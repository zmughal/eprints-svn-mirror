######################################################################
#
# EPrints::DataObj::User
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

B<EPrints::DataObj::User> - Class representing a single user.

=head1 DESCRIPTION

This class represents a single eprint user record and the metadata 
associated with it. 

EPrints::DataObj::User is a subclass of EPrints::DataObj with the following
metadata fields (plus those defined in ArchiveMetadataFieldsConfig:

=head1 SYSTEM METADATA

=over 4

=item userid (int)

The unique ID number of this user record. Unique within the current repository.

=item rev_number (int)

The revision number of this record. Each time it is changed the revision
number is increased. This is not currently used for anything but it may
be used for logging later.

=item username (text)

The username of this user. Used for logging into the system. Unique within
this repository.

=item password (secret)

The password of this user encoded with crypt. This may be ignored if the
repository is using an alternate authentication system, eg. LDAP.

=item usertype (datatype)

The type of this user. The options are configured in metadata-phrases.xml.

=item newemail (email)

Used to store a new but as yet unconfirmed email address.

=item newpassword (secret)

Used to store a new but as yet unconfirmed password.

=item pin (text)

A code required to confirm a new username or password. This code is emailed
to the user to confirm they are who they say they are.

=item pinsettime (int)

When the pin code was set, so we can make it time out.

=item joined (time)

The date and time that the user account was created. Before EPrints 2.4 this
was a date field so users created before the upgrade will appear to have been 
created at midnight.

=item email (email)

The email address of this user. Unique within the repository. 

=item lang (datatype) 

The ID of the prefered language of this user. Only really used in multilingual
repositories.

=item editperms (search, multiple)

This field is used to filter what eprints a staff member can approve and 
modify. If it's unset then they can modify any (given the correct privs. but
if it is set then an eprint must match at least one of the searches to be
within their scope.

=item frequency (set)

Only relevant to staff accounts. Is the frequency they want to be mailed 
about eprints matching their scope that are in editorial review. never, 
daily, weekly or monthly.

=item mailempty (boolean)

Only relevant to staff accounts. If set to true then emails are sent
even if there are no items matching the scope.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::User;

@ISA = ( 'EPrints::DataObj' );

use EPrints;
use EPrints::SearchExpression;

use strict;


######################################################################
=pod

=item $field_info = EPrints::DataObj::User->get_system_field_info

Return an array describing the system metadata of the this 
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"userid", type=>"int", required=>1 },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

		{ name=>"subscriptions", type=>"subobject", datasetid=>'subscription',
			multiple=>1 },

		{ name=>"username", type=>"text", required=>1 },

		{ name=>"password", type=>"secret", show_in_html=>0,
			fromform=>\&EPrints::Utils::crypt_password },

		{ name=>"usertype", type=>"datatype", required=>1, 
			datasetid=>"user" },
	
		{ name=>"newemail", type=>"email", show_in_html=>0 },
	
		{ name=>"newpassword", type=>"secret", show_in_html=>0, 
			fromform=>\&EPrints::Utils::crypt_password },

		{ name=>"pin", type=>"text", show_in_html=>0 },

		{ name=>"pinsettime", type=>"int", show_in_html=>0 },

		{ name=>"joined", type=>"time", required=>1 },

		{ name=>"email", type=>"email", required=>1 },

		{ name=>"lang", type=>"datatype", required=>0, 
			datasetid=>"arclanguage", input_rows=>1 },

		{ name => "editperms", 
			multiple => 1,
			input_add_boxes => 1,
			input_boxes => 1,
			type => "search", 
			datasetid => "buffer",
			fieldnames => "editpermfields",
			allow_set_order => 0 },

		{ name=>"frequency", type=>"set", 
			options=>["never","daily","weekly","monthly"] },

		{ name=>"mailempty", type=>"boolean", input_style=>"radio" }
	)
};



######################################################################
=pod

=item $user = EPrints::DataObj::User->new( $session, $userid )

Load the user with the ID of $userid from the database and return
it as an EPrints::DataObj::User object.

=cut
######################################################################

sub new
{
	my( $class, $session, $userid ) = @_;

	return $session->get_db()->get_single( 
		$session->get_repository->get_dataset( "user" ),
		$userid );
}


######################################################################
=pod

=item $user = EPrints::DataObj::User->new_from_data( $session, $data )

Construct a new EPrints::DataObj::User object based on the $data hash 
reference of metadata.

