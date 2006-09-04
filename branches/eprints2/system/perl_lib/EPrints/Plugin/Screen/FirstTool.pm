
package EPrints::Plugin::Screen::FirstTool;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;


sub from
{
	my( $self ) = @_;

	my @tools = ( $self->list_items( "key_tools" ), $self->list_items( "other_tools" ) );

	$self->{processor}->{screenid} = substr( $tools[0]->{screen}->{id}, 8 );

	$self->SUPER::from;
}


1;

