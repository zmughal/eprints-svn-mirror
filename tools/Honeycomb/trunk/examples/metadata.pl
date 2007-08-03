#!/usr/bin/perl -w

use Data::Dumper;
use Honeycomb;

Honeycomb::init();

my $oid;
my $honey = Honeycomb->new( "hc-data", 8080 );

$oid = "010001237ff443418b11dcb2ec00e081731b57000020ce0200000000";
$oid = "0100011e3cb880421e11dc947a00e081719aa1000026f90200000000";
$oid = "010001d2dcdb5a421811dcb2ec00e081731b5700001efb0200000000";

my $data = $honey->get_metadata( $oid );
$honey->print_error if( $honey->error );
print Dumper( $data );

$honey->free();
Honeycomb::cleanup();
