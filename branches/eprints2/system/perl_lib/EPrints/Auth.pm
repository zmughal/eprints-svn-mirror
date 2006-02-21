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
use EPrints::AnApache; # exports apache constants

#use EPrints::Session;
#use EPrints::SystemSettings;


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

	return OK unless $r->is_initial_req; # only the first internal request

	my $session = new EPrints::Session(2); # don't open the CGI info
	
	if( !defined $session )
	{
		return FORBIDDEN;
	}

	my $area = $r->dir_config( "EPrints_Security_Area" );

	if( $area eq "Documents" )
	{
		my $document = secure_doc_from_url( $r, $session );
		if( !defined $document ) 
		{
			$session->terminate();
			return FORBIDDEN;
		}

		my $security = $document->get_value( "security" );

#		if( $security eq "" )
#		{
#			$session->terminate();
#			return OK;
#		}

		my $rule = "REQ_AND_USER";
		if( $session->get_archive->can_call( "document_security_rule" ) )
		{
			$rule = $session->get_archive->call("document_security_rule", $security );
		}
		if( $rule !~ m/^REQ|REQ_AND_USER|REQ_OR_USER$/ )
		{
			$session->get_archive->log( "Bad document_security_rule: '$rule'." );
			$session->terminate();
			return FORBIDDEN;
		}

		my $req_view = 1;
		if( $session->get_archive->can_call( "can_request_view_document" ) )
		{
			$req_view = $session->get_archive->call( "can_request_view_document", $document, $r );
		}

		if( $rule eq "REQ" )
		{
			if( $req_view )
			{
				$session->terminate();
				return OK;
			}

			$session->terminate();
			return FORBIDDEN;
		}

		if( $rule eq "REQ_AND_USER" )
		{
			if( !$req_view )
			{
				$session->terminate();
				return FORBIDDEN;
			}
		}

		if( $rule eq "REQ_OR_USER" )
		{
			if( $req_view )
			{
				$session->terminate();
				return OK;
			}
		}
	}


	my( $res, $passwd_sent ) = $r->get_basic_auth_pw;
	my( $user_sent ) = $r->user;
	if( !defined $user_sent )
	{
		$session->terminate();
		return AUTH_REQUIRED;
	}

	if( $area eq "ChangeUser" )
	{
		my $user_sent = $r->user;
		if( $r->uri !~ m/\/$user_sent$/i )
		{
			return OK;
		}
		
		$r->note_basic_auth_failure;
		return AUTH_REQUIRED;
	}

	my $user_ds = $session->get_archive()->get_dataset( "user" );

	my $user = EPrints::DataObj::User::user_with_username( $session, $user_sent );
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

	my $rwrapper = $EPrints::AnApache::RequestWrapper->new( $r , $authconfig );
	my $result = &{$handler}( $rwrapper );
	$session->terminate();
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

	# If we are looking at the users section then do nothing, 
	# but if we are looking at a document in the secure area then
	# we need to do some work.

	my $session = new EPrints::Session(2); # don't open the CGI info
	my $archive = $session->get_archive;

	my $area = $r->dir_config( "EPrints_Security_Area" );

	if( $area eq "ChangeUser" )
	{
		# All we need here is to check it's a valid user
		# this is a valid user, which we have so let's
		# return OK.

		$session->terminate();
		return OK;
	}

	if( $area eq "User" )
	{
		# All we need in the user area is to check that
		# this is a valid user, which we have so let's
		# return OK.

		$session->terminate();
		return OK;
	}

	if( $area ne "Documents" )
	{
		# Ok, It's not User or Documents which means
		# something screwed up. 

		$archive->log( "Request to ".$r->uri." in unknown EPrints HTTP Security area \"$area\"." );
		$session->terminate();
		return FORBIDDEN;
	}

	my $document = secure_doc_from_url( $r, $session );
	if( !defined $document ) {
		$session->terminate();
		return FORBIDDEN;
	}

	my $security = $document->get_value( "security" );

