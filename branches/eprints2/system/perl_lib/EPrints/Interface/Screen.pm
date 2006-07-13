package EPrints::Interface::Screen;

# placeholder.

sub new
{
	my( $class, $session ) = @_;

	return bless { session=>$session }, $class;
}

sub from
{
	my( $class , $interface ) = @_;

	if( $interface->{action} eq "" )
	{
		return;
	}

	$interface->add_message( "error",
		$interface->{session}->html_phrase(
	      		"cgi/users/edit_eprint:unknown_action",
			action=>$interface->{session}->make_text( $interface->{action} ) ) );
}

1;
