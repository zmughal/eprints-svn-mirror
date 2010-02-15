package EPrints::Plugin::Screen::Shelf::Remove;

our @ISA = ( 'EPrints::Plugin::Screen::Shelf' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_remove.png";

	$self->{appears} = [
		{
			place => "shelf_item_actions",
			position => 100,
		},
	];
	
	$self->{actions} = [qw/ remove cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return 1;
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );

	$div->appendChild( $self->html_phrase("sure_delete",
		title=>$self->{processor}->{shelf}->render_description() ) );

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		remove => $self->{session}->phrase(
				"lib/submissionform:action_remove" ),
		_order => [ "remove", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $div );
}	

sub allow_remove
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_cancel
{
	my( $self ) = @_;

	return 1;
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Shelves";
}

sub action_remove
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Shelves";

	if( !$self->{processor}->{shelf}->remove )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( "DB error removing Shelf ".$self->{processor}->{shelf}->get_value( "shelfid" ).": $db_error" );
		$self->{processor}->add_message( "message", $self->html_phrase( "item_not_removed" ) );
		return;
	}

	$self->{processor}->add_message( "message", $self->html_phrase( "item_removed" ) );
}


1;
