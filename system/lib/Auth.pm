######################################################################
#
# cjg
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Auth;

use strict;

use Apache::AuthDBI;
use Apache::Constants qw( OK AUTH_REQUIRED FORBIDDEN DECLINED SERVER_ERROR );

use EPrints::Session;
use EPrints::RequestWrapper;

## WP1: BAD
sub authen
{
	my( $r ) = @_;

print STDERR "Authen\n";

	my($res, $passwd_sent) = $r->get_basic_auth_pw;

	my ($user_sent) = $r->connection->user;

	return OK unless $r->is_initial_req; # only the first internal request

	my $hpp=$r->hostname.":".$r->get_server_port.$r->uri;
	my $session = new EPrints::Session( 2 , $hpp );
	
	if( !defined $session )
	{
		return FORBIDDEN;
	}

	if( !defined $user_sent )
	{
		$session->terminate();
		return AUTH_REQUIRED;
	}

	my $user_ds = $session->get_archive()->get_dataset( "user" );

	my $user = EPrints::User::user_with_username( $session, $user_sent );
	if( !defined $user )
	{
		$r->note_basic_auth_failure;
		$session->terminate();
		return AUTH_REQUIRED;
	}

	my $userauthdata = $session->get_archive()->get_conf( 
		"userauth", $user->get_value( "usertype" ) );

	if( !defined $userauthdata )
	{
		$session->get_archive()->log(
			"Unknown user type: ".$user->get_value( "usertype" ) );
		$session->terminate();
		return AUTH_REQUIRED;
	}
	my $authconfig = $userauthdata->{auth};
	my $handler = $authconfig->{handler}; 
	# {handler} should really be removed before passing authconfig
	# to the requestwrapper. cjg

	my $rwrapper = EPrints::RequestWrapper->new( $r , $authconfig );
	my $result = &{$handler}( $rwrapper );
	$session->terminate();
print STDERR "***END OF AUTH***($result)\n\n";
	return $result;
}

## WP1: BAD
sub authz
{
	my( $r ) = @_;

	# If we are looking at the users section then do nothing, 
	# but if we are looking at a document in the secure area then
	# we need to do some work.

	my $hpp=$r->hostname.":".$r->get_server_port.$r->uri;
	my $session = new EPrints::Session( 2 , $hpp );
	my $archive = $session->get_archive();

	my $uri = $r->uri;
	
	my $secpath = $archive->get_conf( "server_secure_path" );
	
	if( $uri !~ m#^$secpath# )
	{
		print STDERR "OK\n";
		# Not the secure documents area, so probably the script area
		# which handles security on a script by script basis.
		$session->terminate();
		return OK;
	}	

	my $idstem = $archive->get_conf( "eprint_id_stem" );

	if( $uri !~ m#^$secpath/$idstem(\d+)/(\d+)/# )
	{
		print STDERR "URL in secure area fails to match pattern\n";
		print STDERR "$uri\n";
		$r->note_basic_auth_failure;
		$session->terminate();
		return AUTH_REQUIRED;
	}

	my $user_sent = $r->connection->user;
	my $eprintid = $1+0; # force it to be integer.
	my $docid = "$eprintid-$2";
	my $user = EPrints::User::user_with_username( $session, $user_sent );
	my $document = EPrints::Document->new( $session, $docid );

	unless( $document->can_view( $user ) )
	{
		$session->terminate();
		return FORBIDDEN;
	}	

	$session->terminate();
	return OK;
}

1;
