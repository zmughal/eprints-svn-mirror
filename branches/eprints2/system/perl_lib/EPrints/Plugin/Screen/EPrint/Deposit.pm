package EPrints::Plugin::Screen::EPrint::Deposit;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{priv} = "action/eprint/deposit";

	return $self;
}

sub from
{
	my( $self ) = @_;

	if( $self->{processor}->{action} eq "deposit" )
	{
		$self->action_deposit;
		$self->{processor}->{screenid} = "EPrint::View";	
		return;
	}
	
	$self->EPrints::Plugin::Screen::from;
}

sub render
{
	my( $self ) = @_;

	$self->{processor}->{title} = $self->{session}->make_text( "Deposit item" ); #cjg lang

	my $problems = $self->{processor}->{eprint}->validate_full( $self->{processor}->{for_archive} );
	if( scalar @{$problems} > 0 )
	{
		my $warnings = $self->{session}->make_element( "ul" );
		foreach my $problem_xhtml ( @{$problems} )
		{
			my $li = $self->{session}->make_element( "li" );
			$li->appendChild( $problem_xhtml );
			$warnings->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $warnings );
		$self->{processor}->add_message( "warning", $warnings );
	}

	$self->{processor}->before_messages( 
		 $self->render_blister( "deposit", 1 ) );

	my $page = $self->{session}->make_doc_fragment;
	if( scalar @{$problems} == 0 )
	{
		$page->appendChild( $self->{session}->html_phrase( "deposit_agreement_text" ) );
	
		my $form = $self->render_form;
		$form->appendChild(
		 	$self->{session}->render_action_buttons( 
				deposit=>$self->{session}->phrase( "priv:action/eprint/deposit" ) ) );
	
		$page->appendChild( $form );
	}

	return $page;
}


sub action_deposit
{
	my( $self ) = @_;

	if( !$self->{processor}->allow( "action/eprint/deposit" ) )
	{
		$self->{processor}->action_not_allowed( "deposit" );
		return;
	}

	my $problems = $self->{processor}->{eprint}->validate_full( $self->{processor}->{for_archive} );
	if( scalar @{$problems} > 0 )
	{
		$self->{processor}->add_message( "error", $self->{session}->make_text( "Could not deposit due to validation errors." ) ); #cjg lang
		my $warnings = $self->{session}->make_element( "ul" );
		foreach my $problem_xhtml ( @{$problems} )
		{
			my $li = $self->{session}->make_element( "li" );
			$li->appendChild( $problem_xhtml );
			$warnings->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $warnings );
		$self->{processor}->add_message( "warning", $warnings );
		return;
	}

	# OK, no problems, submit it to the archive

	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" ) || 0;	
	my $ok = 0;
	if( $sb )
	{
		$ok = $self->{processor}->{eprint}->move_to_archive;
	}
	else
	{
		$ok = $self->{processor}->{eprint}->move_to_buffer;
	}

	if( $ok )
	{
		$self->{processor}->add_message( "message", $self->{session}->make_text( "Item has been deposited." ) ); #cjg lang
		if( !$sb ) 
		{
			$self->{processor}->add_message( "warning", $self->{session}->make_text( "Your item will not appear on the public website until it has been checked by an editor." ) ); #cjg lang
		}
	}
	else
	{
		$self->{processor}->add_message( "error", $self->{session}->make_text( "Could not deposit for some reason." ) ); #cjg lang
	}
}


1;
