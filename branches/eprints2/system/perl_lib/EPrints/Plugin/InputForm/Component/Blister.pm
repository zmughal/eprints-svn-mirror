package EPrints::Plugin::InputForm::Component::Blister;

use EPrints::Plugin::InputForm::Component;

@ISA = ( "EPrints::Plugin::InputForm::Component" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Blister";
	$self->{visible} = "all";

	return $self;
}

=pod

=item $content = $component->render_content( $session )

Returns the DOM for the content of this component.

=cut

sub render_content
{
	my( $self, $session ) = @_;
	
	my $workflow = $self->{stage}->get_workflow();

	my $base = $session->make_element( "div", class => "wf_blister" );
	my $stages = $session->make_element( "div", class => "wf_blister_stages" );
	
	my @stages = @{$workflow->{stages}};
	my $current = $session->make_element( "div", class => "wf_blister_stage_curr" );
	
	foreach(@stages)
	{
		my $div;
		my $err = "";
		if( $_->has_problems() )
		{
			$err = "_prob";
		}
		
		if( $self->{stage}->get_name() eq $_->get_name() )
		{
			$div = $session->make_element( "div", class => "wf_blister_stage_curr$err" );
			$current->appendChild( $session->make_text( $_->get_title() ) );
		}
		else
		{
			$div = $session->make_element( "div", class => "wf_blister_stage$err" );
		}
		$div->appendChild( $session->make_text( $_->get_name() ) );
		$stages->appendChild( $div );
	}
	$base->appendChild( $stages );
	$base->appendChild( $current );

	return $base;
}

1;





