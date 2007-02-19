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

=item usertype (namedset)

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

=item lang (namedset) 

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
use EPrints::Search;

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
		{ name=>"userid", type=>"int", required=>1, import=>0 },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

		{ name=>"saved_searches", type=>"subobject", datasetid=>'saved_search',
			multiple=>1 },

		{ name=>"username", type=>"text", required=>1 },

		{ name=>"password", type=>"secret", show_in_html=>0,
			fromform=>\&EPrints::Utils::crypt_password },

		{ name=>"usertype", type=>"namedset", required=>1, 
			set_name=>"user", input_style=>"medium" },
	
		{ name=>"newemail", type=>"email", show_in_html=>0 },
	
		{ name=>"newpassword", type=>"secret", show_in_html=>0, 
			fromform=>\&EPrints::Utils::crypt_password },

		{ name=>"pin", type=>"text", show_in_html=>0 },

		{ name=>"pinsettime", type=>"int", show_in_html=>0 },

		{ name=>"joined", type=>"time", required=>1 },

		{ name=>"email", type=>"email", required=>1 },

		{ name=>"lang", type=>"arclanguage", required=>0, 
			input_rows=>1 },

		{ name => "editperms", 
			multiple => 1,
			input_ordered => 0,
			input_add_boxes => 1,
			input_boxes => 1,
			type => "search", 
			datasetid => "eprint",
			fieldnames => "editpermfields",
		},

		{ name => "permission_group", multiple => 1, type => "namedset", 
			set_name => "permission_group", },

		{ name=>"frequency", type=>"set", input_style=>"medium",
			options=>["never","daily","weekly","monthly"] },

		{ name=>"mailempty", type=>"boolean", input_style=>"radio" },

		{ name=>"items_fields", type=>"fields", datasetid=>"eprint", multiple=>1, input_ordered=>1 },

		{ name=>"review_fields", type=>"fields", datasetid=>"eprint", multiple=>1, input_ordered=>1 },

		{ name=>"latitude", type=>"float", required=>0 },

		{ name=>"longitude", type=>"float", required=>0 },

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

	return $session->get_database->get_single( 
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
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "user" ) );
}



######################################################################
# =pod
# 
# =item $user = EPrints::DataObj::User::create( $session, $user_type )
# 
# Create a new user in the database with the specified user type.
# 
# =cut
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

	my $date_joined = EPrints::Time::get_iso_timestamp();

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

	my $searchexp = new EPrints::Search(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "email" ),
		$email );

	my $searchid = $searchexp->perform_search;
	my @records = $searchexp->get_records(0,1);
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

	my $searchexp = new EPrints::Search(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "username" ),
		$username,
		"EX" );

	my $results = $searchexp->perform_search;
	my @records = $results->get_records(0,1);
	
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

	my @problems;

	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );

	my %opts = ( item=> $self, session=>$self->{session} );
 	my $workflow = EPrints::Workflow->new( $self->{session}, "default", %opts );

	push @problems, $workflow->validate;

	push @problems, $self->{session}->get_repository->call(
			"validate_user",
			$self,
			$self->{session} );

	return( \@problems );
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
	$self->tidy;
	my $success = $self->{session}->get_database->update(
		$user_ds,
		$self->{data} );
	
	$self->queue_changes;

	return( $success );
}



######################################################################
=pod

=item $success = $user->remove

Remove this user from the database. Also, remove their saved searches,
but do not remove their eprints.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	my $success = 1;

	foreach my $saved_search ( $self->get_saved_searches )
	{
		$saved_search->remove;
	}

	# remove user record
	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );
	$success = $success && $self->{session}->get_database->remove(
		$user_ds,
		$self->get_value( "userid" ) );
	
	return( $success );
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

	my $searchexp = new EPrints::Search(
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
		my $searchexp = EPrints::Search->new(
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
	        $searchexp->{order} = $EPrints::Search::CustomOrder;

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
		EPrints::abort( "get_users_owned_eprints should now return an EPrints::List object." );
	}
	return $result;
}

######################################################################
=pod

