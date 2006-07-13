package EPrints::Interface::EPrint::Reject_with_email;

our @ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub from
{
	my( $class, $interface ) = @_;

	if( $interface->{action} eq "send" )
	{
		$class->action_reject_with_email( $interface );
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

	my $user = $interface->{eprint}->get_user();
	# We can't bounce it if there's no user associated 

	if( !defined $user )
	{
		$interface->{session}->render_error( 
			$interface->{session}->html_phrase( 
				"cgi/users/edit_eprint:no_user" ),
			"buffer" );
		return;
	}

	$interface->{title} = $interface->{session}->html_phrase( 
		"cgi/users/edit_eprint:title_bounce_form" );

	my $page = $interface->{session}->make_doc_fragment();

	$page->appendChild( 
		$interface->{session}->html_phrase( 
			"cgi/users/edit_eprint:bounce_form_intro", 
			langpref => $user->render_value( "lang" ) ) );

	my $form = $interface->render_form;
	
	$page->appendChild( $form );
	
	my $div = $interface->{session}->make_element( "div", class => "formfieldinput" );

	my $textarea = $interface->{session}->make_element(
		"textarea",
		name => "reason",
		rows => 20,
		cols => 60,
		wrap => "virtual" );

	# remove any markup:
	my $title = $interface->{session}->make_text( 
		EPrints::Utils::tree_to_utf8( 
			$interface->{eprint}->render_description() ) );

	$textarea->appendChild( 
		$interface->{session}->html_phrase( 
			"mail_bounce_reason", 
			title => $title ) );

	$div->appendChild( $textarea );

	$form->appendChild( $div );

	$form->appendChild( $interface->{session}->render_action_buttons(
		"send" => $interface->{session}->phrase( "cgi/users/edit_eprint:action_send" ),
		"cancel" => $interface->{session}->phrase( "cgi/users/edit_eprint:action_cancel" ),
 	) );

	return( $page );
}	


sub action_reject_with_email
{
	my( $class, $interface ) = @_;

	my $user = $interface->{eprint}->get_user();
	# We can't bounce it if there's no user associated 

	$interface->{screenid} = "control";

	if( !$interface->allow_action( "reject_with_email" ) )
	{
		$interface->action_not_allowed( "reject_with_email" );
		return;
	}

	if( !$interface->{eprint}->move_to_inbox )
	{
		$interface->add_message( 
			"error",
			$interface->{session}->html_phrase( 
				"cgi/users/edit_eprint:bord_fail" ) );
	}

	$interface->add_message( "message",
		$interface->{session}->html_phrase( 
			"cgi/users/edit_eprint:status_changed" ) );

	# Successfully transferred, mail the user with the reason

	my $mail = $interface->{session}->make_element( "mail" );
	$mail->appendChild( 
		$interface->{session}->make_text( 
			$interface->{session}->param( "reason" ) ) );

	if( !$user->mail(
		"cgi/users/edit_eprint:subject_bounce",
		$mail,
		$interface->{session}->current_user() ) )
	{
		$interface->add_message( "warning",
			$interface->{session}->html_phrase( 
				"cgi/users/edit_eprint:mail_fail",
				username => $user->render_value( "username" ),
				email => $user->render_value( "email" ) ) );
		return;
	}

	$interface->{eprint}->log_mail_owner( $mail );
}


1;
