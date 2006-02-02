package EPrints::Plugin::Component::FieldComponent::PlaceHolder;

use EPrints::Plugin::Component::FieldComponent;

@ISA = ( "EPrints::Plugin::Component::FieldComponent" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "PlaceHolder";
	$self->{visible} = "all";

	return $self;
}

sub render_field
{
	my( $self, $session, $metafield, $value ) = @_;
	my $out = $session->make_doc_fragment;
	$out->appendChild( $session->make_text( "This is a placeholder for the ".$self->{params}->{name}." component" ) );
}

1;





