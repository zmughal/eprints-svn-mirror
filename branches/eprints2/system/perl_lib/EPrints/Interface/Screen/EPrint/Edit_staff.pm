package EPrints::Interface::Screen::EPrint::Edit_staff;

@ISA = ( 'EPrints::Interface::Screen::EPrint' );

use strict;

sub from
{
	my( $self ) = @_;

	if( !$self->{processor}->allow( "action/eprint/edit_staff" ) )
	{
		$self->{processor}->action_not_allowed( "edit" );
		$self->{processor}->{screenid} = "EPrint::View";
		return;
	}

	my $workflow = $self->workflow;

	if( $self->{processor}->{action} eq "stop" )
	{
		$self->{processor}->{screenid} = "EPrint::View";
		return;
	}
	
	if( $self->{processor}->{action} eq "staff_save" )
	{
		my $ok = $workflow->from;
	
		$self->{processor}->{screenid} = "EPrint::View";
		return;
	}
	
	if( $self->{processor}->{action} eq "save" )
	{
		my $ok = $workflow->from;
	
		$self->{processor}->{screenid} = "EPrint::View";
		return;
	}
	
	if( $self->{processor}->{action} eq "prev" )
	{
		my $ok = $workflow->from;
	
		$workflow->prev;

		return;
	}

	if( $self->{processor}->{action} eq "next" )
	{
		my @problems = $workflow->from;
		if( !scalar @problems )
		{
			if( !defined $workflow->get_next_stage_id )
			{
				$self->{processor}->{screenid} = "EPrint::View";
				return;
			}

			$workflow->next;
		}
		else
		{
			my $warnings = $self->{session}->make_element( "ul" );
			foreach my $problem_xhtml ( @problems )
			{
				my $li = $self->{session}->make_element( "li" );
				$li->appendChild( $problem_xhtml );
				$warnings->appendChild( $li );
			}
			$workflow->link_problem_xhtml( $warnings );
			$self->{processor}->add_message( "warning", $warnings );
		}

		return;
	}

	$self->EPrints::Interface::Screen::from;
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
