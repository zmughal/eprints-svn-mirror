package EPrints::Plugin::Screen::EPrint::Staff::EditLink;

use EPrints::Plugin::Screen::EPrint::EditLink;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::EditLink' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{priv} = "action/eprint/edit_staff";

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 400,
		}
	];

	return $self;
}

sub show_in
{
	return( eprint_view_tabs => 400 );
}

sub things
{
	my( $self ) = @_;

	return( "EPrint::Edit_staff", $self->workflow(1) );
}


1;
