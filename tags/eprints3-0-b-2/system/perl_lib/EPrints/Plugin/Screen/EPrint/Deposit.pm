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
		},
		{ 
			place => "eprint_actions_owner_inbox", 
			position => 100, 
		},
	];

	$self->{actions} = [qw/ deposit /];

	return $self;
}

sub from
{
	my( $self ) = @_;

	my $action_id = $self->{processor}->{action};
	if( $action_id =~ m/^jump_(.*)$/ )
	{
		my $jump_to = $1;

		if( $jump_to eq "deposit" )
		{
			return;
		}

		# not checking that this succeded. Maybe we should.
		$self->{processor}->{screenid} = "EPrint::Edit";
		$self->workflow->set_stage( $jump_to );
		return;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless defined $self->{processor}->{eprint};
	return 0 unless $self->{processor}->{eprint}->get_value( "eprint_status" ) eq "inbox";

	return $self->allow( "eprint/deposit" );
}

sub render
{
	my( $self ) = @_;

	my $problems = $self->{processor}->{eprint}->validate( $self->{processor}->{for_archive} );
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

	my $page = $self->{session}->make_doc_fragment;
	my $form = $self->render_form;
	$page->appendChild( $form );
	$form->appendChild( 
		 $self->render_blister( "deposit", 0 ) );

	if( scalar @{$problems} == 0 )
	{
		$form->appendChild( $self->{session}->html_phrase( "deposit_agreement_text" ) );
	
		$form->appendChild(
		 	$self->{session}->render_action_buttons( 
				deposit=>$self->{session}->phrase( "priv:action/eprint/deposit" ) ) );
	}

	return $page;
}

sub allow_deposit
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_deposit
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";	

	my $problems = $self->{processor}->{eprint}->validate( $self->{processor}->{for_archive} );
	if( scalar @{$problems} > 0 )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "validation_errors" ) ); 
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
		$self->{processor}->add_message( "message", $self->html_phrase( "item_deposited" ) );
		if( !$sb ) 
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( "in_buffer" ) );
		}
	}
	else
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "item_not_deposited" ) );
	}
}


1;
