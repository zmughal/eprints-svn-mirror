package EPrints::Plugin::Screen::EPrint::Staff::Edit;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::Edit' );

use strict;

sub priv {  "action/eprint/edit_staff"; }

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{icon} = "action_edit.png";

	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 1700,
		},
		{
			place => "eprint_review_actions",
			position => 100,
		},
	];

	$self->{staff} = 1;

	return $self;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->obtain_eprint_lock;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless $self->could_obtain_eprint_lock;

	return $self->allow( "eprint/staff/edit" );
}

sub screen_after_flow
{
	my( $self ) = @_;

	return "EPrint::View";
}

sub render
{
	my( $self ) = @_;

	$self->SUPER::render( 1 );
}

sub workflow
{
	my( $self ) = @_;

	return $self->SUPER::workflow( 1 );
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

	push @{$buttons{_order}}, "stop", "save";
	$buttons{stop} = 
		$self->{session}->phrase( "lib/submissionform:action_staff_stop" );
	$buttons{save} = 
		$self->{session}->phrase( "lib/submissionform:action_staff_save" );

	if( defined $self->workflow->get_next_stage_id )
	{
		push @{$buttons{_order}}, "next";
		$buttons{next} = 
			$self->{session}->phrase( "lib/submissionform:action_next" );
	}	
	return $self->{session}->render_action_buttons( %buttons );
}

1;