#	if( $security eq "" )
#	{
#		$session->terminate();
#		return OK;
#	}

	my $rule = "REQ_AND_USER";
	if( $session->get_archive->can_call( "document_security_rule" ) )
	{
		$rule = $session->get_archive->call("document_security_rule", $security );
	}
	# no need to check authen is always called first

	my $req_view = 1;
	if( $session->get_archive->can_call( "can_request_view_document" ) )
	{
		$req_view = $session->get_archive->call( "can_request_view_document", $document, $r );
	}

	if( $rule eq "REQ_AND_USER" )
	{
		if( !$req_view )
		{
			$session->terminate();
			return FORBIDDEN;
		}
	}
	if( $rule eq "REQ_OR_USER" )
	{
		if( $req_view )
		{
			$session->terminate();
			return OK;
		}
	}
	# REQ should not have made it this far.

	my $user_sent = $r->user;
	my $user = EPrints::DataObj::User::user_with_username( $session, $user_sent );
	unless( $document->can_view( $user ) )
	{
		$session->terminate();
		return FORBIDDEN;
	}	


	$session->terminate();
	return OK;
}

######################################################################
=pod

=item $document = EPrints::Auth::secure_doc_from_url( $r, $session )

Return the document that the current URL, in the secure documents area
relates to, if any. Or undef.

=cut
######################################################################


sub secure_doc_from_url
{
	my( $r, $session ) = @_;

	# hack to reduce load. We cache the document in the request object.
	#if( defined $r->{eprint_document} ) { return $r->{eprint_document}; }

	my $archive = $session->{archive};
	my $uri = $r->uri;

	my $secpath = $archive->get_conf( "secure_url_dir" );
	my $esec = $r->dir_config( "EPrints_Secure" );
	my $https = (defined $esec && $esec eq "yes" );
	my $urlpath;
	if( $https ) 
	{ 
		$urlpath = $archive->get_conf( "securepath" );
	}
	else
	{ 
		$urlpath = $archive->get_conf( "urlpath" );
	}

	$uri =~ s/^$urlpath$secpath//;
	my $docid;
	my $eprintid;

	if( $uri =~ m#^/(\d\d\d\d\d\d\d\d)/(\d+)/# )
	{
		# /archive/00000001/01/.....
		# or
		# /$archiveid/archive/00000001/01/.....

		# force it to be integer. (Lose leading zeros)
		$eprintid = $1+0; 
		$docid = "$eprintid-$2";
	}
	else
	{
		$archive->log( 
"Request to ".$r->uri." in secure documents area failed to match REGEXP." );
		return undef;
	}
	my $document = EPrints::DataObj::Document->new( $session, $docid );
	if( !defined $document ) {
		$archive->log( 
"Request to ".$r->uri.": document $docid not found." );
		return undef;
	}

	# cache $document in the request object
	#$r->{eprint_document} = $document;


	return $document;
}

=pod

=item @roles = EPrints::Auth::user_roles( $user, [$dataobj] )

Return the roles $user has, optionally also roles available for $dataobj.

=cut

sub user_roles
{
	my( $user, $dataobj ) = @_;
	my @roles;

	if( defined( $user ) ) {
		# A user might have administrative permission for another
		# user
		push @roles, $user->user_roles( $dataobj );
		# I don't think dataobj could have a role that isn't dependent
		# on the $user?
		if( defined( $dataobj ) ) {
			push @roles, $dataobj->user_roles( $user );
		}
	}

	return @roles;
}

=pod

=item @roles = EPrints::Auth::has_privilege( $session, $privilege, [$user, [$dataobj]] )

Returns a list of roles available for privilege. If L<$user|EPrints::DataObj::User> is defined finds additional roles available to them. If L<$dataobj|EPrints::DataObj> is defined adds the roles that $user might have on $dataobj.

=cut

sub has_privilege
{
	my ($session, $priv, $user, $dataobj) = @_;
	my @roles = qw( anonymous ); # User can always be anonymous
	my @permitted_roles;

	my $func = $session->get_archive->get_conf( "user_roles" );
	$func ||= \&EPrints::Auth::user_roles;

	push @roles, &{$func}( $user, $dataobj );

	# Admin 'god-mode'
	if( grep { $_ eq 'usertype.admin' } @roles ) {
		push @roles, 'usertype.admin';
	}

	# TODO: Replace undef with remote IP address (if available)
	push @permitted_roles, $session->get_db->get_roles( $priv, undef, @roles );

	return @permitted_roles;
}

1;

######################################################################
=pod

=back

=cut

