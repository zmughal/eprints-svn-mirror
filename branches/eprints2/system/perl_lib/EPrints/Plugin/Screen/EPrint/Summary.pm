package EPrints::Plugin::Screen::EPrint::Summary;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{priv} = "view/eprint/summary";
	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 100,
		}
	];

	return $self;
}

sub render
{
	my( $self ) = @_;

	my ($data,$title) = $self->{processor}->{eprint}->render; 

	return $data;
}	


1;
