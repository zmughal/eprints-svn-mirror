package EPrints::Plugin::Control::Blister;

use EPrints::Plugin::Control;

@ISA = ( "EPrints::Plugin::Control" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "control/blister";
	$d{name} = "Blister";
	$d{visible} = "all";

	return %d;
}


sub render
{
  my( $self, $defobj, $params ) = @_;
 
  my $session = $params->{session};
  my $workflow = $params->{workflow};
  
  my @stages = @{$workflow->{stages}};
  my $tdwid = POSIX::floor(50/(scalar @stages));
  
  my $table = $session->make_element( "table", width => "100%" );
  my $tr = $session->make_element( "tr", width => "100%" );
  my $td = $session->make_element( "td", width => "50%" );
  $td->appendChild( $session->make_text( $workflow->get_stage( $params->{stage} )->get_title ) );
  $tr->appendChild( $td );
  my $pos = 1;
  foreach my $stage ( @stages ) 
  {
  
    my $td = $session->make_element( "td", width => "$tdwid%" );
    $td->appendChild( $session->make_text( "$pos. " ) );
    $td->appendChild( $session->make_text( $stage->get_short_title ) );
    $tr->appendChild( $td );
    $pos++;
  }
  $table->appendChild( $tr );
  return $table;
}

1;





