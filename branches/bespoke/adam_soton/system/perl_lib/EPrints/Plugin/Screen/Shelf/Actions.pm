package EPrints::Plugin::Screen::Shelf::Actions;

our @ISA = ( 'EPrints::Plugin::Screen::Shelf' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "shelf_view_tabs",
			position => 300,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless scalar $self->action_list( "shelf_actions" );

	return $self->who_filter;
}

sub who_filter { return 4; }

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	return $self->render_action_list( "shelf_actions", ['shelfid'] );
}

1;
