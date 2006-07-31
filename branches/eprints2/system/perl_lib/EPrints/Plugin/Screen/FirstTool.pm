
package EPrints::Plugin::Screen::FirstTool;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;


sub from
{
	my( $self ) = @_;

	my @tools = $self->get_allowed_tools;

	$self->{processor}->{screenid} = $tools[0]->{screen};

	$self->SUPER::from;
}


1;

