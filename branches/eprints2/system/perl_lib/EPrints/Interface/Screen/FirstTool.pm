
package EPrints::Interface::Screen::FirstTool;

use EPrints::Interface::Screen::EPrint;

@ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub new
{
	my( $class, $processor ) = @_;

	$class->SUPER::new( $processor );
}


sub from
{
	my( $self ) = @_;

	my @tools = $self->get_allowed_tools;

	$self->{processor}->{screenid} = $tools[0]->{screen};

	$self->SUPER::from;
}


1;

