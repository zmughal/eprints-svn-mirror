package EPrints::Plugin::Screen::EPrint::Edit;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;


sub priv {  "action/eprint/edit"; }

sub from
{
	my( $self ) = @_;

	if( !$self->{processor}->allow($self->priv) )
	{
		$self->{processor}->action_not_allowed( "edit" );
		$self->{processor}->{screenid} = "EPrint::View";
		return;
	}

	my $workflow = $self->workflow;

	if( defined $self->{processor}->{internal} )
	{
		my @problems = $workflow->from;
		if( scalar @problems )
		{
			$self->add_problems( @problems );
		}
		return;
	}
	
	if( $self->{processor}->{action} eq "stop" )
	{
		$self->{processor}->{screenid} = "EPrint::View";
		return;
	}
	
	if( $self->{processor}->{action} eq "save" )
	{
		$workflow->from;
	
		$self->{processor}->{screenid} = "EPrint::View";
		return;
	}
	
	if( $self->{processor}->{action} eq "prev" )
	{
		$workflow->from;
	
		$workflow->prev;

		return;
	}

	if( $self->{processor}->{action} eq "next" )
	{
		my @problems = $workflow->from;
		if( scalar @problems )
		{
			$self->add_problems( @problems );
		}
		else
		{
			if( !defined $workflow->get_next_stage_id )
			{
				$self->{processor}->{screenid} = $self->screen_after_flow;
				return;
			}

			$workflow->next;
		}

		return;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub screen_after_flow
{
	my( $self ) = @_;

	return "EPrint::Deposit";
}

sub add_problems
{
	my( $self, @problems ) = @_;
 
	my $warnings = $self->{session}->make_element( "ul" );
	foreach my $problem_xhtml ( @problems )
	{
		my $li = $self->{session}->make_element( "li" );
		$li->appendChild( $problem_xhtml );
				$warnings->appendChild( $li );
	}
	$self->workflow->link_problem_xhtml( $warnings );
	$self->{processor}->add_message( "warning", $warnings );
}

sub render
{
	my( $self ) = @_;

	$self->{processor}->before_messages( 
		$self->render_blister( $self->workflow->get_stage_id, 1 ) );

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

	push @{$buttons{_order}}, "save";
	$buttons{save} = 
		$self->{session}->phrase( "lib/submissionform:action_save" );

	push @{$buttons{_order}}, "next";
	$buttons{next} = 
		$self->{session}->phrase( "lib/submissionform:action_next" );

	return $self->{session}->render_action_buttons( %buttons );
}

1;
