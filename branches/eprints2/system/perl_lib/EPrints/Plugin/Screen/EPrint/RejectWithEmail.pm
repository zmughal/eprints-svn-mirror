package EPrints::Plugin::Screen::EPrint::RejectWithEmail;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{priv} = "action/eprint/reject_with_email";

	return $self;
}


sub from
{
	my( $self ) = @_;

	if( $self->{processor}->{action} eq "send" )
	{
		$self->action_reject_with_email;
		return;
	}

	if( $self->{processor}->{action} eq "cancel" )
	{
		$self->{processor}->{screenid} = "EPrint::View";
		return;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub render
{
	my( $self ) = @_;

	if( !$self->{processor}->allow( "action/eprint/reject_with_email" ) )
	{
		$self->{processor}->action_not_allowed( "eprint/reject_with_email" );
		return;
	}

	my $user = $self->{processor}->{eprint}->get_user();
	# We can't bounce it if there's no user associated 

	if( !defined $user )
	{
		$self->{session}->render_error( 
			$self->{session}->html_phrase( 
				"cgi/users/edit_eprint:no_user" ),
			"buffer" );
		return;
	}

	$self->{processor}->{title} = $self->{session}->html_phrase( 
		"cgi/users/edit_eprint:title_bounce_form" );

	my $page = $self->{session}->make_doc_fragment();

	$page->appendChild( 
		$self->{session}->html_phrase( 
			"cgi/users/edit_eprint:bounce_form_intro", 
			langpref => $user->render_value( "lang" ) ) );

	my $form = $self->render_form;
	
	$page->appendChild( $form );
	
	my $div = $self->{session}->make_element( "div", class => "ep_form_field_input" );

	my $textarea = $self->{session}->make_element(
		"textarea",
		name => "reason",
		rows => 20,
		cols => 60,
		wrap => "virtual" );

	# remove any markup:
	my $title = $self->{session}->make_text( 
		EPrints::Utils::tree_to_utf8( 
			$self->{processor}->{eprint}->render_description() ) );

	$textarea->appendChild( 
		$self->{session}->html_phrase( 
			"mail_bounce_reason", 
			title => $title ) );

	$div->appendChild( $textarea );

	$form->appendChild( $div );

	$form->appendChild( $self->{session}->render_action_buttons(
		"send" => $self->{session}->phrase( "priv:action/eprint/reject_with_email" ),
		"cancel" => $self->{session}->phrase( "cgi/users/edit_eprint:action_cancel" ),
 	) );

	return( $page );
}	


sub action_reject_with_email
{
	my( $self ) = @_;

	my $user = $self->{processor}->{eprint}->get_user();
	# We can't bounce it if there's no user associated 

	$self->{processor}->{screenid} = "EPrint::View";

	if( !$self->{processor}->allow( "action/eprint/reject_with_email" ) )
	{
		$self->{processor}->action_not_allowed( "eprint/reject_with_email" );
		return;
	}

	if( !$self->{processor}->{eprint}->move_to_inbox )
	{
		$self->{processor}->add_message( 
			"error",
			$self->{session}->html_phrase( 
				"cgi/users/edit_eprint:bord_fail" ) );
	}

	$self->{processor}->add_message( "message",
		$self->{session}->html_phrase( 
			"cgi/users/edit_eprint:status_changed" ) );

	# Successfully transferred, mail the user with the reason

	my $mail = $self->{session}->make_element( "mail" );
	$mail->appendChild( 
		$self->{session}->make_text( 
			$self->{session}->param( "reason" ) ) );

	my $mail_ok = $user->mail(
		"cgi/users/edit_eprint:subject_bounce",
		$mail,
		$self->{session}->current_user );
	
	if( !$mail_ok ) 
	{
		$self->{processor}->add_message( "warning",
			$self->{session}->html_phrase( 
				"cgi/users/edit_eprint:mail_fail",
				username => $user->render_value( "username" ),
				email => $user->render_value( "email" ) ) );
		return;
	}

	$self->{processor}->add_message( "message",
		$self->{session}->html_phrase( 
			"cgi/users/edit_eprint:mail_sent" ) );
	$self->{processor}->{eprint}->log_mail_owner( $mail );
}


1;
