package EPrints::Plugin::Screen::Coversheet::Remove;

our @ISA = ( 'EPrints::Plugin::Screen::Coversheet' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_remove.png";

	$self->{appears} = [
		{
			place => "coversheet_manager_actions",
			position => 100,
		},
	];
	
	$self->{actions} = [qw/ remove cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return 0 if $self->{processor}->{coversheet}->is_in_use();

	return $self->allow( "coversheet/write" );
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );
	my %buttons;

	if ($self->{processor}->{coversheet}->is_in_use())
	{
		$div->appendChild( $self->html_phrase("coversheet_in_use",
			title=>$self->{processor}->{coversheet}->get_value('name') ) );

		%buttons = (
			cancel => $self->{session}->phrase(
					"lib/submissionform:action_cancel" ),
			_order => [ "cancel" ]
		);

	}
	else
	{
		$div->appendChild( $self->html_phrase("sure_delete",
			title=>$self->{processor}->{coversheet}->get_value('name') ) );

		%buttons = (
			cancel => $self->{session}->phrase(
					"lib/submissionform:action_cancel" ),
			remove => $self->{session}->phrase(
					"lib/submissionform:action_remove" ),
			_order => [ "remove", "cancel" ]
		);

	}
	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $div );

}	

sub allow_cancel
{
	my( $self ) = @_;

	return 1;
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::CoversheetManager";
}

sub allow_remove
{
	my( $self ) = @_;

	return 0 if $self->{processor}->{coversheet}->is_in_use();

	return $self->can_be_viewed;
}

sub action_remove
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::CoversheetManager";

	if( !$self->{processor}->{coversheet}->remove )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( "DB error removing coversheet ".$self->{processor}->{coversheet}->get_value( "coversheetid" ).": $db_error" );
		$self->{processor}->add_message( "message", $self->html_phrase( "item_not_removed" ) );
		$self->{processor}->{screenid} = "FirstTool";
		return;
	}

	$self->{processor}->add_message( "message", $self->html_phrase( "item_removed" ) );
}


1;
