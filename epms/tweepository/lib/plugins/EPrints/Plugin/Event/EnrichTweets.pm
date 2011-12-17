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

        $self->{log_data}->{start_time} = scalar localtime time;

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

		$data->{log_data}->{tweets_enriched}++;

		foreach my $tweetstreamid (@{$tweet->get_value('tweetstreams')})
		{
			$data->{tweetstreamids}->{$tweetstreamid} = 1;
		}

		$tweet->enrich_text($data->{uri_cache}, $data->{log_data});
		$tweet->commit;
	}, { uri_cache => $uri_cache, tweetstreamids => $tweetstreamids, log_data => $self->{log_data} });

	$self->{log_data}->{enrichment_end_time} = scalar localtime time;
	$self->{log_data}->{tweetstreams_digested} = scalar keys %{$tweetstreamids};

	$ds = $self->repository->get_dataset( "tweetstream" );
	foreach my $tweetstreamid (keys %{$tweetstreamids})
	{
		my $tweetstream = $ds->dataobj($tweetstreamid);

		$tweetstream->generate_tweet_digest;
		$tweetstream->commit;
	}

	$self->remove_lock;
        $self->{log_data}->{end_time} = scalar localtime time;
	$self->write_log;

}

sub generate_log_string
{
	my ($self) = @_;

	my $l = $self->{log_data};

	my @r;

	my $tweets = $l->{tweets_enriched} ? $l->{tweets_enriched} : 0;
	my $cached = $l->{url_cache_lookups} ? $l->{url_cache_lookups} : 0;
	my $follows = $l->{url_follows} ? $l->{url_follows} : 0;
	my $tweetstreams = $l->{tweetstreams_digested} ? $l->{tweetstreams_digested} : 0;

        push @r, "Enrichment started at:        " . $l->{start_time};
	push @r, "Enrichment finished at:       " . $l->{enrichment_end_time};
        push @r, "$tweets tweets enriched";
        push @r, "$follows URLs looked up ($cached cache reads)";
        push @r, "Stream digestion finished at: " . $l->{end_time};
	push @r, "$tweetstreams tweetstreams digested";

	return join("\n", @r);
}






1;
