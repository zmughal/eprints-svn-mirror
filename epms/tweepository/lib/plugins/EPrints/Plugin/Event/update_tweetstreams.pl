#!/usr/bin/perl -I/opt/eprints3/perl_lib

use strict;
use warnings;

use EPrints;

my $ep = EPrints->new;
my $repo = $ep->repository('tweets');
my $plugin = $repo->plugin('Event::UpdateTweetStreams');

$plugin->action_update_tweetstreams;
