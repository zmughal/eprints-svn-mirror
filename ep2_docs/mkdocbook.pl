#!/usr/bin/perl

use subs 'die';
BEGIN {

	sub die {
		print "Error: $_[0]\n";
		exit;
	}

}

use XML::DOM;

$p = new XML::DOM::Parser( ErrorContext=>3, ParseParamEnt=>1 );

$doc = $p->parsefile( $ARGV[0] );

print $doc->toString();


