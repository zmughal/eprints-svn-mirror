
package EPrints::Interface::Screen::Search::User;

use EPrints::Interface::Screen;

@ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub new
{
	my( $class, $processor ) = @_;

	$class->SUPER::new( $processor );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;

	return $session->make_doc_fragment;
}

1;
