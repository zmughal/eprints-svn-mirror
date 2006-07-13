package EPrints::Interface::EPrint::Deposit;

our @ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub from
{
	my( $class, $interface ) = @_;

	if( $interface->{action} eq "deposit" )
	{
		$class->action_deposit( $interface );
		$interface->{screenid} = "control";	
		return;
	}
	
	$class->SUPER::from( $interface );
}

sub render
{
	my( $class, $interface ) = @_;

	$interface->{title} = $interface->{session}->make_text( "Deposit item" ); #cjg lang
	my $problems = $interface->{eprint}->validate_full( $interface->{for_archive} );
	if( scalar @{$problems} > 0 )
	{
		my $warnings = $interface->{session}->make_element( "ul" );
		foreach my $problem_xhtml ( @{$problems} )
		{
			my $li = $interface->{session}->make_element( "li" );
			$li->appendChild( $problem_xhtml );
			$warnings->appendChild( $li );
		}
		$interface->workflow->link_problem_xhtml( $warnings );
		$interface->add_message( "warning", $warnings );
	}

	$interface->before_messages( 
		 $interface->render_blister( "deposit", 1 ) );

	my $page = $interface->{session}->make_doc_fragment;
	if( scalar @{$problems} == 0 )
	{
		$page->appendChild(
		 	$class->render_deposit_form( $interface ) );
	}

	return $page;
}

sub render_deposit_form
{
	my( $class, $interface ) = @_;
	
	my $chunk = $interface->{session}->make_doc_fragment;

	$chunk->appendChild( $interface->{session}->html_phrase( "deposit_agreement_text" ) );

	my $form = $interface->render_form;
	$form->appendChild(
		 $interface->{session}->render_action_buttons( 
			deposit=>$interface->{session}->phrase( "cgi/users/edit_eprint:action_deposit" ) ) );

	$chunk->appendChild( $form );

	return $chunk;
}

sub action_deposit
{
	my( $class, $interface ) = @_;

	if( !$interface->allow_action( "deposit" ) )
	{
		$interface->action_not_allowed;
		return;
	}

		
	$interface->{screenid} = "control";

	my $problems = $interface->{eprint}->validate_full( $interface->{for_archive} );
	if( scalar @{$problems} > 0 )
	{
		$interface->add_message( "error", $interface->{session}->make_text( "Could not deposit due to validation errors." ) ); #cjg lang
		my $warnings = $interface->{session}->make_element( "ul" );
		foreach my $problem_xhtml ( @{$problems} )
		{
			my $li = $interface->{session}->make_element( "li" );
			$li->appendChild( $problem_xhtml );
			$warnings->appendChild( $li );
		}
		$interface->add_message( "warning", $warnings );
		return;
	}

	# OK, no problems, submit it to the archive

	my $sb = $interface->{session}->get_repository->get_conf( "skip_buffer" ) || 0;	
	my $ok = 0;
	if( $sb )
	{
		$ok = $interface->{eprint}->move_to_archive;
	}
	else
	{
		$ok = $interface->{eprint}->move_to_buffer;
	}

	if( $ok )
	{
		$interface->add_message( "message", $interface->{session}->make_text( "Item has been deposited." ) ); #cjg lang
		if( !$sb ) 
		{
			$interface->add_message( "warning", $interface->{session}->make_text( "Your item will not appear on the public website until it has been checked by an editor." ) ); #cjg lang
		}
	}
	else
	{
		$interface->add_message( "error", $interface->{session}->make_text( "Could not deposit for some reason." ) ); #cjg lang
	}
}


1;
