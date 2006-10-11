######################################################################
#
# EPrints::UserForm
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

B<EPrints::UserForm> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

####################################################################
#
#  EPrints User Record Forms
#
######################################################################
#
#  __LICENSE__
#
######################################################################

package EPrints::UserForm;

use EPrints::User;
use EPrints::Session;
use EPrints::Database;

use strict;

######################################################################
#
#
#  Create a new user form session. If $user is unspecified, the current
#  user (from Apache cookies) is used.
#
######################################################################


######################################################################
=pod

=item $thing = EPrints::UserForm->new( $redirect, $staff, $user )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $redirect, $staff, $user, $dest ) = trim_params(@_);
	
	my $self = {};
	bless $self, $class;

	$self->{redirect} = $redirect;
	$self->{staff} = $staff;
	$self->{user} = $user;
	$self->{dest} = $dest;

	if( !defined $self->{user} ) 
	{
		$self->{user} = &SESSION->current_user();
	}
	
	return( $self );
}


######################################################################
#
# process()
#
#  Render and respond to the form
#
######################################################################


######################################################################
=pod

=item $foo = $thing->process

undocumented

=cut
######################################################################

sub process
{
	my( $self ) = @_;
	
	my $full_name = $self->{user}->render_description();

	if( &SESSION->seen_form() == 0 ||
	    &SESSION->internal_button_pressed() ||
	    &SESSION->get_action_button() eq "edit" )
	{
		if( &SESSION->internal_button_pressed() )
		{
			$self->_update_from_form();
		}

		my( $page, $p, $a );

		$page = &SESSION->make_doc_fragment();
		if( $self->{staff} )
		{
			$page->appendChild( &SESSION->html_phrase( 
				"lib/userform:staff_blurb" ) );
		}
		else
		{
			$page->appendChild( &SESSION->html_phrase( 
				"lib/userform:blurb" ) );
		}

		$page->appendChild( $self->_render_user_form() );
		&SESSION->build_page(
			&SESSION->html_phrase( 
				"lib/userform:record_for", 
				name => $full_name ),
			$page,
			"user_form" );
		&SESSION->send_page();

	}
	elsif( $self->_update_from_form() )
	{
		# Update the user values

		# Validate the changes
		$self->{user}->commit();
		$self->{user} = EPrints::User->new( 
			$self->{user}->get_value( "userid" ) );
		my $problems = $self->{user}->validate();

		if( scalar @{$problems} == 0 )
		{
			# User has entered everything OK
			&SESSION->redirect( $self->{redirect} );
			return;
		}

		my( $page, $p, $ul, $li );

		$page = &SESSION->make_doc_fragment();

		my $problem_box = &SESSION->make_element( 
					"div",
					class=>"problems" );
		$page->appendChild( $problem_box );
		$problem_box->appendChild( &SESSION->html_phrase( 
			"lib/userform:form_incorrect" ) );

		$ul = &SESSION->make_element( "ul" );
		my( $problem );
		foreach $problem (@$problems)
		{
			$li = &SESSION->make_element( "li" );
			$li->appendChild( $problem );
			$ul->appendChild( $li );
		}
		$problem_box->appendChild( $ul );

		$problem_box->appendChild( &SESSION->html_phrase( 
			"lib/userform:complete_form" ) );
	
		$page->appendChild( $self->_render_user_form() );

		&SESSION->build_page(
			&SESSION->html_phrase( 
				"lib/userform:record_for", 
				name => $full_name ), 
			$page,
			"user_form" );
		&SESSION->send_page();
	}
	else 
	{
		&SESSION->render_error( 
			&SESSION->html_phrase( 
				"lib/userform:problem_updating" ),
			$self->{redirect} );
	}
}


######################################################################
#
# render_form()
#
#  Render the current user as an HTML form for editing. If
# $self->{staff} is 1, the staff-only fields will be available for
#  editing, otherwise they won't.
#
######################################################################

######################################################################
# 
# $foo = $thing->_render_user_form
#
# undocumented
#
######################################################################

sub _render_user_form
{
	my( $self ) = @_;
	
	my $user_ds = &ARCHIVE->get_dataset( "user" );

	my @fields = $user_ds->get_type_fields( $self->{user}->get_value( "usertype" ), $self->{staff} );

	my %hidden = ( "userid"=>$self->{user}->get_value( "userid" ) );
	my $buttons = { update => &SESSION->phrase( "lib/userform:update_record" ) };
	my $form = &SESSION->render_input_form( 
					staff=>$self->{staff},
					dataset=>$user_ds,
					type=>$self->{user}->get_value( "usertype" ),
					fields=>\@fields,
					values=>$self->{user}->get_data(),
					show_names=>1,
					show_help=>1,
					buttons=>$buttons,
					default_action => "update",
					dest => $self->{dest}.'#t',
					hidden_fields=>\%hidden );
	return $form;
}

######################################################################
#
# $success = update_from_form()
#
#  Updates the user object from POSTed form data. Note that this
#  methods does NOT update the database - for that use commit().
#
######################################################################


######################################################################
# 
# $foo = $thing->_update_from_form
#
# undocumented
#
######################################################################

sub _update_from_form
{
	my( $self ) = @_;

	# Ensure correct user
	if( &SESSION->param( "userid" ) ne
		$self->{user}->get_value( "userid" ) )
	{
		my $form_id = &SESSION->param( "username" );
		&ARCHIVE->log( 
			"Username in $form_id doesn't match object username ".
			 $self->{username} );
	
		return( 0 );
	}
	
	my $user_ds = &ARCHIVE->get_dataset( "user" );

	my $usertype;
	if( $self->{staff} )
	{
		# In a search type the usertype can change!
 		$usertype = &SESSION->param( "usertype" );   
	}
	if( !defined $usertype )
	{
		$usertype = $self->{user}->get_value( "usertype" )       
	}   
	my @fields = $user_ds->get_type_fields( $usertype, $self->{staff} );

	my $field;
	foreach $field ( @fields )
	{
		my $param = $field->form_value;

		$self->{user}->set_value( $field->{name} , $param );
	}
	return( 1 );
}


######################################################################
=pod

=item $foo = $thing->DESTROY

undocumented

=cut
######################################################################

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}

1;

######################################################################
=pod

=back

=cut

