package EPrints::Plugin::Control::Phrase;

use EPrints::Plugin::Control;

@ISA = ( "EPrints::Plugin::Control" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "control/phrase";
	$d{name} = "Phrase";
	$d{visible} = "all";

	return %d;
}

sub render
{
  my( $self, $defobj, $params ) = @_;
  my $phrase = $params->{session}->html_phrase( $self->{params}->{phraseid} );
  return $phrase; 
}

1;





