######################################################################
#
# EPrints::Apache::Auth
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Apache::Auth> - Password authentication & authorisation checking 
for EPrints.

=head1 DESCRIPTION

This module handles the authentication and authorisation of users
viewing private sections of an EPrints website.

=over 4

=cut
######################################################################

package EPrints::Apache::Auth;

use strict;

use EPrints::Apache::AnApache; # exports apache constants
use URI;

#use EPrints::Session;
#use EPrints::SystemSettings;



sub authen
{
	my( $r ) = @_;

	return OK unless $r->is_initial_req; # only the first internal request
	
	my $repository = $EPrints::HANDLE->current_repository;
	if( !defined $repository )
	{
		return DECLINED;
	}

	my $rc;
	if( !_use_auth_basic( $r, $repository ) )
	{
		$rc = auth_cookie( $r, $repository );
	}
	else
	{
		$rc = auth_basic( $r, $repository );
	}

	return $rc;
}

sub _use_auth_basic
{
	my( $r, $repository ) = @_;

	my $rc = 0;

	if( !$repository->config( "cookie_auth" ) ) 
	{
		$rc = 1;
	}
	else
	{
		my $uri = URI->new( $r->uri, "http" );
		my $script = $uri->path;

		my $econf = $repository->config( "auth_basic" ) || [];

		foreach my $exppath ( @$econf )
		{
			if( $exppath !~ /^\// )
			{
				$exppath = $repository->config( "rel_cgipath" )."/$exppath";
			}
			if( $script =~ /^$exppath/ )
			{
				$rc = 1;
				last;
			}
		}
	}

	return $rc;
}

sub authen_doc
{
	my( $r ) = @_;

	my $repository = $EPrints::HANDLE->current_repository;
	if( !defined $repository )
	{
		return DECLINED;
	}

	my $rvalue = _authen_doc( $r, $repository );

	return $rvalue;
}

sub _authen_doc
{
	my( $r, $repository ) = @_;

	my $document = $r->pnotes( "document" );
	return NOT_FOUND if( !defined $document );

	my $security = $document->get_value( "security" );

	my $result = $repository->call( "can_request_view_document", $document, $r );

	if( $result eq "ALLOW" )
	{
		return OK;
	}
	elsif( $result eq "DENY" )
	{
		return FORBIDDEN;
	}
	elsif( $result ne "USER" )
	{
		$repository->log( "Response from can_request_view_document was '$result'. Only ALLOW, DENY, USER are allowed." );
		return FORBIDDEN;
	}

	my $rc;
	if( !_use_auth_basic( $r, $repository ) )
	{
		$rc = auth_cookie( $r, $repository, 1 );
	}
	else
	{
		$rc = auth_basic( $r, $repository );
	}

	return $rc;
}




sub auth_cookie
{
	my( $r, $repository, $redir ) = @_;

	my $user = $repository->current_user;

	if( !defined $user ) 
	{
		my $login_url = $repository->get_url(
			path => "cgi",
		) . "/users/login";
		my $target_url = $repository->get_url(
			host => 1,
			path => "auto",
		);
		$login_url = URI->new( $login_url );
		$login_url->query_form(
			target => $target_url
		);
		if( $repository->can_call( 'get_login_url' ) )
		{
			$login_url = $repository->call( 'get_login_url', $repository, $target_url );
			$redir = 1;
		}
		if( $redir )
		{
			EPrints::Apache::AnApache::send_status_line( $r, 302, "Need to login first" );
			EPrints::Apache::AnApache::header_out( $r, "Location", $login_url );
			EPrints::Apache::AnApache::send_http_header( $r );
			return DONE;
		}

		$r->handler( 'perl-script' );
		$r->set_handlers(PerlResponseHandler =>[ 'EPrints::Apache::Login' ] );
		return OK;
	}

	my $loginparams = $repository->param("loginparams");
	if( EPrints::Utils::is_set( $loginparams ) ) 
	{
		my $url = $repository->get_url( host=>1 )."?".$loginparams;
		$repository->redirect( $url );
		return DONE;
	}

	return OK;
}


sub auth_basic
{
	my( $r, $repository ) = @_;

	my( $res, $passwd_sent ) = $r->get_basic_auth_pw;
	my( $user_sent ) = $r->user;

	if( !defined $user_sent )
	{
		return AUTH_REQUIRED;
	}

	my $user_ds = $repository->get_repository->get_dataset( "user" );

	my $user = EPrints::DataObj::User::user_with_username( $repository, $user_sent );
	if( !defined $user )
	{
		$r->note_basic_auth_failure;
		return AUTH_REQUIRED;
	}

	return $repository->valid_login( $user_sent, $passwd_sent ) ?
			OK : AUTH_REQUIRED;
}

sub authz
{
	my( $r ) = @_;

	return OK;
}

sub authz_doc
{
	my( $r ) = @_;

	my $repository = $EPrints::HANDLE->current_repository;
	if( !defined $repository )
	{
		return DECLINED;
	}

	my $document = $r->pnotes( "document" );
	if( !defined $document ) 
	{
		return NOT_FOUND;
	}

	my $result = $repository->call( "can_request_view_document", $document, $r );
	if( $result eq "ALLOW" )
	{
		return OK;
	}
	elsif( $result eq "DENY" )
	{
		return FORBIDDEN;
	}

	my $user = $repository->current_user;

	if( $document->user_can_view( $user ) )
	{
		return OK;
	}
	else
	{
		return FORBIDDEN;
	}
}

1;

######################################################################
=pod

=back

=cut

