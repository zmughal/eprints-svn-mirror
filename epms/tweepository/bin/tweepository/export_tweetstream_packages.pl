#!/usr/bin/perl -w

use FindBin;
use lib "$FindBin::Bin/../../perl_lib";

use strict;
use warnings;

use EPrints;

my ($repoid, @ids) = @ARGV;
die "export_tweetstream_packages.pl *repositoryid* [*tweetstreamid*] [*tweetstreamid*] [...]\n" unless $repoid;
chomp $repoid;

my $ep = EPrints->new;
my $repo = $ep->repository($repoid);
die "couldn't create repository for '$repoid'\n" unless $repo;

my $plugin = $repo->plugin('Event::ExportTweetStreamPackage');

if (scalar @ids)
{
	$plugin->action_export_tweetstream_packages(@ids);
}
else
{
	$plugin->action_export_queued_tweetstream_packages;
}

