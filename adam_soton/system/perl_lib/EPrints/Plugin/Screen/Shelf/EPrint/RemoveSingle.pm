package EPrints::Plugin::Screen::Shelf::EPrint::RemoveSingle;

our @ISA = ( 'EPrints::Plugin::Screen::Shelf::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "delete.png";

	$self->{appears} = [
		{
			place => "shelf_items_eprint_actions",
			position => 300,
		},
	];
	
	$self->{actions} = [qw/ remove cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->{processor}->{shelf}->has_editor($self->{processor}->{user});
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );

	$div->appendChild( $self->html_phrase("sure_delete",
		title=>$self->{processor}->{eprint}->render_description() ) );

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
	$form->appendChild($self->render_hidden_bits);
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

	$self->{processor}->{screenid} = "Shelf::EditItems";
}

sub action_remove
{
	my( $self ) = @_;

        my $eprintid = $self->{session}->param('eprintid');

        $self->{processor}->{shelf}->remove_items($eprintid);

	$self->{processor}->{screenid} = "Shelf::EditItems";
	$self->{processor}->add_message( "message", $self->html_phrase( "item_removed" ) );
}


1;
