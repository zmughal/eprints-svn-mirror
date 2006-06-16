package EPrints::Interface::EPrint::Deposit;

our @ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub from
{
	my( $class, $interface ) = @_;

	if( $interface->{action} eq "deposit" )
	{
		$class->action_deposit( $interface );
	}
}

sub render
{
	my( $class, $interface ) = @_;

	$interface->{title} = $interface->{session}->make_text( "Deposit item" ); #cjg lang

	return $class->render_deposit_form( $interface );
}

sub render_deposit_form
{
	my( $class, $interface ) = @_;
	
	my $chunk = $interface->{session}->make_doc_fragment;

	$chunk->appendChild( $interface->{session}->html_phrase( "deposit_agreement_text" ) );

	my $dep_a = $interface->{session}->make_element( "a", href=>"?screen=deposit&eprintid=".$interface->{eprintid}."&action=deposit" );
	$dep_a->appendChild( $interface->{session}->make_text( "Deposit this Item now" ) ); #cjg lang

	$chunk->appendChild( $dep_a );

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

	my $problems = $interface->{eprint}->validate_full( $interface->{for_archive} );
		
	$interface->{screenid} = "control";

	if( scalar @{$problems} > 0 )
	{
		$interface->add_message( "error", $interface->{session}->make_text( "Could not deposit due to validation errors." ) ); #cjg lang
		foreach( @{$problems} )
		{
			$interface->add_message( "warning", $_ );
		}
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
