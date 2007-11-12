#!/usr/bin/perl -w

use Data::Dumper;
use Net::Honeycomb;

Net::Honeycomb::init();

my $oid;
my $honey = Net::Honeycomb->new( "hc-data", 8080 );

$oid = $honey->store_file( "demo.pl" );
$honey->print_error if( $honey->error );
print "$oid\n";

$honey->free();
Net::Honeycomb::cleanup();
