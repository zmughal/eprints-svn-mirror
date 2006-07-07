package EPrints::Plugin::InputForm::Surround::Default;

use strict;

our @ISA = qw/ EPrints::Plugin /;


sub render
{
	my( $self, $component ) = @_;

	my $is_req = $component->is_required();
	my $help = $component->render_help( $self );
	my $collapsed = $component->is_collapsed();
	my $comp_name = $component->get_name();
	my $title = $component->render_title( $self );
	my @problems = @{$component->get_problems()};

	my $surround = $self->{session}->make_element( "div", class => "wf_component" );

	# Help rendering
	
	my $helpimg = $self->{session}->make_element( "img", src => "/images/help.gif", class => "wf_help_icon", border => "0" );
	my $helplink = $self->{session}->make_element( "a", onClick => "doToggle('help_${comp_name}')" );
	$helplink->appendChild( $helpimg );
	my $help_div = $self->{session}->make_element( "div", class => "wf_help", style => "display: none", id => "help_${comp_name}" );
	$help_div->appendChild( $help );
	
	# Title rendering
	
	my $title_div = $self->{session}->make_element( "div", class => "wf_title" );
	$title_div->appendChild( $helplink );

	# Add the title and 'required' button if necessary. 
	
	$title_div->appendChild( $title );
	
	if( $is_req )
	{
		$title_div->appendChild( $self->get_req_icon() );
	}

	$surround->appendChild( $title_div );
	$surround->appendChild( $help_div );
	
	# Problem rendering

	if( scalar @problems > 0 )
	{
		my $problem_div = $self->{session}->make_element( "div", class => "wf_problems" );
		foreach my $problem ( @problems )
		{
			$problem_div->appendChild( $problem );
		}
		$surround->appendChild( $problem_div );
	}

	# Finally add the content (unless we're collapsed)
	my $input_div = $self->{session}->make_element( "div", class => "wf_input" );
	if( !$collapsed )
	{
		$input_div->appendChild( $component->render_content( $self ) );
	}
	
	$surround->appendChild( $input_div );
	
	return $surround;
}

sub get_req_icon
{
	my( $self ) = @_;
	my $reqimg = $self->{session}->make_element( "img", src => "/images/req.gif", class => "wf_req_icon", border => "0" );
	return $reqimg;
}

1;
