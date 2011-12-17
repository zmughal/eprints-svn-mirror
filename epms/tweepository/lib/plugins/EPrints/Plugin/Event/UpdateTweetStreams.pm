package EPrints::Plugin::Event::UpdateTweetStreams;

use EPrints::Plugin::Event::LockingEvent;
@ISA = qw( EPrints::Plugin::Event::LockingEvent );

use strict;

use URI;
use LWP::UserAgent;
use JSON;
use Encode qw(encode);



sub action_update_tweetstreams
{
	my ($self) = @_;

	if ($self->is_locked)
	{
		$self->repository->log( (ref $self) . " is locked.  Unable to run (remove ".$self->lockfile." if you think it previously crashed)" );
		return;
	}

	$self->create_lock;

	my $FEEDS_IN_PARALLEL = 3;
	my $api_url = 'http://search.twitter.com/search.json';

	my $active_tweetstreams = $self->active_tweetstreams;
	my $queue_items = {};
	$active_tweetstreams->map( \&EPrints::Plugin::Event::UpdateTweetStreams::create_queue_item, $queue_items);

	my @queue = values %{$queue_items};

	my $ua = LWP::UserAgent->new;
	my $nosort = 0;

	ITEM: while ( scalar @queue ) #future development -- test API limits too
	{
		#prioritise by date, but have some parallelisation
		#nosort flag counts down from FEEDS_IN_PARALLEL
		if (!$nosort)
		{
			@queue = $self->order_queue(@queue);
			$nosort = $FEEDS_IN_PARALLEL + 1;
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
				#We've got all we can.  Move onto the next and let this one fall off of the queue
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
			if ($current_item->{retries})
			{
				#requeue X times (where X is the number of retries)
				$current_item->{retries}--;
				push @queue, $current_item
			}
			#else let this one fall off the end of the queue
		}

		next ITEM unless scalar @{$tweets->{results}}; #if an empty page of results, assume no more tweets

		my $first = 1;
		my $update_finished;
		#create a tweet dataobj for each tweet and store the objid in the queue item
		TWEET_IN_UPDATE: foreach my $tweet (@{$tweets->{results}})
		{
			$update_finished = 0;	
			if (!$current_item->{search_params}->{max_id})
			{
				$current_item->{search_params}->{max_id} = $tweet->{id}; #highest ID, for consistant paging
			}
			$current_item->{orderval} = $tweet->{id}; #lowest processed so far, for queue ordering

			#check to see if we already have a tweet with this twitter id in this repository
			my $tweetobj = EPrints::DataObj::Tweet::tweet_with_twitterid($self->repository,$tweet->{id});
			if (!defined $tweetobj)
			{
				$tweetobj = EPrints::DataObj::Tweet->create_from_data(
					$self->repository,
					{
						twitterid => $tweet->{id},
						json_source => $tweet,
						tweetstreams => $current_item->{tweetstreamids},
					} 
				);
			}
			else
			{
				$tweetobj->add_to_tweetstreamid($current_item->{tweetstreamids});
			}
			#only the first in the update doesn't have a following tweet
			if (!$first)
			{
				$tweetobj->set_next_in_tweetstream($current_item->{tweetstreamids});
			}
			$tweetobj->commit;

			if ($tweet->{id} <= $current_item->{since_twitterid}) #the one we're considering is the same or younger than the oldest in our stream
			{
				$update_finished = 1;
				last TWEET_IN_UPDATE;
			}
			$first = 0;
		}

		#request the next page of results (unless we've reached a previously seen item)
		if ($current_item->{search_params}->{page})
		{
			$current_item->{search_params}->{page}++;
		}
		else
		{
			$current_item->{search_params}->{page} = 2;
		}
		push @queue, $current_item unless $update_finished;
		
	}

	#tweetstream is only committed when the tweets are enriched

	$self->remove_lock
}

sub order_queue
{
	my ($self, @queue) = @_;

	return sort { ( $a->{orderval} ? $b->{orderval} : -1 ) <=> ( $b->{orderval} ? $a->{orderval} : -1) } @queue; #if there's no orderval, sort highest (i.e. prioritise new streams)
}

sub create_queue_item
{
	my ($repo, $ds, $tweetstream, $queue_items) = @_;

	my $search_string = $tweetstream->get_value('search_string');
	my $highest_id = $tweetstream->highest_twitterid;
	$highest_id = 0 unless $highest_id;

	if ($queue_items->{$search_string})
	{
		push @{$queue_items->{$search_string}->{tweetstreamids}}, $tweetstream->id;
		if ($highest_id < $queue_items->{$search_string}->{since_twitterid})
		{
			$queue_items->{$search_string}->{since_twitterid} = $highest_id;
			$queue_items->{$search_string}->{orderval} = $highest_id;
		}
	}
	else
	{
		$queue_items->{$search_string} = {
			search_params => {
				q => $search_string,
				rpp => 100,
	#			max_id => set to first ID we get -- used for accurate paging
	#			page => set to current page + 1 when this item is requeued
			},
			tweetstreamids => [ $tweetstream->id ], #for when two streams have identical search strings
			retries => 5, #if there's a failure, we'll try again.
			since_twitterid => $highest_id,
			orderval => $highest_id,
		};
	}
}


sub active_tweetstreams
{
	my ($self) = @_;

	my $ds = $self->repository->get_dataset( "tweetstream" );

	my $searchexp = EPrints::Search->new(
			session => $self->repository,
			dataset => $ds,
			);
	my $today = EPrints::Time::get_iso_date( time );
	$searchexp->add_field(
			$ds->get_field( "expiry_date" ),
			$today."-" );

	return $searchexp->perform_search;
}






1;
