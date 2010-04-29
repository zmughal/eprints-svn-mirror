
package EPrints::Plugin::Screen::NewCoversheet;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ create /];

	$self->{appears} = [
		{
			place => "coversheet_tools",
			action => "create",
			position => 100,
		}
	];

	return $self;
}

sub allow_create
{
	my ( $self ) = @_;

	return $self->allow( "coversheet/write" );
}

sub action_create
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{session}->get_repository->get_dataset( "coversheet" );

	my $user = $self->{session}->current_user;

	$self->{processor}->{coversheet} = $ds->create_object( $self->{session}, { 
		userid => $user->get_value( "userid" ) } );

	if( !defined $self->{processor}->{coversheet} )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{processor}->{session}->get_repository->log( "Database Error: $db_error" );
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "db_error" ) );
		return;
	}

	$self->{processor}->{coversheetid} = $self->{processor}->{coversheet}->get_id;
	$self->{processor}->{screenid} = "Coversheet::Edit";

}



1;
