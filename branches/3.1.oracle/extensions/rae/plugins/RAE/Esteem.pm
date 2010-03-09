package EPrints::Plugin::Screen::User::RAE::Esteem;

our @ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "user_actions",
			position => 2000,
		}
	];
	
	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/staff/edit" );
}

sub render
{
	my( $self ) = @_;

	my $perl_url = $self->{session}->get_repository->get_conf( "perl_url" );
	$self->{session}->redirect( $perl_url . "/users/rae/moe?role=" . $self->{processor}->{user}->get_id );

}	

1;