=item $boolean = $user->has_owner( $possible_owner )

True if the users are the same record.

=cut
######################################################################

sub has_owner
{
	my( $self, $possible_owner ) = @_;

	if( $possible_owner->get_value( "userid" ) == $self->get_value( "userid" ) )
	{
		return 1;
	}

	return 0;
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

	return EPrints::Email::send_mail(
		session  => $self->{session},
		langid   => $langid,
		to_name  => EPrints::Utils::tree_to_utf8( $self->render_description ),
		to_email => $email,
		subject  => EPrints::Utils::tree_to_utf8( $lang->phrase( $subjectid, {}, $self->{session} ) ),
		message  => $message,
		sig      => $lang->phrase( "mail_sig", {}, $self->{session} ),
		replyto_name  => $rname, 
		replyto_email => $remail,
	); 
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
	
	my $new_id = $session->get_database->counter_next( "userid" );

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

	my $ds = $self->{session}->get_repository->get_dataset( "saved_search" );
	foreach my $saved_search ( $self->get_saved_searches )
	{
		my $rowright = $self->{session}->make_doc_fragment;
		foreach( "frequency","spec","mailempty" )
		{
			my $strong;
			$strong = $self->{session}->make_element( "strong" );
			$strong->appendChild( $ds->get_field( $_ )->render_name( $self->{session} ) );
			$strong->appendChild( $self->{session}->make_text( ": " ) );
			$rowright->appendChild( $strong );
			$rowright->appendChild( $saved_search->render_value( $_ ) );
			$rowright->appendChild( $self->{session}->make_element( "br" ) );
		}
		$table->appendChild( $self->{session}->render_row(
			$self->{session}->html_phrase(
				"page:saved_search" ),
			$rowright ) );
				
	}

	return( $table, $title );
}


######################################################################
=pod

=item $url = $user->get_url

Return the URL which will display information about this user.

If $staff is true then return the URL for an administrator to view
and modify this record.

=cut
######################################################################

sub get_url
{
	my( $self ) = @_;

	return $self->{session}->get_repository->get_conf( "perl_url" )."/users/home?screen=User::View&userid=".$self->get_value( "userid" );
}

