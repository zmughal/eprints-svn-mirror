#!/usr/bin/perl -w

use FindBin;
use lib "$FindBin::Bin/../../perl_lib";

use strict;
use warnings;

use EPrints;

my ($repoid) = @ARGV;
die "update_tweetstream_abstracts.pl *repositoryid*\n" unless $repoid;
chomp $repoid;

my $ep = EPrints->new;
my $repo = $ep->repository($repoid);
die "couldn't create repository for '$repoid'\n" unless $repo;

my $plugin = $repo->plugin('Event::UpdateTweetStreamAbstracts');

$plugin->action_update_tweetstream_abstracts;

