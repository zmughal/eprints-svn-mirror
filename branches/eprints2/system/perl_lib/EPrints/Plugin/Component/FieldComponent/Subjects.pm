package EPrints::Plugin::Component::FieldComponent::Subjects;

use EPrints::Plugin::Component::FieldComponent;

@ISA = ( "EPrints::Plugin::Component::FieldComponent" );

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





