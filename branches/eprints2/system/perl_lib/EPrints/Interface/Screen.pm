package EPrints::Interface::Screen;

# placeholder.

sub new
{
	my( $class, $session ) = @_;

	return bless { session=>$session }, $class;
}


1;
