package EPrints::Feed::Twitter::Update;

use URI;
use LWP::UserAgent;
use JSON;

my $FEEDS_IN_PARALLEL = 3; #how parallelised is the process - this controls how often the queue is resorted

sub create_queue_item
{
	my ($doc) = @_;

	my $feed_obj = EPrints::Feed::Twitter->new($doc);

	my $highest_id = $feed_obj->highest_id;
	$highest_id = 0 unless $highest_id;

	my $item = {
		search_params => {
			q => $doc->get_value('twitter_hashtag'),
			rpp => 100,
#			max_id => set to first ID we get
#			page => set to current page + 1 when this item is requeued
		},
		feed_obj => $feed_obj,
		request_failed => 0,
		retries => 5, #if there's a failure, we'll try again.
		since_id => $highest_id,
		orderval => $highest_id,
		first_update => $highest_id ? 1 : 0, #if we have no highest_id, then it's the first time we've searched on this item.
		update_complete => 0,
		no_more_tweets => 0,
	};
	return $item;
}

sub generate_mains
{
	my ($reps, $force) = @_;
	my $documents = get_all_feeds($reps);
	foreach my $doc (@{$documents})
	{
		my $feed_obj = EPrints::Feed::Twitter->new($doc);
		$feed_obj->create_main_file($force);
	}
}

sub update_all
{
	my ($reps) = @_;

	my $documents = get_current_feeds($reps);

	my @queue;
	foreach my $doc (@{$documents})
	{
		push @queue, create_queue_item($doc);
	}

	my $ua = LWP::UserAgent->new;

	my $nosort = 0;
	ITEM: while ( scalar @queue ) #test API limits too
	{
		#prioritise by date, but have some parallelisation.  We'll only get nothing if we have feeds_in_parallel+1 trending topics.
		if (!$nosort)
		{
			@queue = sort { ( $a->{orderval} ? $b->{orderval} : -1 ) <=> ( $b->{orderval} ? $a->{orderval} : -1) } @queue; #if there's no orderval, sort highest
			$nosort = $FEEDS_IN_PARALLEL;
		}
		$nosort--;

		my $current_item = shift @queue;

		my $url = URI->new( "http://search.twitter.com/search.json" );
		$url->query_form( %{$current_item->{search_params}} );
		my $response = $ua->get($url);

		my $json_tweets;
		if ($response->is_success)
		{
			$json_tweets = $response->decoded_content;
		}
		else
		{
			my $code = $response->code;
			if ($code == 403) #forbidden -- probably because we've gone back too many pages on this item
			{
				$current_item->{no_more_tweets} = 1;
				post_process(\@queue,$current_item);
				next ITEM;
			}

			#otherwise, assume we've gone over the API limit, and halt *all* requests
			print STDERR 'Got failure status, assuming API limit reached: ',$response->status_line, "\n";
			last ITEM;
		}

		my $tweets = eval { decode_json($json_tweets); };
		if ($@)
		{
			print STDERR "Couldn't decode json: $@\n";
			$current_item->{request_failed} = 1;
			post_process(\@queue,$current_item);
		}
		$current_item->{request_failed} = 0;

		foreach my $tweet (@{$tweets->{results}})
		{
			$current_item->{search_params}->{max_id} = $tweet->{id} unless $current_item->{search_params}->{max_id}; #highest ID, for consistant paging
			$current_item->{orderval} = $tweet->{id}; #lowest processed so far, for ordering

			if ($tweet->{id} == $current_item->{since_id})
			{
				$current_item->{update_complete} = 1;
				last;
			}
			else
			{
				$current_item->{feed_obj}->add_to_buffer($tweet);
			}
		}

		if ( #we didn't get all tweets upto the one we last stored, but we exhausted our search
			not scalar @{$tweets->{results}} #empty page 
		)
		{
			$current_item->{no_more_tweets} = 1;
		}
		post_process(\@queue, $current_item);
	}

	foreach my $incomplete_item (@queue)
	{
		post_process(\@queue, $incomplete_item);
	}

}

#after updating a page, do what needs to be done to the item -- Most importantly, does the next page need to be queued
sub post_process
{
	my ($queue, $item) = @_;

	if ($item->{update_complete})
	{
		$item->{feed_obj}->commit;
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
			#perhaps handle with more sophistication?
			$item->{feed_obj}->commit_incomplete;
		}
	}
	elsif ($item->{no_more_tweets})
	{
		if ($item->{first_update})
		{
			$item->{feed_obj}->commit;
		}
		else
		{
			$item->{feed_obj}->commit_incomplete;
		}
	}
	else
	{
		my $page_no = $item->{search_params}->{page};
		$item->{search_params}->{page} = $page_no ? ( $page_no + 1 ) : 2;
		push @{$queue}, $item;
	}
}

sub _get_feeds_aux
{
	my ($reps, $current_only) = @_;

	my @documents;

	foreach my $repository (values %{$reps})
	{
		$ds = $repository->get_dataset( "document" );

		$searchexp = EPrints::Search->new(
				session => $repository,
				dataset => $ds,
				);

		$searchexp->add_field( $ds->get_field( "content" ), 'feed/twitter' );

		if ($current_only)
		{
			my $today = EPrints::Time::get_iso_date( time );
			$searchexp->add_field(
					$ds->get_field( "twitter_expiry_date" ),
					$today."-" );
		}

		my $results = $searchexp->perform_search;

		my @docs = $results->get_records;
		push @documents, @docs;
	}

	return \@documents;

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
