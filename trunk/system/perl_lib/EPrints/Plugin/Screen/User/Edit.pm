=head1 NAME

EPrints::Plugin::Screen::User::Edit

=cut


package EPrints::Plugin::Screen::User::Edit;

use EPrints::Plugin::Screen::User;

@ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{appears} = [
		{
			place => "user_actions",
			position => 100,
		}
	];

	$self->{staff} = 0;

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/edit" );
}

sub from
{
	my( $self ) = @_;

	if( defined $self->{processor}->{internal} )
	{
		my $from_ok = $self->workflow->update_from_form( $self->{processor},undef,1 );
		$self->uncache_workflow;
		return unless $from_ok;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub allow_stop
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_stop
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "User::View";
}	


sub allow_save
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_save
{
	my( $self ) = @_;

	$self->workflow->update_from_form( $self->{processor} );
	$self->uncache_workflow;
	$self->{session}->reload_current_user;
	
	$self->{processor}->{screenid} = "User::View";
}


sub allow_prev
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}
	
sub action_prev
{
	my( $self ) = @_;

	$self->workflow->update_from_form( $self->{processor} );
	$self->{session}->reload_current_user;
	$self->uncache_workflow;
	$self->workflow->prev;
}


sub allow_next
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_next
{
	my( $self ) = @_;

	my $from_ok = $self->workflow->update_from_form( $self->{processor} );
	$self->uncache_workflow;
	$self->{session}->reload_current_user;
	return unless $from_ok;

	if( !defined $self->workflow->get_next_stage_id )
	{
		$self->{processor}->{screenid} = $self->screen_after_flow;
		return;
	}

	$self->workflow->next;
}



sub screen_after_flow
{
	my( $self ) = @_;

	return "User::View";
}


sub render
{
	my( $self ) = @_;

#	$self->{processor}->before_messages( 
#		$self->render_blister( $self->workflow->get_stage_id, 1 ) );

	my $form = $self->render_form;

	$form->appendChild( $self->render_buttons );
	$form->appendChild( $self->workflow->render );
	$form->appendChild( $self->render_buttons );
	
	return $form;
}


sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url.$self->workflow->get_state_params( $self->{processor} );
}

sub render_buttons
{
	my( $self ) = @_;

	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	if( defined $self->workflow->get_prev_stage_id )
	{
		push @{$buttons{_order}}, "prev";
		$buttons{prev} = $self->phrase( "prev" );
	}

	push @{$buttons{_order}}, "stop", "save";
	$buttons{stop} = $self->phrase( "stop" );
	$buttons{save} = $self->phrase( "save" );

	if( defined $self->workflow->get_next_stage_id )
	{
		push @{$buttons{_order}}, "next";
		$buttons{next} = $self->phrase( "next" );
	}	
	return $self->{session}->render_action_buttons( %buttons );
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		stage => $self->workflow->get_stage_id
	);
}

1;



=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

