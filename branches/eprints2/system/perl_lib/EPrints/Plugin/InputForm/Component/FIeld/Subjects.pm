package EPrints::Plugin::InputForm::Component::FieldComponent::Subjects;

use EPrints::Plugin::InputForm::Component::FieldComponent;

@ISA = ( "EPrints::Plugin::InputForm::Component::FieldComponent" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Subjects";
	$self->{visible} = "all";

	return $self;
}

1;





