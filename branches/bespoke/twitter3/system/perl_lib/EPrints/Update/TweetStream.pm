package EPrints::Update::TweetStream;

use URI;
use LWP::UserAgent;
use JSON;
use Encode qw(encode);

my $FEEDS_IN_PARALLEL = 3; #how parallelised is the process - this controls how often the queue is resorted



sub create_queue_item
{
	my ($queue_items, $tweetstream) = @_;

	my $session = $tweetstream->{session};
	my $archiveid = $session->get_repository->get_id;

	my $search_string = $tweetstream->get_value('search_string');
	my $key = $search_string . "\n\t\t\n" . $archiveid;

	my $highest_id = $tweetstream->highest_twitterid;
	$highest_id = 0 unless $highest_id;

	if ($queue_items->{$key})
	{
		push @{$queue_items->{$key}->{tweetstreamids}}, $tweetstream->id;
		if ($highest_id < $queue_items->{$key}->{since_twitterid})
		{
			$queue_items->{$key}->{since_twitterid} = $highest_id;
			$queue_items->{$key}->{orderval} = $highest_id;
		}
	}
	else
	{
		$queue_items->{$key} = {
			search_params => {
				q => $search_string,
				rpp => 100,
	#			max_id => set to first ID we get -- used for accurate paging
	#			page => set to current page + 1 when this item is requeued
			},
			tweetstreamids => [ $tweetstream->id ], #for when two streams have identical search strings
			request_failed => 0,
			retries => 5, #if there's a failure, we'll try again.
			since_twitterid => $highest_id,
			orderval => $highest_id,
			commit_flag => 0, #set to 1 when it's time to write the tweetids to the tweetstream
			tweetids => [], #accumulate the tweet object ids as they are collected
			session => $session,
		};
	}
}


sub update_all
{
	my ($reps) = @_;

	my $api_url = 'http://search.twitter.com/search.json';

#get al tweetstreams in all repositories, and create queue items for all the search strings
	my $tweetstreams = get_current_feeds($reps);
	my $queue_items = {};
	foreach my $tweetstream (@{$tweetstreams})
	{
		create_queue_item($queue_items, $tweetstream);
	}

	my @queue = values %{$queue_items};
	my $ua = LWP::UserAgent->new;
	my $nosort = 0;

	ITEM: while ( scalar @queue ) #future development -- test API limits too
	{
		#prioritise by date, but have some parallelisation
		#nosort flag counts down from FEEDS_IN_PARALLEL
		if (!$nosort)
		{
			@queue = sort { ( $a->{orderval} ? $b->{orderval} : -1 ) <=> ( $b->{orderval} ? $a->{orderval} : -1) } @queue; #if there's no orderval, sort highest (i.e. prioritise new streams)
			$nosort = $FEEDS_IN_PARALLEL;
		}
		$nosort--;

		#remove item from the front of the queue
		my $current_item = shift @queue;

		#query Twitter API
		my $url = URI->new( $api_url );
		$url->query_form( %{$current_item->{search_params}} );
		my $response = $ua->get($url);

		my $json_tweets;
		if ($response->is_success)
		{
			$json_tweets = encode('utf-8',$response->decoded_content);
		}
		else
		{
			#handle failure
			my $code = $response->code;
			if ($code == 403) #forbidden -- probably because we've gone back too many pages on this item
			{
				#commit this item and move to next in queue
				$current_item->{commit} = 1;
				post_process(\@queue,$current_item);
				next ITEM;
			}

			#otherwise, assume we've gone over the API limit, and halt *all* requests
			print STDERR 'Got failure status, assuming API limit reached: ',$response->status_line, "\n";
			last ITEM;
		}

		#convert JSON to perl structure
		my $json = JSON->new->allow_nonref;
		my $tweets = eval { $json->utf8()->decode($json_tweets); };
		if ($@)
		{
			print STDERR "Couldn't decode json: $@\n";
			$current_item->{request_failed} = 1;
			post_process(\@queue,$current_item);
		}
		$current_item->{request_failed} = 0;

		#create a tweet dataobj for each tweet and store the objid in the queue item
		TWEET_IN_UPDATE: foreach my $tweet (@{$tweets->{results}})
		{
			$current_item->{search_params}->{max_id} = $tweet->{id} unless $current_item->{search_params}->{max_id}; #highest ID, for consistant paging
			$current_item->{orderval} = $tweet->{id}; #lowest processed so far, for ordering

			#check to see if we already have a tweet with this twitter id in this repository
			my $tweetobj = EPrints::DataObj::Tweet::tweet_with_twitterid($current_item->{session},$tweet->{id});
			if (!defined $tweetobj)
			{
				$tweetobj = EPrints::DataObj::Tweet->create_from_data(
					$current_item->{session},
					{
						twitterid => $tweet->{id},
						json_source => $tweet
					} 
				);
				$tweetobj->commit;
			}
			push @{$current_item->{tweetids}}, $tweetobj->id;

			if ($tweet->{id} <= $current_item->{since_twitterid}) #the one we're considering is the same or younger than the oldest in our stream
			{
				$current_item->{commit} = 1;
				last TWEET_IN_UPDATE;
			}
		}                                                               

		if ( #we didn't get all tweets upto the one we last stored, but we exhausted our search
			not scalar @{$tweets->{results}} #empty page 
		)
		{
			$current_item->{commit} = 1;
		}
		post_process(\@queue, $current_item);
	}

#We're out of API limit
	foreach my $incomplete_item (@queue)
	{
		$incomplete_item->{commit} = 1;
		post_process(\@queue, $incomplete_item);
	}

}

#after updating a page, do what needs to be done to the item -- Most importantly, does the next page need to be requeued
sub post_process
{
	my ($queue, $item) = @_;

#debug - avoid paging: it takes too much time.
#	commit_streams($item);
#	return;

	if ($item->{commit})
	{
		commit_streams($item);
	}
	elsif ($item->{request_failed})
	{
		if ($item->{retries})
		{
			$item->{retries}--;
			push @{$queue}, $item;
		}
		else
		{
			commit_streams($item);			
		}
	}
	else
	{
		my $page_no = $item->{search_params}->{page};
		$item->{search_params}->{page} = $page_no ? ( $page_no + 1 ) : 2;
		push @{$queue}, $item;
	}
}

sub commit_streams
{
	my ($queue_item) = @_;
	foreach my $id (@{$queue_item->{tweetstreamids}})
	{
		my $tweetstream = EPrints::DataObj::TweetStream->new($queue_item->{session}, $id);
		$tweetstream->add_tweetids($queue_item->{tweetids});
	}
}

sub _get_feeds_aux
{
	my ($reps, $current_only) = @_;

	my @tweetstreams;

	foreach my $repository (values %{$reps})
	{
		$ds = $repository->get_dataset( "tweetstream" );

		$searchexp = EPrints::Search->new(
				session => $repository,
				dataset => $ds,
				);

		if ($current_only)
		{
			my $today = EPrints::Time::get_iso_date( time );
			$searchexp->add_field(
					$ds->get_field( "expiry_date" ),
					$today."-" );
		}

		my $results = $searchexp->perform_search;

		my @streams = $results->get_records;
		push @tweetstreams, @streams;
	}

	return \@tweetstreams;

}

sub get_all_feeds
{
        my ($reps) = @_;

	return _get_feeds_aux($reps);
}

sub get_current_feeds
{
        my ($reps) = @_;

	return _get_feeds_aux($reps,1);
}


1;
