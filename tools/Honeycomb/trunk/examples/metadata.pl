#!/usr/bin/perl -w

use Data::Dumper;
use Net::Honeycomb;

my $honey = Net::Honeycomb->new( "hc-data", 8080 );
die "Could not connect to honeycomb" unless defined $honey;

my $data = $honey->get_metadata( $ARGV[0] );
die $honey->error_string if( $honey->error );

print Dumper( $data );

