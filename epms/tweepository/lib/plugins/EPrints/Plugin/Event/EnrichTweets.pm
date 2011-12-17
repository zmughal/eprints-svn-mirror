package EPrints::Plugin::Event::EnrichTweets;

use EPrints::Plugin::Event::LockingEvent;
@ISA = qw( EPrints::Plugin::Event::LockingEvent );

use strict;

sub action_enrich_tweets
{
	my ($self) = @_;

	if ($self->is_locked)
	{
		$self->repository->log( (ref $self) . " is locked.  Unable to run (remove ".$self->lockfile." if you think it previously crashed)\n");
		return;
	}

	$self->create_lock;

	my $ds = $self->repository->get_dataset( "tweet" );

	my $searchexp = EPrints::Search->new(
			session => $self->repository,
			dataset => $ds,
			);
	$searchexp->add_field(
			$ds->get_field( "text_is_enriched" ),
			'FALSE' );

	my $tweets = $searchexp->perform_search;

	my $uri_cache = {}; #do some caching
	my $tweetstreamids = {};

	$tweets->map(sub {
		my ($repo, $ds, $tweet, $data) = @_;
		foreach my $tweetstreamid (@{$tweet->get_value('tweetstreams')})
		{
			$data->{tweetstreamids}->{$tweetstreamid} = 1;
		}

		$tweet->enrich_text($data->{uri_cache});
		$tweet->commit;
	}, { uri_cache => $uri_cache, tweetstreamids => $tweetstreamids });

	$ds = $self->repository->get_dataset( "tweetstream" );
	foreach my $tweetstreamid (keys %{$tweetstreamids})
	{
		my $tweetstream = $ds->dataobj($tweetstreamid);

		$tweetstream->generate_tweet_digest;
		$tweetstream->commit;
	}

	$self->remove_lock;

}






1;
