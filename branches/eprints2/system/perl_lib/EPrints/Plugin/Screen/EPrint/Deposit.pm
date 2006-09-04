package EPrints::Plugin::Screen::EPrint::Deposit;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 100,
		}
	];

	$self->{actions} = [qw/ deposit /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless defined $self->{processor}->{eprint};
	return 0 unless $self->{processor}->{eprint}->get_value( "eprint_status" ) eq "inbox";

	return $self->allow( "eprint/deposit" );
}

sub allow_deposit
{
	my( $self ) = @_;

	return $self->can_be_viewed;
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

	$self->{processor}->{screenid} = "EPrint::View";	

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
