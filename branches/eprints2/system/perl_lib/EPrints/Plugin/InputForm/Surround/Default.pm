package EPrints::Plugin::InputForm::Surround::Default;

use strict;

our @ISA = qw/ EPrints::Plugin /;

sub render
{
	my( $self, $component, $session ) = @_;

	my $is_req = $component->is_required();
	my $help = $component->render_help($session);
	my $collapsed = $component->is_collapsed();
	my $comp_name = $component->get_name();
	my $title = $component->render_title($session);

	my $surround = $session->make_element( "div", class => "wf_component" );

	# Help rendering
	
	my $helpimg = $session->make_element( "img", src => "/images/help.gif", class => "wf_help_icon", border => "0" );
	my $helplink = $session->make_element( "a", onClick => "doToggle('help_${comp_name}')" );
	$helplink->appendChild( $helpimg );
	my $help_div = $session->make_element( "div", class => "wf_help", style => "display: none", id => "help_${comp_name}" );
	$help_div->appendChild( $help );
	
	# Title rendering
	
	my $title_div = $session->make_element( "div", class => "wf_title" );
	$title_div->appendChild( $helplink );

	# Add the title and 'required' button if necessary. 
	
	if( $is_req )
	{
		my $reqimg = $session->make_element( "img", src => "/images/req.gif", class => "wf_req_icon", border => "0" );
		$title_div->appendChild( $reqimg );
	}

	$title_div->appendChild( $title );

	$surround->appendChild( $title_div );
	$surround->appendChild( $help_div );

	# Finally add the content (unless we're collapsed)
	my $input_div = $session->make_element( "div", class => "wf_input" );
	if( !$collapsed )
	{
		$input_div->appendChild( $component->render_content($session, $self) );
	}
	
	$surround->appendChild( $input_div );
	
	return $surround;
}


1;