Used to create an object from the data retrieved from the database.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data ) = @_;

	my $self = {};
	bless $self, $class;
	$self->{data} = $data;
	$self->{dataset} = $session->get_repository->get_dataset( "user" );
	$self->{session} = $session;

	return( $self );
}


######################################################################
=pod

=item $user = EPrints::DataObj::User::create( $session, $user_type )

Create a new user in the database with the specified user type.

=cut
######################################################################

sub create
{
	my( $session, $user_type ) = @_;


	return EPrints::DataObj::User->create_from_data( 
		$session, 
		{ usertype=>$user_type },
		$session->get_repository->get_dataset( "user" ) );
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::User->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	my $userid = _create_userid( $session );

	my $date_joined = EPrints::Utils::get_datetimestamp( time );

	my $defaults = { 
		"userid"=>$userid,
		"joined"=>$date_joined,
		"frequency"=>'never',
		"mailempty"=>"FALSE",
		"rev_number"=>1,
	};

	$session->get_repository->call(
		"set_user_defaults",
		$defaults,
		$session );

	return $defaults;
}



######################################################################
=pod

=item $user = EPrints::DataObj::User::user_with_email( $session, $email )

Return the EPrints::user with the specified $email, or undef if they
are not found.

=cut
######################################################################

sub user_with_email
{
	my( $session, $email ) = @_;
	
	my $user_ds = $session->get_repository->get_dataset( "user" );

	my $searchexp = new EPrints::SearchExpression(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "email" ),
		$email );

	my $searchid = $searchexp->perform_search;
	my @records = $searchexp->get_records;
	$searchexp->dispose();
	
	return $records[0];
}


######################################################################
=pod

=item $user = EPrints::DataObj::User::user_with_username( $session, $username )

Return the EPrints::user with the specified $username, or undef if 
they are not found.

=cut
######################################################################

sub user_with_username
{
	my( $session, $username ) = @_;
	
	my $user_ds = $session->get_repository->get_dataset( "user" );

	my $searchexp = new EPrints::SearchExpression(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "username" ),
		$username,
		"EX" );

	my $searchid = $searchexp->perform_search;

	my @records = $searchexp->get_records;
	$searchexp->dispose();
	
	return $records[0];
}


######################################################################
=pod

=item $problems = $thing->validate

Validate the user - find out if all the required fields are filled
out, and that what's been filled in is OK. Returns a reference to an
array of problem descriptions.

If there are no probelms then the array is empty.

The problems are XHTML DOM objects describing the problem.

=cut
######################################################################

sub validate
{
	my( $self ) = @_;

	my @all_problems;
	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );
	my @rfields = $user_ds->get_required_type_fields( $self->get_value( "usertype" ) );
	my @all_fields = $user_ds->get_fields();

	my $field;
	foreach $field ( @rfields )
	{
		# Check that the field is filled in if it is required
		if( !$self->is_set( $field->get_name() ) )
		{
			push @all_problems, 
			  $self->{session}->html_phrase( 
			   "lib/user:missed_field", 
			   field => $field->render_name( $self->{session} ) );
		}
	}

	# Give the validation module a go
	foreach $field ( @all_fields )
	{
		push @all_problems, $self->{session}->get_repository->call(
			"validate_field",
			$field,
			$self->get_value( $field->get_name() ),
			$self->{session},
			0 );
	}

	push @all_problems, $self->{session}->get_repository->call(
			"validate_user",
			$self,
			$self->{session} );

	return( \@all_problems );
}


######################################################################
=pod

=item $user->commit( [$force] )

Write this object to the database.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	$self->{session}->get_repository->call( 
		"set_user_automatic_fields", 
		$self );
	
	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	

	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );
	my $success = $self->{session}->get_db()->update(
		$user_ds,
		$self->{data} );
	
	$self->queue_changes;

	return( $success );
}



######################################################################
=pod

=item $success = $user->remove

Remove this user from the database. Also, remove their subscriptions,
but do not remove their eprints.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	my $success = 1;

	my $subscription;
	foreach $subscription ( $self->get_subscriptions() )
	{
		$subscription->remove();
	}

	# remove user record
	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );
	$success = $success && $self->{session}->get_db()->remove(
		$user_ds,
		$self->get_value( "userid" ) );
	
	return( $success );
}


######################################################################
=pod

=item $boolean = $user->has_priv( $privtype )

Return true if the user is allowed to perform tasks of type $privtype.

=cut
######################################################################

