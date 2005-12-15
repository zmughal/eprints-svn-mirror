package EPrints::Plugin::Component::Default;

use EPrints::Plugin::Component;

@ISA = ( "EPrints::Plugin::Component" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "component/default";
	$d{name} = "Default";
	$d{visible} = "all";

	return %d;
}


sub render_outer
{
	my( $self, $session, $metafield, $dataset, $type ) = @_;
	my $shell = $session->make_element( "div", class => "wf_component" );
	my $name = $metafield->get_name;
	
	my $helpimg = $session->make_element( "img", src => "/images/help.gif", class => "wf_help_icon", border => "0" );
	my $reqimg = $session->make_element( "img", src => "/images/req.gif", class => "wf_req_icon", border => "0" );

	my $title = $session->make_element( "div", class => "wf_title" );

	my $helplink = $session->make_element( "a", onClick => "doToggle('help_$name')" );
	$helplink->appendChild($helpimg);

	$title->appendChild( $helplink );
	
	my $req = $dataset->field_required_in_type( $metafield, $type );
	if($req)
	{
		$title->appendChild( $reqimg );
	}
	$title->appendChild( $session->make_text(" ") );
	$title->appendChild( $metafield->render_name( $session ) );

	my $help = $session->make_element( "div", class => "wf_help", style => "display: none", id => "help_$name" );
	$help->appendChild( $metafield->render_help( $session, $metafield->get_type() ) );

	$shell->appendChild( $title );
	$shell->appendChild( $help );
	return $shell;

}

sub render
{
	my( $self, $defobj, $params ) = @_;
  
	my $session = $params->{session};
	my $field = $self->{params}->{field};
	my $user_ds = $session->get_archive()->get_dataset( "eprint" );
	my $metafield = $user_ds->get_field( $field );

	my $value;
	if( $params->{eprint} )
	{
		$value = $params->{eprint}->get_value( $field );
	}
	else
	{
		$value = $params->{default};
	}


	# Get the shell
	my $outer = $self->render_outer( $session, $metafield, $user_ds, "article" );
	
	# Render the input
	
	my $div = $session->make_element( "div", class => "wf_input" );

	$div->appendChild( $metafield->render_input_field( $session, $value ) );
	$outer->appendChild( $div );
	return $outer;
}

1;





