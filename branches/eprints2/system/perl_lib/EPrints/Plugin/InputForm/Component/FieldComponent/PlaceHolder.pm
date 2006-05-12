package EPrints::Plugin::InputForm::Component::FieldComponent::PlaceHolder;

use EPrints::Plugin::InputForm::Component::FieldComponent;

@ISA = ( "EPrints::Plugin::InputForm::Component::FieldComponent" );

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

sub render_content
{
	my( $self, $session ) = @_;
	my $out = $session->make_doc_fragment;
	$out->appendChild( $session->make_text( "This is a placeholder for the ".$self->{name}." component" ) );
	return $out;
}

1;





