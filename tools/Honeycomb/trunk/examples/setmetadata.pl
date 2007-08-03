#!/usr/bin/perl -w

use Data::Dumper;
use Honeycomb;

Honeycomb::init();

my $oid;
my $honey = Honeycomb->new( "hc-data", 8080 );

$oid = "010001237ff443418b11dcb2ec00e081731b57000020ce0200000000";
$oid = "010001b5d0d9fa421211dc890600e08173199100000eef0200000000";
$oid = "0100011e3cb880421e11dc947a00e081719aa1000026f90200000000";

$honey->set_metadata( $oid, "filesystem.mimetype", "test/groovy" );
$honey->print_error if( $honey->error );

$honey->free();
Honeycomb::cleanup();
