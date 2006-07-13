package EPrints::Interface::Screen::EPrint::Edit;

@ISA = ( 'EPrints::Interface::Screen::EPrint' );

use strict;

sub from
{
	my( $self ) = @_;

	if( !$self->{processor}->allow_action( "edit_eprint" ) )
	{
		$self->{processor}->action_not_allowed( "edit_eprint" );
		$self->{processor}->{screenid} = "EPrint";
		return;
	}

	my $workflow = $self->workflow;

	if( $self->{processor}->{action} eq "stop" )
	{
		$self->{processor}->{screenid} = "EPrint";
		return;
	}
	
	if( $self->{processor}->{action} eq "staff_save" )
	{
		my $ok = $workflow->from;
	
		$self->{processor}->{screenid} = "EPrint";
		return;
	}
	
	if( $self->{processor}->{action} eq "save" )
	{
		my $ok = $workflow->from;
	
		$self->{processor}->{screenid} = "EPrint";
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
				$self->{processor}->{screenid} = "EPrint::Deposit";
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
		$self->render_blister( $self->workflow->get_stage_id, !$self->{processor}->{staff} ) );

	my $form = $self->render_form;

	$form->appendChild( $self->render_buttons );
	$form->appendChild( $self->workflow->render );
	$form->appendChild( $self->render_buttons );
	
	return $form;
}


sub render_buttons
{
	my( $self ) = @_;

	my %buttons = ( _order=>[], _class=>"ep_button_bar" );

	if( defined $self->workflow->get_prev_stage_id )
	{
		push @{$buttons{_order}}, "prev";
		$buttons{prev} = 
			$self->{session}->phrase( "lib/submissionform:action_prev" );
	}

	if( $self->{processor}->{staff} ) 
	{
		push @{$buttons{_order}}, "stop", "save";
		$buttons{stop} = 
			$self->{session}->phrase( "lib/submissionform:action_staff_stop" );
		$buttons{save} = 
			$self->{session}->phrase( "lib/submissionform:action_staff_save" );
	}
	else
	{
		push @{$buttons{_order}}, "save";
		$buttons{save} = 
			$self->{session}->phrase( "lib/submissionform:action_save" );
	}

	push @{$buttons{_order}}, "next";
	$buttons{next} = 
		$self->{session}->phrase( "lib/submissionform:action_next" );

	return $self->{session}->render_action_buttons( %buttons );
}

1;
