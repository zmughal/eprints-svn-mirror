package EPrints::Plugin::Component::Phrase;

use EPrints::Plugin::Component;

@ISA = ( "EPrints::Plugin::Component" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Phrase";
	$self->{visible} = "all";

	return $self;
}

sub render
{
	my( $self, $defobj, $params ) = @_;
	my $phrase = $params->{session}->html_phrase( $self->{params}->{phraseid} );
	return $phrase; 
}

1;





