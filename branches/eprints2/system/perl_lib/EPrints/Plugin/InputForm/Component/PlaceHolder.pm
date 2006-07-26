package EPrints::Plugin::InputForm::Component::PlaceHolder;

use EPrints::Plugin::InputForm::Component;

@ISA = ( "EPrints::Plugin::InputForm::Component" );

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
	my( $self ) = @_;

	return $self->{session}->make_text( "This is a placeholder for the ".$self->{placeholding}." component" );
}

sub render_help
{
	my( $self, $surround ) = @_;
	
	return $self->{session}->make_text( "Help placeholder for ".$self->{placeholding}. " component" );
}

sub render_title
{
	my( $self, $surround ) = @_;

	return $self->{session}->make_text( "Problem loading component: ".$self->{placeholding} );
}
	
1;





