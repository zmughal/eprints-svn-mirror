package EPrints::Plugin::Screen::Admin::RAEReport;

our @ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "admin_actions",
			position => 2100,
		}
	];
	
	return $self;
}

sub render
{
	my( $self ) = @_;

	my $perl_url = $self->{session}->get_repository->get_conf( "perl_url" );
	$self->{session}->redirect( $perl_url . "/users/rae/report" );

}	

1;
