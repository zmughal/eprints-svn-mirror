package EPrints::Plugin::Control::Default;

use EPrints::Plugin::Control;

@ISA = ( "EPrints::Plugin::Control" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "control/default";
	$d{name} = "Default";
	$d{visible} = "all";

	return %d;
}


sub render
{
  my( $self, $defobj, $params ) = @_;
  
  my $session = $params->{session};
  my $field = $self->{params}->{field};
  my $user_ds = $session->get_archive()->get_dataset( "eprint" );
  my $metafield = $user_ds->get_field( $field );
  
  my $frag = $session->make_doc_fragment;
  my $div = $session->make_element( "div", class => "formfieldname" );
  $div->appendChild( $metafield->render_name( $session ) );
  $frag->appendChild( $div );
  $div = $session->make_element( "div", class => "formfieldinput", id => "inputfield_".$metafield->get_name );
  $div->appendChild( $metafield->render_input_field( $session, $self->{params}->{default} ) );
  $frag->appendChild( $div );
  return $frag;
}

1;





