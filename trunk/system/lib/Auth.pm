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

print STDERR "URI: ".$r->uri()."\n";


	my $hpp=$r->hostname.":".$r->get_server_port.$r->uri;
print STDERR "Rebuilt URL Stub: $hpp\n";

	my $session = new EPrints::Session( 2 , $hpp );
	
	if( !defined $session )
	{
		return FORBIDDEN;
	}

	if( !defined $user_sent )
	{
print STDERR "no user name\n";
		$session->terminate();
		return AUTH_REQUIRED;
	}
print STDERR "therequest: ".$r->the_request()."\n";

print STDERR "THE USER IS: $user_sent\n";

	my $ds = $session->get_archive()->get_dataset( "user" );

	my $user = $session->get_db()->get_single( $ds , $user_sent );
	if( !defined $user )
	{
print STDERR "zong\n";
		$r->note_basic_auth_failure;
		$session->terminate();
		return AUTH_REQUIRED;
	}
print STDERR "GRP:".$user->{usertype}."\n";
	my $usertypedata = $session->get_archive()->get_conf( 
		"userauth", $user->get_value( "usertype" ) );
	if( !defined $usertypedata )
	{
#cjg this is an error
		$session->get_archive()->log(
			"Unknown user type: $user->{usertype}" );
		$session->terminate();
		return AUTH_REQUIRED;
	}
print STDERR "X2:".join(",",keys %{$usertypedata->{conf}})."\n";
	my $rwrapper = EPrints::RequestWrapper->new( 
			$r , 
			$usertypedata->{conf} );
	my $result = &{$usertypedata->{routine}}( $rwrapper );
	$session->terminate();
print STDERR "***END OF AUTH***\n\n";
	return $result;
}

## WP1: BAD
sub authz
{
	my( $r ) = @_;

	return 1;
#          |
#### JUNK \|/ 

print STDERR "Authz\n";
print STDERR "XX:".$r->requires()."\n";
print STDERR EPrints::Session::render_struct( $r->requires() );
	my %okgroups = ();
	my $authz = 0;
	my $reqset;
	foreach $reqset ( @{$r->requires()} )
	{
		my $val = $reqset->{requirement};
print STDERR "REQUIxxx: $val\n";
		$val =~ s/^\s*require\s+//;
		# handle different requirement-types
		if ($val =~ /valid-user/) {
			$authz = 1;
		} elsif ($val =~ s/^group\s+//go) {
			foreach( split(/\s+/,$val) )
			{
				$okgroups{$_}++;
			}
		}
print STDERR "REQUIRES: $val\n";
	}
	
	my $user_sent = $r->connection->user;
	my $session = new EPrints::Session( 2 , $r->hostname.$r->uri );
print STDERR "THE USER IS: $user_sent\n";
	my $ds = $session->get_archive()->get_dataset( "user" );
	my $user = $session->get_db()->get_single( $ds , $user_sent );
	if( defined $user )
	{
		foreach( @{$session->get_archive()->get_conf( 
					"userauth", 
					$user->get_value( "usertype" ), 
					"priv" )} )
		{
			$authz = 1 if( defined $okgroups{$_} );
		}
	}

	$session->terminate;

	return OK if( $authz );

	$r->note_basic_auth_failure;

	return AUTH_REQUIRED;
}

1;
