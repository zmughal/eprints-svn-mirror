
package EPrints::Plugin::Screen::User::SavedSearch::Edit;

use EPrints::Plugin::Screen::User::SavedSearch;

@ISA = ( 'EPrints::Plugin::Screen::User::SavedSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{appears} = [
		{
			place => "saved_search_actions",
			position => 300,
		}
	];

	$self->{staff} = 0;

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "saved_search/edit" );
}

sub from
{
	my( $self ) = @_;

	if( defined $self->{processor}->{internal} )
	{
		my @problems = $self->workflow->from;
		if( scalar @problems )
		{
			$self->add_problems( @problems );
		}
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

	$self->{processor}->{screenid} = "User::SavedSearches";
}	


sub allow_save
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_save
{
	my( $self ) = @_;

	$self->workflow->from;
	$self->{session}->reload_current_user;
	
	$self->{processor}->{screenid} = "User::SavedSearches";
}


sub allow_prev
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}
	
sub action_prev
{
	my( $self ) = @_;

	$self->workflow->from;
	$self->{session}->reload_current_user;
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

	my @problems = $self->workflow->from;
	$self->{session}->reload_current_user;
	if( scalar @problems )
	{
		$self->add_problems( @problems );
		return;
	}

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

	return "User::SavedSearches";
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
	$self->workflow->link_problem_xhtml( $warnings, $self->{staff} );
	$self->{processor}->add_message( "warning", $warnings );
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


