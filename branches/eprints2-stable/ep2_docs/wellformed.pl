#!/usr/bin/perl

use subs 'die';

BEGIN {

	sub die {
		print "Error: $_[0]\n";
		exit;
	}

}

use XML::Parser;

$p = new XML::Parser( ErrorContext=>3, ParseParamEnt=>1 );
open( XML, $ARGV[0] ) || die "Can't open $ARGV[0]";
my $xml = "";
if( $ARGV[1] eq "NODTD" )
{
	$xml=<<END;
<?xml version="1.0" standalone="no" ?>
<!DOCTYPE book SYSTEM "eprints.entities" >
END
}
while(<XML>) { $xml.=$_; }
close XML;

$p->parse( $xml );


