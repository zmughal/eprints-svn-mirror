package EPrints::Plugin::Component::PlaceHolder;

use EPrints::Plugin::Component;

@ISA = ( "EPrints::Plugin::Component" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "component/placeholder";
	$d{name} = "PlaceHolder";
	$d{visible} = "all";

	return %d;
}


sub render
{
	my( $self, $defobj, $params ) = @_;

	my $session = $params->{session};
	my $div = $session->make_element( "div", class => "wf_component" );
	$div->appendChild( $session->make_text( "This is a placeholder for the ".$self->{params}->{name}." component" ) );

	return $div;
}

1;





