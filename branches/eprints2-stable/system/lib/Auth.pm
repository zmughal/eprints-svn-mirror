######################################################################
#
# EPrints::Auth
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

B<EPrints::Auth> - Password authentication & authorisation checking 
for EPrints.

=head1 DESCRIPTION

This module handles the authentication and authorisation of users
viewing private sections of an EPrints website.

=over 4

=cut
######################################################################

package EPrints::Auth;

use strict;

use Apache::AuthDBI;
use EPrints::AnApache;

use EPrints::Session;
use EPrints::SystemSettings;


######################################################################
=pod

=item $result = EPrints::Auth::authen( $r )

Authenticate a request. This works in a slightly whacky way.

If the username isn't a valid user in the current archive then it
fails right away.

Otherwise it looks up the type of the given user. Then it looks up
in the archive configuration to find how to authenticate that user
type (a reference to another authen function, probably a normal
3rd party mod_perl library like AuthDBI.) and then makes a mock
request and attempts to authenticate it using the authen function for
that usertype.

This is a bit odd, but allows, for example, you to have local users 
being authenticated via LDAP and remote users authenticated by the
normal eprints AuthDBI method.

If the authentication area is "ChangeUser" then it returns true unless
the current user is the user specified in the URL. This will allow a
user to log in as someone else.

=cut
######################################################################

sub authen
{
	my( $r ) = @_;

	my($res, $passwd_sent) = $r->get_basic_auth_pw;

	my ($user_sent) = $r->user;

	return OK unless $r->is_initial_req; # only the first internal request

	EPrints::Session::start or return FORBIDDEN;

	if( !defined $user_sent )
	{
		&SESSION->terminate();
		return AUTH_REQUIRED;
	}

	my $area = $r->dir_config( "EPrints_Security_Area" );
	if( $area eq "ChangeUser" )
	{
		my $user_sent = $r->user;
		if( $r->uri !~ m#/$user_sent$# )
		{
			return OK;
		}
		
		$r->note_basic_auth_failure;
		return AUTH_REQUIRED;
	}

	my $user_ds = &ARCHIVE->get_dataset( "user" );

	my $user = EPrints::User::user_with_username( $user_sent );
	if( !defined $user )
	{
		$r->note_basic_auth_failure;
		&SESSION->terminate();
		return AUTH_REQUIRED;
	}

	my $userauthdata = &ARCHIVE->get_conf( 
		"userauth", $user->get_value( "usertype" ) );

	if( !defined $userauthdata )
	{
		&ARCHIVE->log(
			"Unknown user type: ".$user->get_value( "usertype" ) );
		&SESSION->terminate();
		return AUTH_REQUIRED;
	}
	my $authconfig = $userauthdata->{auth};
	my $handler = $authconfig->{handler}; 
	# {handler} should really be removed before passing authconfig
	# to the requestwrapper. cjg

	my $rwrapper = $EPrints::AnApache::RequestWrapper->new( $r , $authconfig );
	my $result = &{$handler}( $rwrapper );
	&SESSION->terminate();
	return $result;
}


######################################################################
=pod

=item $results = EPrints::Auth::authz( $r )

Tests to see if the user making the current request is authorised to
see this URL.

There are three kinds of security area in the system:

=over 4

=item User

The main user area. Noramally /perl/users/. This just returns true -
any valid user can access it. Individual scripts worry about who is 
running them.

=item Documents

This is the secure documents area - for documents of records which
are either not in the public archive, or have a non-public security
option.

In which case it works out which document is being viewed and calls
$doc->can_view( $user ) to decide if it should allow them to view it
or not.

=item ChangeUser

This area is just a way to de-validate the current user, so the user
can log in as some other user. 

=back

=cut
######################################################################

sub authz
{
	my( $r ) = @_;

	EPrints::Session::start;
	# If we are looking at the users section then do nothing, 
	# but if we are looking at a document in the secure area then
	# we need to do some work.

	my $uri = $r->uri;

	my $area = $r->dir_config( "EPrints_Security_Area" );

	if( $area eq "ChangeUser" )
	{
		# All we need here is to check it's a valid user
		# this is a valid user, which we have so let's
		# return OK.

		&SESSION->terminate();
		return OK;
	}

	if( $area eq "User" )
	{
		# All we need in the user area is to check that
		# this is a valid user, which we have so let's
		# return OK.

		&SESSION->terminate();
		return OK;
	}

	if( $area ne "Documents" )
	{
		# Ok, It's not User or Documents which means
		# something screwed up. 

		&ARCHIVE->log( "Request to ".$r->uri." in unknown EPrints HTTP Security area \"$area\"." );
		&SESSION->terminate();
		return FORBIDDEN;
	}

	my $secpath = &ARCHIVE->get_conf( "secure_url_dir" );
	my $urlpath = &ARCHIVE->get_conf( "urlpath" );

	$uri =~ s/^$urlpath$secpath//;
	my $docid;
	my $eprintid;
#	unless( $uri =~ s#^$urlpath## )

	if( $uri =~ m#^/(\d\d\d\d\d\d\d\d)/(\d+)/# )
	{
		# /archive/00000001/01/.....
		# or
		# /$archiveid/archive/00000001/01/.....

		# force it to be integer. (Lose leading zeros)
		$eprintid = $1+0; 
		$docid = "$eprintid-$2";
	}
#	elsif( $uri =~ 
#		m#^$sechostpath$secpath/(\d\d)/(\d\d)/(\d\d)/(\d\d)/(\d+)/# )
#	{
#		# /$archiveid/archive/00/00/00/01/01/.....
#		$eprintid = "$1$2$3$4"+0;
#		$docid = "$eprintid-$5";
#	}
	else
	{

		&ARCHIVE->log( 
"Request to ".$r->uri." in secure documents area failed to match REGEXP." );
		&SESSION->terminate();
		return FORBIDDEN;
	}

	my $user_sent = $r->user;
	my $user = EPrints::User::user_with_username( $user_sent );
	my $document = EPrints::Document->new( $docid );
	unless( $document->can_view( $user ) )
	{
		&SESSION->terminate();
		return FORBIDDEN;
	}	

	&SESSION->terminate();
	return OK;
}

1;

######################################################################
=pod

=back

=cut