sub get_control_url
{
	my( $self ) = @_;

	return $self->{session}->get_repository->get_conf( "perl_url" )."/users/home?screen=User::View&userid=".$self->get_value( "userid" );
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

=item @saved_searches = $eprint->get_saved_searches

Return an array of all EPrint::DataObj::SavedSearch objects associated with this
user.

=cut
######################################################################

sub get_saved_searches
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset( 
		"saved_search" );

	my $searchexp = EPrints::Search->new(
		session=>$self->{session},
		dataset=>$ds,
		custom_order=>"id" );

	$searchexp->add_field(
		$ds->get_field( "userid" ),
		$self->get_value( "userid" ) );

	my $searchid = $searchexp->perform_search;
	my @results = $searchexp->get_records;
	$searchexp->dispose;

	return( @results );
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
			"lib/saved_search:".$freq ); # nb. reusing the SavedSearch.pm phrase
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
				url => $self->{session}->render_link( $url ) );
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

	my $searchexp = EPrints::Search->new(
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





# Privs and Role related methods

# this maps roles onto privs
my $PRIVMAP = 
{

	general => 
	{
		"user/view" => 2,
	},

	"edit-own-record" => 
	{
		"user/edit" => 4,
	},
		
	"set-password" => 
	{
		"set-password" => 2,
	},

	"change-email" => 
	{
		# not done
	},

	"change-user" => 
	{
		# not done
	},

	"staff-view" => 
	{
		# still needs search tools

		"eprint/inbox/view" => 2,
		"eprint/inbox/summary" => 2,
		"eprint/inbox/staff/export" => 2,
		"eprint/inbox/staff/details" => 2,
		"eprint/inbox/history" => 2,

		"eprint/buffer/view" => 2,
		"eprint/buffer/summary" => 2,
		"eprint/buffer/staff/export" => 2,
		"eprint/buffer/staff/details" => 2,
		"eprint/buffer/history" => 2,

		"eprint/archive/view" => 2,
		"eprint/archive/summary" => 2,
		"eprint/archive/staff/export" => 2,
		"eprint/archive/staff/details" => 2,
		"eprint/archive/history" => 2,

		"eprint/deletion/view" => 2,
		"eprint/deletion/summary" => 2,
		"eprint/deletion/staff/export" => 2,
		"eprint/deletion/staff/details" => 2,
		"eprint/deletion/history" => 2,

		"staff/eprint_search" => 2,
	},
	
	"view-status" => 
	{
		"status" => 1,
	},

	"admin" =>
	{
		"config/reload" => 2,
		"indexer/stop" => 2,
		"indexer/start" => 2,
		"indexer/force_start" => 2,
		"user/remove" => 8,
		"user/view" => 8,
		"user/history" => 8,
		"user/staff/edit" => 8,
		"create_user" => 2,
		"subject/edit" => 8,
		"staff/user_search" => 2,
		"staff/history_search" => 2,
	},

	"saved-searches" => 
	{
		"saved_search" => 2,
		"create_saved_search" => 2,
		"saved_search/view" => 4,
		"saved_search/perform" => 4,
		"saved_search/edit" => 4,
		"saved_search/remove" => 4,
	},

	deposit => 
	{
		"items" => 2,
		"create_eprint" => 2,
		"user/history" => 4,
	
		"eprint/inbox/view" => 4,
		"eprint/inbox/summary" => 4,
		"eprint/inbox/deposit" => 4,
		"eprint/inbox/edit" => 4,
		"eprint/inbox/remove" => 4,
		"eprint/inbox/export" => 4,
		"eprint/inbox/details" => 4,
		"eprint/inbox/history" => 4,
		"eprint/inbox/messages" => 4,
	
		"eprint/inbox/deposit" => 4,
		"eprint/inbox/use_as_template" => 4,
		"eprint/inbox/derive_version" => 4,
	
	
		"eprint/buffer/view" => 4,
		"eprint/buffer/summary" => 4,
		"eprint/buffer/move_inbox" => 4,
		"eprint/buffer/export" => 4,
		"eprint/buffer/details" => 4,
		"eprint/buffer/history" => 4,
		"eprint/buffer/messages" => 4,
	
		"eprint/buffer/request_removal" => 4,
		"eprint/buffer/use_as_template" => 4,
		"eprint/buffer/derive_version" => 4,
	
	
		"eprint/archive/view" => 4,
		"eprint/archive/summary" => 4,
		"eprint/archive/export" => 4,
		"eprint/archive/details" => 4,
		"eprint/archive/history" => 4,
		"eprint/archive/messages" => 4,
	
		"eprint/archive/request_removal" => 4,
		"eprint/archive/use_as_template" => 4,
		"eprint/archive/derive_version" => 4,
	

		"eprint/deletion/view" => 4,
		"eprint/deletion/summary" => 4,
		"eprint/deletion/export" => 4,
		"eprint/deletion/details" => 4,
		"eprint/deletion/history" => 4,
		"eprint/deletion/messages" => 4,
	
		"eprint/deletion/use_as_template" => 4,
		"eprint/deletion/derive_version" => 4,
	},

	editor => 
	{
		"editorial_review" => 2,

		"eprint/inbox/view" => 8,
		"eprint/inbox/summary" => 8,
		"eprint/inbox/staff/export" => 8,
		"eprint/inbox/staff/details" => 8,
		"eprint/inbox/history" => 8,
		"eprint/inbox/messages" => 8,

		"eprint/inbox/remove_with_email" => 8,
		"eprint/inbox/move_archive" => 8,
		"eprint/inbox/move_buffer" => 8,
		"eprint/inbox/use_as_template" => 8,
		"eprint/inbox/derive_version" => 8,
		"eprint/inbox/staff/edit" => 8,


		"eprint/buffer/view" => 8,
		"eprint/buffer/summary" => 8,
		"eprint/buffer/staff/export" => 8,
		"eprint/buffer/staff/details" => 8,
		"eprint/buffer/history" => 8,
		"eprint/buffer/messages" => 8,

		"eprint/buffer/remove_with_email" => 8,
		"eprint/buffer/reject_with_email" => 8,
		"eprint/buffer/move_inbox" => 8,
		"eprint/buffer/move_archive" => 8,
		"eprint/buffer/use_as_template" => 8,
		"eprint/buffer/derive_version" => 8,
		"eprint/buffer/staff/edit" => 8,


		"eprint/archive/view" => 8,
		"eprint/archive/summary" => 8,
		"eprint/archive/staff/export" => 8,
		"eprint/archive/staff/details" => 8,
		"eprint/archive/history" => 8,
		"eprint/archive/messages" => 8,

		"eprint/archive/move_buffer" => 8,
		"eprint/archive/move_deletion" => 8,
		"eprint/archive/use_as_template" => 8,
		"eprint/archive/derive_version" => 8,
		"eprint/archive/staff/edit" => 8,


		"eprint/deletion/view" => 8,
		"eprint/deletion/summary" => 8,
		"eprint/deletion/staff/export" => 8,
		"eprint/deletion/staff/details" => 8,
		"eprint/deletion/history" => 8,
		"eprint/deletion/messages" => 8,

		"eprint/deletion/move_archive" => 8,
		"eprint/deletion/use_as_template" => 8,
		"eprint/deletion/derive_version" => 8,
		#"eprint/archive/staff/edit" => 8,
	},
	
};



######################################################################
=pod

=item $result = $user->allow( $priv, [$item] )

Rleturns true if $user can perform this action/view this screen.

A true result is 1..15 where the value indicates what about the user
allowed the priv to be performed. This is used for filtering owner/
editor actions in eprint control screens.

1 = anybody (not currently used)
2 = only if logged in 
4 = only if owner of item
8 = only if editor of item

For non item related privs the result will normally be 2.

Nb. That create eprint is NOT a priv related to an eprint, as you 
don't own it at that stage.

=cut
######################################################################

sub allow
{
	my( $self, $priv, $item ) = @_;

	return 1 if( $self->{session}->allow_anybody( $priv ) );

	my $r = $self->get_privs->{$priv} || 0;

	if( !($r & 3 ) && ( $r & 4 || $r & 8 ) && !defined $item )
	{
		$self->{session}->get_repository->log(
"\$user->allow( $priv ) called. It returned a value of $r which meant it needed an item to resolve the permission, but none was passed. Assuming false, but this may indicate a bug." );
		return 0;
	}

	if( $r & 4 )
	{
		if( !defined $item || !$item->has_owner( $self ) )
		{
			$r-=4;
		}
	}

	if( $r & 8 )
	{
		if( !defined $item || !$item->in_editorial_scope_of( $self ) )
		{
			$r-=8;
		}
	}

	return $r;
}

######################################################################
#
# $privs = $user->get_privs;
#
# Return the privs a user has. Currently just based on roles, but 
# could do more later. Returns a reference to a hash. Caches the 
# result to save time.
#
######################################################################

sub get_privs
{
	my( $self ) = @_;

	return $self->{".privs"} if( defined $self->{".privs"} ) ;

	$self->{".privs"} = {};
	foreach my $role ( $self->get_roles )
	{
		foreach my $priv ( keys %{$PRIVMAP->{$role}} ) 
		{ 
			$self->{".privs"}->{$priv} = ($self->{".privs"}->{$priv}||0) + $PRIVMAP->{$role}->{$priv}; 
		}
	}

	return $self->{".privs"};
}
	
######################################################################
#
# @roles = $user->get_roles;
#
# Return the roles the user has. Each role represents a whole bunch
# of privs.
#
######################################################################

sub get_roles
{
	my( $self ) = @_;

	my $rep = $self->{session}->get_repository;
	my $roles = $rep->get_conf( "user_roles", $self->get_value( "usertype" ) );

	return @{$roles};
}






1;

######################################################################
=pod

=back

=cut

