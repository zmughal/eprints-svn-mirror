#!/usr/bin/perl
# file :update_promon_puids_detached.pl

use strict;
use warnings;
#use EPrints qw( no_check_user );

#my $base_path = EPrints::Config::get( "base_path" );
use POSIX 'setsid';

chdir '/'                or die "Can't chdir to /: $!";
open STDIN, '/dev/null'  or die "Can't read /dev/null: $!";
open STDOUT, '+>>', '/dev/null' or die "Can't write to /dev/null:  $!";
open STDERR, '>&STDOUT'  or die "Can't dup stdout: $!";
setsid or die "Can't start a new session: $!";

my $repo = $ARGV[0];
my $base_path = $ARGV[1];

my $command = $base_path . "/tools/update_pronom_puids " . $repo;

system($command);
