package EPrints::Plugin::Screen::EPrint::Details;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{priv} = "view/eprint/full";

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 200,
		},
	];

	return $self;

}


sub render
{
	my( $self ) = @_;

	my ($data,$title) = $self->{processor}->{eprint}->render_full; 

	return $data;
}	


1;
