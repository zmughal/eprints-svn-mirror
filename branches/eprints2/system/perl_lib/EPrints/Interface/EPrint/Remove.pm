package EPrints::Interface::EPrint::Remove;

our @ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub from
{
	my( $class, $interface ) = @_;

	if( $interface->{action} eq "confirm" )
	{
		$class->action_remove( $interface );
		return;
	}

	if( $interface->{action} eq "cancel" )
	{
		$interface->{screenid} = "control";
		return;
	}

	$class->SUPER::from( $interface );
}

sub render
{
	my( $class, $interface ) = @_;


	# no title! cjg

	my $page = $interface->{session}->make_doc_fragment();

	$page->appendChild( $interface->{session}->html_phrase("lib/submissionform:sure_delete", #cjg lang
		title=>$interface->{eprint}->render_description() ) );

	my %buttons = (
		cancel => $interface->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		confirm => $interface->{session}->phrase(
				"lib/submissionform:action_confirm" ),
		_order => [ "confirm", "cancel" ]
	);

	my $form= $interface->render_form;
	$form->appendChild( 
		$interface->{session}->render_action_buttons( 
			%buttons ) );
	$page->appendChild( $form );

	return( $page );
}	


sub action_remove
{
	my( $class, $interface ) = @_;

	if( !$interface->allow_action( "remove" ) )
	{
		$interface->action_not_allowed( "remove" );
		return;
	}
		

	if( !$interface->{eprint}->remove )
	{
		my $db_error = $interface->{session}->get_database->error;
		$interface->{session}->get_repository->log( "DB error removing EPrint ".$interface->{eprint}->get_value( "eprintid" ).": $db_error" );
		$interface->add_message( "message", $interface->{session}->make_text( "Item could not be removed." ) ); #cjg lang
		$interface->{screenid} = "control";
		return;
	}

	#$interface->add_message( "message", $interface->{session}->make_text( "Item has been removed." ) ); #cjg lang
	$interface->{redirect} = $interface->{session}->get_repository->get_conf( "userhome" );
}


1;
