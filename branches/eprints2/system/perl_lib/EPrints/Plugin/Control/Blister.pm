package EPrints::Plugin::Component::Blister;

use EPrints::Plugin::Component;

@ISA = ( "EPrints::Plugin::Component" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "component/blister";
	$d{name} = "Blister";
	$d{visible} = "all";

	return %d;
}


sub render
{
	my( $self, $defobj, $params ) = @_;
	
	my $session = $params->{session};
	my $workflow = $params->{workflow};

	my $base = $session->make_element( "div", class => "wf_blister" );
	my $stages = $session->make_element( "div", class => "wf_blister_stages" );
	
	my @stages = @{$workflow->{stages}};
	my $current = $session->make_element( "div", class => "wf_blister_stage_curr" );;
	foreach(@stages)
	{
		my $div;
		if( $params->{stage} eq $_->get_name() )
		{
			$div = $session->make_element( "div", class => "wf_blister_stage_curr" );
			$current->appendChild( $session->make_text( $_->get_title() ) );
		}
		else
		{
			$div = $session->make_element( "div", class => "wf_blister_stage" );
		}
		$div->appendChild( $session->make_text( $_->get_name() ) );
		$stages->appendChild( $div );
	}
	$base->appendChild( $stages );
	$base->appendChild( $current );

	return $base;
}

1;





