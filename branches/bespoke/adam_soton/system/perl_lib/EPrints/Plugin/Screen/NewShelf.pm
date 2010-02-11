
package EPrints::Plugin::Screen::NewShelf;

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
			place => "shelf_tools",
			action => "create",
			position => 100,
		}
	];

	return $self;
}

sub allow_create
{
	my ( $self ) = @_;

	return 1;

	return $self->allow( "create_shelf" );
}

sub action_create
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{session}->get_repository->get_dataset( "shelf" );

	my $user = $self->{session}->current_user;

	$self->{processor}->{shelf} = $ds->create_object( $self->{session}, { 
		userid => $user->get_value( "userid" ) } );

	if( !defined $self->{processor}->{shelf} )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{processor}->{session}->get_repository->log( "Database Error: $db_error" );
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "db_error" ) );
		return;
	}

	$self->{processor}->{shelfid} = $self->{processor}->{shelf}->get_id;
	$self->{processor}->{screenid} = "Shelf::Edit";

}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $url = URI->new($self->{processor}->{url});
	$url->query_form( 
		screen => $self->{processor}->{screenid},
		_action_create => 1
		);

	$session->redirect( $url );
	$session->terminate();
	exit(0);
}


1;
