package EPrints::Plugin::Screen::EPrint::Edit;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 1500,
		}
	];

	$self->{staff} = 0;

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/edit" );
}

sub from
{
	my( $self ) = @_;

	if( defined $self->{processor}->{internal} )
	{
		$self->workflow->update_from_form( $self->{processor} );
		return;
	}

	my $action_id = $self->{processor}->{action};
	if( $action_id =~ m/^jump_(.*)$/ )
	{
		my $jump_to = $1;

		my $from_ok = $self->workflow->update_from_form( $self->{processor} );
		return if( !$from_ok );

		if( $jump_to eq "deposit" )
		{
			$self->{processor}->{screenid} = $self->screen_after_flow;
			return;
		}

		# not checking that this succeded. Maybe we should.
		$self->workflow->set_stage( $jump_to );
		return;
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

	$self->{processor}->{screenid} = "EPrint::View";
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
	
	$self->{processor}->{screenid} = "EPrint::View";
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

	return "EPrint::Deposit";
}


sub render
{
	my( $self ) = @_;

	my $form = $self->render_form;
	$form->appendChild( 
		$self->render_blister( $self->workflow->get_stage_id, 0 ) );

	$form->appendChild( $self->render_buttons );
	$form->appendChild( $self->workflow->render );
	$form->appendChild( $self->render_buttons );
	
	return $form;
}


sub render_buttons
{
	my( $self ) = @_;

	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	if( defined $self->workflow->get_prev_stage_id )
	{
		push @{$buttons{_order}}, "prev";
		$buttons{prev} = 
			$self->{session}->phrase( "lib/submissionform:action_prev" );
	}

	push @{$buttons{_order}}, "save";
	$buttons{save} = 
		$self->{session}->phrase( "lib/submissionform:action_save" );

	push @{$buttons{_order}}, "next";
	$buttons{next} = 
		$self->{session}->phrase( "lib/submissionform:action_next" );

	return $self->{session}->render_action_buttons( %buttons );
}

1;