sub has_priv
{
	my( $self, $resource ) = @_;

	my $userprivs = $self->{session}->get_repository->
		get_conf( "userauth", $self->get_value( "usertype" ), "priv" );

	foreach my $priv ( @{$userprivs} )
	{
		return 1 if( $priv eq $resource );
	}

	return 0;
}


######################################################################
=pod

=item $list = $user->get_eprints( $dataset )

Return EPrints in the given EPrints::DataSet which have this user
as their creator.

Since 2.4 this returns an EPrints::List object, not an array of eprints.

=cut
######################################################################

sub get_eprints
{
	my( $self , $ds ) = @_;

	my $searchexp = new EPrints::SearchExpression(
		session=>$self->{session},
		custom_order=>"eprintid",
		dataset=>$ds );

	$searchexp->add_field(
		$ds->get_field( "userid" ),
		$self->get_value( "userid" ) );

	return $searchexp->perform_search;
}

######################################################################
=pod

=item $list = $user->get_editable_eprints

Return eprints currently in the editorial review buffer. If this user
has editperms set then only return those records which match.

Since 2.4 this returns an EPrints::List object, not an array of eprints.

=cut
######################################################################

sub get_editable_eprints
{
	my( $self ) = @_;

	unless( $self->is_set( 'editperms' ) )
	{
		my $ds = $self->{session}->get_repository->get_dataset( 
			"buffer" );
		my $searchexp = EPrints::SearchExpression->new(
			allow_blank => 1,
			custom_order => "-datestamp",
			dataset => $ds,
			session => $self->{session} );
		return $searchexp->perform_search;
	}

	my $editperms = $self->{dataset}->get_field( "editperms" );
	my $list = undef;
	foreach my $sv ( @{$self->get_value( 'editperms' )} )
	{
		my $searchexp = $editperms->make_searchexp(
			$self->{session},
			$sv );
		$searchexp->{custom_order}="-datestamp";
	        $searchexp->{order} = $EPrints::SearchExpression::CustomOrder;

		my $newlist = $searchexp->perform_search;
		if( defined $list )
		{
			$list = $list->merge( $newlist );
		}
		else
		{
			$list = $newlist;
		}
	}
	return $list;
}

######################################################################
=pod

=item $list = $user->get_owned_eprints( $dataset );

Return a list of the eprints which this user owns. This is by default
the same as $user->get_eprints( $dataset) but may be over-ridden by
get_users_owned_eprints.

Since 2.4 this returns an EPrints::List object, not an array of eprints.

=cut
######################################################################

sub get_owned_eprints
{
	my( $self, $ds ) = @_;

	my $fn = $self->{session}->get_repository->get_conf( "get_users_owned_eprints" );

	if( !defined $fn )
	{
		return $self->get_eprints( $ds );
	}

	my $result = &$fn( $self->{session}, $self, $ds );
	unless( $result->isa( "EPrints::List" ) )
	{
		EPrints::Config::abort( "get_users_owned_eprints should now return an EPrints::List object." );
	}
	return $result;
}

######################################################################
=pod

=item $boolean = $user->is_owner( $eprint )

True if this user "owns" the given $eprint. By default this is true
if the eprint was created by this user, but this rule can be 
overridden by the config option "does_user_own_eprint".

=cut
######################################################################

sub is_owner
{
	my( $self, $eprint ) = @_;

	my $fn = $self->{session}->get_repository->get_conf( "does_user_own_eprint" );

	if( !defined $fn )
	{
		if( $eprint->get_value( "userid" ) == $self->get_value( "userid" ) )
		{
			return 1;
		}
		return 0;
	}

	return &$fn( $self->{session}, $self, $eprint );
}




######################################################################
=pod

=item $ok = $user->mail( $subjectid, $message, [$replyto], [$email] )

Send an email to this user. 

$subjectid is the ID of a phrase to use as the subject of this email.

$message is an XML DOM object describing the message in simple XHTML.

$replyto is the reply to address for this email, if different to the
repository default.

$email is the email address to send this email to if different from
this users configured email address.

Return true if the email was sent OK.

=cut
######################################################################

