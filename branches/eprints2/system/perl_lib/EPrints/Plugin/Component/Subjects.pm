package EPrints::Plugin::Component::Subjects;

use EPrints::Plugin::Component;

@ISA = ( "EPrints::Plugin::Component" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "component/subjects";
	$d{name} = "Subjects";
	$d{visible} = "all";

	return %d;
}

1;





