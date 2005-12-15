package EPrints::Plugin::Component::MultiComponent;

use EPrints::Plugin::Component;

@ISA = ( "EPrints::Plugin::Component" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "component/default";
	$d{name} = "MultiComponent";
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
	

#	my $control = $session->make_element( "div", class => "wf_control" );

#	my $helpdiv = $session->make_doc_fragment();
#	my $namediv = $session->make_doc_fragment();
#	my $namebardiv = $session->make_doc_fragment();
#	my $inputdiv= $session->make_doc_fragment();;
#	
#	$namebardiv = $session->make_element( "div", class => "wf_control_name_bar" );
 #
 #	# Help section
#	if( $params->{show_help} )
#	{
#		$helpdiv = $session->make_element( "div", style => "display: none", class => "tipbox", id => "wf_control_help_".$metafield->get_name );
#		my $help = $metafield->render_help( $session, $metafield->get_type() ) ;
#		
#		
#		# Necessary for the Javascript
#		my $container = $session->make_element( "div", class=>"content" );
#		$container->appendChild( $help );
#		
#		$helpdiv->appendChild( $container );
#		
#		my $link = $session->make_element( "a", onClick => "Effect.Appear('wf_control_help_".$metafield->get_name."')");
#		my $helpimg = $session->make_element( "img", valign => "middle", style => "float: right", src => "/images/help.gif", border => "0" );
#		$link->appendChild( $helpimg );
#		$namebardiv->appendChild( $link );
#	}
#
#	# Name section
#	$namediv = $session->make_element( "div", class => "wf_control_name" ); 
#	$namediv->appendChild( $metafield->render_name( $session ) );
#	$namebardiv->appendChild( $namediv );
#	
#	# Input control
#	$inputdiv = $session->make_element( "div", class => "wf_control_input", id => "inputfield_".$metafield->get_name );
#	$inputdiv->appendChild( $metafield->render_input_field( $session, $value ) );
#	
#	$control->appendChild( $namebardiv );
#	$control->appendChild( $session->make_element( "div", style => "clear: all" ) );
#	$control->appendChild( $helpdiv );
#	$control->appendChild( $inputdiv );
#	
#	return $control;
}

1;