sub mail
{
	my( $self,   $subjectid, $message, $replyto,  $email ) = @_;
	#   User   , string,     DOM,      User/undef Other Email

	# Mail the admin in the default language
	my $langid = $self->get_value( "lang" );
	my $lang = $self->{session}->get_repository->get_language( $langid );

	my $remail;
	my $rname;
	if( defined $replyto )
	{
		$remail = $replyto->get_value( "email" );
		$rname = EPrints::Utils::tree_to_utf8( $replyto->render_description() );
	}
	if( !defined $email )
	{
		$email = $self->get_value( "email" );
	}

	return EPrints::Utils::send_mail(
		$self->{session}->get_repository,
		$langid,
		EPrints::Utils::tree_to_utf8( $self->render_description ),
		$email,
		EPrints::Utils::tree_to_utf8( $lang->phrase( $subjectid, {}, $self->{session} ) ),
		$message,
		$lang->phrase( "mail_sig", {}, $self->{session} ),
		$remail,
		$rname ); 
}



######################################################################
# 
# $userid = EPrints::DataObj::User::_create_userid( $session )
#
# Get the next unused userid value.
#
######################################################################

sub _create_userid
{
	my( $session ) = @_;
	
	my $new_id = $session->get_db()->counter_next( "userid" );

	return( $new_id );
}


######################################################################
=pod

=item ( $page, $title ) = $user->render

Render this user into HTML using the "user_render" method in
ArchiveRenderConfig.pm. Returns both the rendered information and
the title as XHTML DOM.

=cut
######################################################################

sub render
{
	my( $self ) = @_;

	my( $dom, $title ) = $self->{session}->get_repository->call( "user_render", $self, $self->{session} );

	if( !defined $title )
	{
		$title = $self->render_description;
	}

	return( $dom, $title );
}

# This should include all the info, not just that presented to the public.

######################################################################
=pod

=item ( $page, $title ) = $user->render_full

The same as $user->render, but renders all fields, not just those 
intended for public viewing. This is the admin view of the user.

=cut
######################################################################

sub render_full
{
	my( $self ) = @_;

	my( $table, $title ) = $self->SUPER::render_full;

	my @subs = $self->get_subscriptions;
	my $subs_ds = $self->{session}->get_repository->get_dataset( "subscription" );
	foreach my $subscr ( @subs )
	{
		my $rowright = $self->{session}->make_doc_fragment;
		foreach( "frequency","spec","mailempty" )
		{
			my $strong;
			$strong = $self->{session}->make_element( "strong" );
			$strong->appendChild( $subs_ds->get_field( $_ )->render_name( $self->{session} ) );
			$strong->appendChild( $self->{session}->make_text( ": " ) );
			$rowright->appendChild( $strong );
			$rowright->appendChild( $subscr->render_value( $_ ) );
			$rowright->appendChild( $self->{session}->make_element( "br" ) );
		}
		$table->appendChild( $self->{session}->render_row(
			$self->{session}->html_phrase(
				"page:subscription" ),
			$rowright ) );
				
	}

	return( $table, $title );
}


######################################################################
=pod

=item $url = $user->get_url( [$staff] )

Return the URL which will display information about this user.

If $staff is true then return the URL for an administrator to view
and modify this record.

=cut
######################################################################

sub get_url
{
	my( $self , $staff ) = @_;

	if( defined $staff && $staff )
	{
		return $self->{session}->get_repository->get_conf( "perl_url" )."/users/staff/view_user?userid=".$self->get_value( "userid" );

	}

	return $self->{session}->get_repository->get_conf( "perl_url" )."/user?userid=".$self->get_value( "userid" );
}


######################################################################
=pod

=item $type = $user->get_type

Return the type of this user. Equivalent of 
$user->get_value( "usertype" );

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return $self->get_value( "usertype" );
}


######################################################################
=pod

=item @subscriptions = $eprint->get_subscriptions

Return an array of all EPrint::Subscription objects associated with this
user.

=cut
######################################################################

sub get_subscriptions
{
	my( $self ) = @_;

	my $subs_ds = $self->{session}->get_repository->get_dataset( 
		"subscription" );

	my $searchexp = EPrints::SearchExpression->new(
		session=>$self->{session},
		dataset=>$subs_ds,
		custom_order=>"subid" );

	$searchexp->add_field(
		$subs_ds->get_field( "userid" ),
		$self->get_value( "userid" ) );

	my $searchid = $searchexp->perform_search();
	my @subs = $searchexp->get_records();
	$searchexp->dispose();

	return( @subs );
}


######################################################################
=pod

=item $user->send_out_editor_alert

Called on users who are editors, when it's time to send their update
on what items are in the editorial review buffer.

Sends the email if needed.

=cut
######################################################################

