
package EPrints::Apache::Login;

use strict;

use EPrints;
use EPrints::Apache::AnApache;

sub handler
{
	my( $r ) = @_;

	my $session = new EPrints::Session;
	my $problems;
	# ok then we need to get the cgi
	my $username = $session->param( "login_username" );
	my $password = $session->param( "login_password" );

	if( defined $username )
	{
		my $valid_login_handler = \&valid_login;
		if( $session->get_repository->can_call( "check_user_password" ) )
		{
			$valid_login_handler = $session->get_repository->get_conf( "check_user_password" );
		}
		if( &{$valid_login_handler}( $session, $username, $password ) )
		{
			my $user = EPrints::DataObj::User::user_with_username( $session, $username );
			$session->login( $user );

			my $params = $session->param("params");

			my $c = $r->connection;

			$c->notes->set( params=>$params );

			return DECLINED;
		}

		$problems = $session->html_phrase("cgi/login:failed" );
	}

	my $page=$session->make_doc_fragment();
	$page->appendChild( input_form( $session, $problems ) );

	my $title = $session->make_text( "Login" );
	$session->build_page( $title, $page, "login" );
	$session->send_page;
	$session->terminate;

	return DONE;

}


sub valid_login
{
	my( $session, $username, $password ) = @_;

	my $sql = "SELECT password FROM user WHERE username='".EPrints::Database::prep_value($username)."'";

	my $sth = $session->get_database->prepare( $sql );
	$session->get_database->execute( $sth , $sql );
	my( $real_password ) = $sth->fetchrow_array;
	$sth->finish;

	return 0 if( !defined $real_password );

	my $salt = substr( $real_password, 0, 2 );

	return $real_password eq crypt( $password , $salt );
}


sub input_form
{
	my( $session, $problems ) = @_;

	my %bits;
	if( defined $problems )
	{
		$bits{problems} = $session->render_message( "error", $problems );
	}
	else
	{
		$bits{problems} = $session->make_doc_fragment;
	}

	$bits{input_username} = $session->render_input_field(
			class => "ep_form_text",
			id => "login_username",
			name => 'login_username' );

	$bits{input_password} = $session->render_input_field(
			class => "ep_form_text",
			name => 'login_password',
			type => "password" );

	$bits{login_button} = $session->render_button(
			name => '_action_login',
			value => "Login",
			class => 'ep_form_action_button', );

	my $op1;
	my $op2;

	$bits{log_in_until} = $session->make_element( "select", name=>"login_log_in_until" );
	$op1 = $session->make_element( "option", value=>"until_close", selected=>"selected" );
	$op1->appendChild( $session->html_phrase( "cgi/login:until_close" ) );
	$op2 = $session->make_element( "option", value=>"forever" );
	$op2->appendChild( $session->html_phrase( "cgi/login:forever" ) );
	$bits{log_in_until}->appendChild( $op1 );
	$bits{log_in_until}->appendChild( $op2 );
	
	$bits{bind_to_ip} = $session->make_element( "select", name=>"login_log_in_until" );
	$op1 = $session->make_element( "option", value=>"bind", selected=>"selected" );
	$op1->appendChild( $session->html_phrase( "cgi/login:bind" ) );
	$op2 = $session->make_element( "option", value=>"dont_bind" );
	$op2->appendChild( $session->html_phrase( "cgi/login:dont_bind" ) );
	$bits{bind_to_ip}->appendChild( $op1 );
	$bits{bind_to_ip}->appendChild( $op2 );
	
	my $form = $session->render_form( "POST" );
	$form->appendChild( $session->html_phrase( "cgi/login:page_layout", %bits ) );
	my @p = $session->param;
	my @k = ();
	foreach my $p ( @p )
	{
		my $v = $session->param( $p );
		$v =~ s/([^A-Z0-9])/sprintf( "%%%02X", ord($1) )/ieg;
		push @k, $p."=".$v;
	}
	$form->appendChild( $session->render_hidden_field( "params", join( "&",@k ) ) );
	my $script = $session->make_element( "script", type=>"text/javascript" );
	$script->appendChild( $session->make_text( '$("login_username").focus()' ) ); 
	$form->appendChild( $script);

	return $form;
}

1;