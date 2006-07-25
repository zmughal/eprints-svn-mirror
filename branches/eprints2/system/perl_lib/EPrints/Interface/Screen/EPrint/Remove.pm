package EPrints::Interface::Screen::EPrint::Remove;

our @ISA = ( 'EPrints::Interface::Screen::EPrint' );

use strict;

sub from
{
	my( $self ) = @_;

	if( $self->{processor}->{action} eq "confirm" )
	{
		$self->action_remove;
		$self->{processor}->{screenid} = "Items";
		return;
	}

	if( $self->{processor}->{action} eq "cancel" )
	{
		$self->{processor}->{screenid} = "EPrint::View";
		return;
	}

	$self->EPrints::Interface::Screen::from;
}

sub render
{
	my( $self ) = @_;


	# no title! cjg

	my $page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->{session}->html_phrase("lib/submissionform:sure_delete", #cjg lang
		title=>$self->{processor}->{eprint}->render_description() ) );

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		confirm => $self->{session}->phrase(
				"lib/submissionform:action_confirm" ),
		_order => [ "confirm", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$page->appendChild( $form );

	return( $page );
}	


sub action_remove
{
	my( $self ) = @_;

	if( !$self->{processor}->allow( "action/eprint/remove" ) )
	{
		$self->{processor}->action_not_allowed( "eprint/remove" );
		return;
	}
		

	if( !$self->{processor}->{eprint}->remove )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( "DB error removing EPrint ".$self->{processor}->{eprint}->get_value( "eprintid" ).": $db_error" );
		$self->{processor}->add_message( "message", $self->{session}->make_text( "Item could not be removed." ) ); #cjg lang
		$self->{processor}->{screenid} = "control";
		return;
	}

	$self->{processor}->add_message( "message", $self->{session}->make_text( "Item has been removed." ) ); #cjg lang
}


1;