sub send_out_editor_alert
{
	my( $self ) = @_;

	my $freq = $self->get_value( "frequency" );


	if( $freq eq "never" )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out an editor alert for a user\n".
			"which has frequency 'never'\n" );
		return;
	}

	unless( $self->has_priv( "editor" ) )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out an editor alert for a user\n".
			"which does not have editor priv (".
			$self->get_value("username").")\n" );
		return;
	}
		
	my $origlangid = $self->{session}->get_langid;
	
	$self->{session}->change_lang( $self->get_value( "lang" ) );

	my $list = $self->get_editable_eprints;

	if( $list->count > 0 || $self->get_value( "mailempty" ) eq 'TRUE' )
	{
		my $url = $self->{session}->get_repository->get_conf( "perl_url" ).
			"/users/record";
		my $freqphrase = $self->{session}->html_phrase(
			"lib/subscription:".$freq ); # nb. reusing the subscription.pm phrase
		my $searchdesc = $self->render_value( "editperms" );

		my $matches = $self->{session}->make_doc_fragment;

		$list->map( sub {
			my( $session, $dataset, $eprint ) = @_;

			my $p = $self->{session}->make_element( "p" );
			$p->appendChild( $eprint->render_citation );
			$matches->appendChild( $p );
			$matches->appendChild( $self->{session}->make_text( $eprint->get_url( 1 ) ) );
			$matches->appendChild( $self->{session}->make_element( "br" ) );
		} );

		my $mail = $self->{session}->html_phrase( 
				"lib/user:editor_update_mail",
				howoften => $freqphrase,
				n => $self->{session}->make_text( $list->count ),
				search => $searchdesc,
				matches => $matches,
				url => $self->{session}->make_text( $url ) );
		$self->mail( 
			"lib/user:editor_update_subject",
			$mail );
		EPrints::XML::dispose( $mail );
	}

	$self->{session}->change_lang( $origlangid );
}


######################################################################
=pod

=item EPrints::DataObj::User::process_editor_alerts( $session, $frequency );

Static method.

Called to send out all editor alerts of a given frequency (daily,
weekly, monthly) for the current repository.

=cut
######################################################################

sub process_editor_alerts
{
	my( $session, $frequency ) = @_;

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		$session->get_repository->log( "EPrints::DataObj::User::process_editor_alerts called with unknown frequency: ".$frequency );
		return;
	}

	my $subs_ds = $session->get_repository->get_dataset( "user" );

	my $searchexp = EPrints::SearchExpression->new(
		session => $session,
		dataset => $subs_ds );

	$searchexp->add_field(
		$subs_ds->get_field( "frequency" ),
		$frequency );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		return unless( $item->has_priv( "editor" ) );

		$item->send_out_editor_alert;
		if( $session->get_noise >= 2 )
		{
			print "Sending out editor alert for ".$item->get_value( "username" )."\n";
		}
	};

	$searchexp->perform_search;
	$searchexp->map( $fn, {} );
	$searchexp->dispose;

	# currently no timestamp for editor alerts 
}

######################################################################
=pod

=item @roles = $user->user_roles( [$user] )

Return the roles the user has and anything that the user can do to $user.

=cut
######################################################################

sub user_roles
{
	my ($self, $user) = @_;
	my @roles;
	
	# Can always be ourselves
	push @roles, $self->get_value( "userid" );
	
	# Set our usertype
	push @roles, "usertype." . $self->get_type();

	# Can $self do something to $user ?
	if( defined( $user ) )
	{
		if( $self->get_value( "userid" ) eq $user->get_value( "userid" ) ) {
			push @roles, qw( user.owner );
		}
	}
	
	return @roles;
}

######################################################################
=pod

=item $boolean = $user->can_edit( $eprint )

Returns true if $user can edit $eprint (according to editperms).

=cut
######################################################################

sub can_edit
{
	my( $user, $eprint ) = @_;
	my $session = $user->{session};

	my $user_ds = $session->get_repository->get_dataset( "user" );

	my $ef_field = $user_ds->get_field( 'editperms' );
	my $searches = $session->current_user->get_value( 'editperms' );
	if( scalar @{$searches} == 0 )
	{
		return 1;
	}

	foreach my $s ( @{$searches} )
	{
		my $search = $ef_field->make_searchexp( $session, $s );
		if( $search->get_conditions->item_matches( $eprint ) )
		{
			$search->dispose;
			return 1;
		}
		$search->dispose;
	}

	return 0;
}






1;

######################################################################
=pod

=back

=cut

