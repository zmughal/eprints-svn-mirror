#!/usr/bin/perl -w

my $path = $ARGV[1];
$path = "" unless defined( $path );

`scp $ARGV[0] webmaster\@www:/home/www.eprints/software/files/eprints2/$path`;

