
package EPrints::Plugin::Screen::User::SaveSearch;

use EPrints::Plugin::Screen::User;

@ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ create /];

	return $self;
}

sub allow_create
{
	my ( $self ) = @_;

	return $self->allow( "create_saved_search" );
}

sub action_create
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{session}->get_repository->get_dataset( "saved_search" );

	my $user = $self->{session}->current_user;

	my $id = $self->{session}->param( "cache" );
        my $string = $self->{session}->get_database->cache_exp( $id );
        my $userid = $self->{session}->get_database->cache_userid( $id );
	if( $userid != $user->get_id )
	{
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "not_your_search" ) );
		$self->{processor}->{screenid} = "User::View";
		return;
	}

   	my $search = new EPrints::Search(
		keep_cache => 1,
		session => $self->{session},
		dataset => $self->{session}->get_repository->get_dataset( "archive" ) );
	$search->from_string_raw( $string );


	$self->{processor}->{savedsearch} = $ds->create_object( $self->{session}, { 
		userid => $user->get_value( "userid" ),
		name => EPrints::Utils::tree_to_utf8( $search->render_conditions_description ),
		spec => $string } );

	if( !defined $self->{processor}->{savedsearch} )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{processor}->{session}->get_repository->log( "Database Error: $db_error" );
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "db_error" ) );
		$self->{processor}->{screenid} = "User::View";
		return;
	}

	$self->{processor}->{savedsearchid} = $self->{processor}->{savedsearch}->get_id;
	$self->{processor}->{screenid} = "User::SavedSearch::Edit";
	$self->{processor}->add_message( 
		"message",
		$self->html_phrase( "done" ) );

}



1;