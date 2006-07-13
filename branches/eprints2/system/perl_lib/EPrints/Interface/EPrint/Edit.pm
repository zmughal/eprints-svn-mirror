package EPrints::Interface::EPrint::Edit;

our @ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub from
{
	my( $class, $interface ) = @_;

	if( !$interface->allow_action( "edit_eprint" ) )
	{
		$interface->action_not_allowed( "edit_eprint" );
		$interface->{screenid} = "control";
		return;
	}

	my $workflow = $interface->workflow;

	if( $interface->{action} eq "stop" )
	{
		$interface->{screenid} = "control";
		return;
	}
	
	if( $interface->{action} eq "staff_save" )
	{
		my $ok = $workflow->from;
	
		$interface->{screenid} = "control";
		return;
	}
	
	if( $interface->{action} eq "save" )
	{
		my $ok = $workflow->from;
	
		$interface->{screenid} = "control";
		return;
	}
	
	if( $interface->{action} eq "prev" )
	{
		my $ok = $workflow->from;
	
		$workflow->prev;

		return;
	}

	if( $interface->{action} eq "next" )
	{
		my @problems = $workflow->from;
		if( !scalar @problems )
		{
			if( !defined $workflow->get_next_stage_id )
			{
				$interface->{screenid} = "deposit";
				return;
			}

			$workflow->next;
		}
		else
		{
			my $warnings = $interface->{session}->make_element( "ul" );
			foreach my $problem_xhtml ( @problems )
			{
				my $li = $interface->{session}->make_element( "li" );
				$li->appendChild( $problem_xhtml );
				$warnings->appendChild( $li );
			}
			$workflow->link_problem_xhtml( $warnings );
			$interface->add_message( "warning", $warnings );
		}

		return;
	}

	$class->SUPER::from( $interface );
}

sub render
{
	my( $class, $interface ) = @_;

	my $form = $interface->render_form;
	$interface->before_messages( $interface->render_blister( $interface->workflow->get_stage_id, !$interface->{staff} ) );
	$form->appendChild( $class->render_buttons( $interface ) );
	$form->appendChild( $interface->workflow->render );
	$form->appendChild( $class->render_buttons( $interface ) );
	
	return $form;
}


sub render_buttons
{
	my( $class, $interface ) = @_;

	my %buttons = ( _order=>[], _class=>"ep_button_bar" );

	if( defined $interface->workflow->get_prev_stage_id )
	{
		push @{$buttons{_order}}, "prev";
		$buttons{prev} = 
			$interface->{session}->phrase( "lib/submissionform:action_prev" );
	}

	if( $interface->{staff} ) 
	{
		push @{$buttons{_order}}, "stop", "save";
		$buttons{stop} = 
			$interface->{session}->phrase( "lib/submissionform:action_staff_stop" );
		$buttons{save} = 
			$interface->{session}->phrase( "lib/submissionform:action_staff_save" );
	}
	else
	{
		push @{$buttons{_order}}, "save";
		$buttons{save} = 
			$interface->{session}->phrase( "lib/submissionform:action_save" );
	}

	push @{$buttons{_order}}, "next";
	$buttons{next} = 
		$interface->{session}->phrase( "lib/submissionform:action_next" );

	return $interface->{session}->render_action_buttons( %buttons );
}

1;
