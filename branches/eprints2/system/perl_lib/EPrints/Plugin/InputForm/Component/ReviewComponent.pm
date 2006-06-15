package EPrints::Plugin::InputForm::Component::ReviewComponent;

use EPrints::Plugin::InputForm::Component;

@ISA = ( "EPrints::Plugin::InputForm::Component" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "ReviewComponent";
	$self->{visible} = "all";

	return $self;
}

sub render_content
{
	my( $self, $surround ) = @_;
	my $out = $self->{session}->make_element( "b" );
	$out->appendChild( $self->{session}->make_text( "Foo" ) );
	return $out; 
}

1;





