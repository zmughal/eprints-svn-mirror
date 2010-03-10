######################################################################
#
# EPrints::Apache::WebDAV
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Apache::WebDAV;

use EPrints;
use EPrints::Filesys;
use EPrints::Apache::AnApache; # constants
use Apache2::WebDAV;

use strict;
use warnings;

sub handler
{
	my( $r ) = @_;

	my $rc = OK;

binmode(STDERR, ":utf8");
print STDERR ('-'x79)."\n".$r->method." ".Encode::decode_utf8($r->uri)." ".$r->protocol."\n";
print STDERR "HEADERS_IN\n";
foreach my $key (keys %{$r->headers_in})
{
	print STDERR sprintf("%20s: %s\n", $key, $r->headers_in->{$key});
}

	my $session = EPrints::Session->new( 2 );

	my $auth_name = "DAV";

	# Require authentication
	if( !defined $session->current_user )
	{
		$r->auth_name( $auth_name );
		$r->ap_auth_type( "Basic" );
		$rc = EPrints::Apache::Auth::auth_basic( $r, $session );
		if( $rc == OK )
		{
			$session->{current_user} = $session->_current_user_auth_basic;
		}
	}

	if( !defined $session->current_user )
	{
		$r->err_headers_out->{'WWW-Authenticate'} = "Basic realm=\"$auth_name\"";
	}

	if( defined $session->current_user )
	{
print STDERR "current_user=".$session->current_user->get_value( "username" )."\n";

		my $dav = Apache2::WebDAV->new;

		my @handlers = ({
			path => "/DAV",
			module => "EPrints::Filesys",
			args => {
				root_path => "/DAV",
				session => $session,
				current_user => $session->current_user,
			},
		});

		$dav->register_handlers(@handlers);

		$rc = $dav->process( $r );
	}

print STDERR "HEADERS_OUT\n";
foreach my $key (keys %{$r->headers_out})
{
	print STDERR sprintf("%20s: %s\n", $key, $r->headers_out->{$key});
}
print STDERR "ERR_HEADERS_OUT\n";
foreach my $key (keys %{$r->err_headers_out})
{
	print STDERR sprintf("%20s: %s\n", $key, $r->err_headers_out->{$key});
}
print STDERR "RESULT ".($rc||$r->status_line||$r->status)."\n";
print STDERR "\n";

	$session->terminate;

	return $rc;
}

1;
