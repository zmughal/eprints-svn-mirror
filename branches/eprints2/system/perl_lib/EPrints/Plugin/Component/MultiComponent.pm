package EPrints::Plugin::Component::MultiComponent;

use EPrints::Plugin::Component;

@ISA = ( "EPrints::Plugin::Component" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "component/multi";
	$d{name} = "MultiComponent";
	$d{visible} = "all";

	return %d;
}

sub render_field
{
	my( $self, $session, $metafield, $value ) = @_;
	my $out = $session->make_doc_fragment;
	return $out;
}

1;





