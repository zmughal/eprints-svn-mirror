package EPrints::Plugin::Screen::EPrint::Staff::Edit;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::Edit' );

use strict;

sub priv {  "action/eprint/edit_staff"; }

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{priv} = "action/eprint/edit_staff";

	$self->{actions} = {
		"stop" => "action/eprint/edit_staff",
		"save" => "action/eprint/edit_staff",
		"next" => "action/eprint/edit_staff",
		"prev" => "action/eprint/edit_staff",
	};

	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 1700,
		}
	];

	return $self;
}

sub screen_after_flow
{
	my( $self ) = @_;

	return "EPrint::View";
}

sub render
{
	my( $self ) = @_;

	$self->{processor}->before_messages( 
		$self->render_blister( $self->workflow->get_stage_id, 0 ) );

	my $form = $self->render_form;

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
