package EPrints::Plugin::Screen::Admin::Config::Edit::Autocomplete;

use EPrints::Plugin::Screen::Admin::Config::Edit;

@ISA = ( 'EPrints::Plugin::Screen::Admin::Config::Edit' );

use strict;

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/edit/autocomplete" );
}

1;
