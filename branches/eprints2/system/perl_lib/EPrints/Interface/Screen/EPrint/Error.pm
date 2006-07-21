
package EPrints::Interface::Screen::Error;

use EPrints::Interface::Screen::EPrint;

@ISA = ( 'EPrints::Interface::Screen::EPrint' );

use strict;

sub new
{
	my( $class, $processor ) = @_;

	$class->SUPER::new( $processor );
}

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$self->{processor}->{title} = $self->{session}->make_text("Error");

	return $chunk;
}

# ignore the form. We're screwed at this point, and are just reporting.
sub from
{
	my( $self ) = @_;

	return;
}

1;

