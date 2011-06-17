#!/usr/bin/perl

# this functions checks what version of the CGI.pm module is
# installed and returns "new" if it's a version which supports
# the new mod_perl2 API and old if it isn't.

use CGI;

unless( $CGI::VERSION =~ m/^(\d+)\.(\d+)/ )
{
	print STDERR "Could not determine the CGI.pm version.\n";
	exit;
}

my( $major, $minor ) = ( $1, $2 );

my $version = $major*1000+$minor;

if( $version <= 3007 )
{
	print "old";
	exit;
}

print "new";
exit;
