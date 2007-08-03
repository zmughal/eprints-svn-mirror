#!/usr/bin/perl -w

use Data::Dumper;
use Honey;

my $oid;
my $honey = Honey->new( "hc-data", 8080 );
print Dumper($honey);

$oid = "0100012cad1008407611dc890600e081731991000023a80200000000";
$oid = "010001237ff443418b11dcb2ec00e081731b57000020ce0200000000";

print $honey->string_oid( $oid );
$honey->print_error if( $honey->error );

#$oid = $honey->store_file( "demo.pl" );
#$honey->print_error if( $honey->error );
#print "$oid\n";

#$oid = "0100012cad1008407611dc890600e081731991000023a80200000300";
#$honey->print_error if( $honey->error );
#print "".$honey->error."\n" if( $honey->error );



