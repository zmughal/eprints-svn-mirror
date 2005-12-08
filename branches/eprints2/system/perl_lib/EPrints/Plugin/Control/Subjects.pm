package EPrints::Plugin::Control::Subjects;

use EPrints::Plugin::Control;

@ISA = ( "EPrints::Plugin::Control" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "control/subjects";
	$d{name} = "Subjects";
	$d{visible} = "all";

	return %d;
}

1;





