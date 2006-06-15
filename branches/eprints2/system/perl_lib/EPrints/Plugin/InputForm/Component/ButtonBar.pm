package EPrints::Plugin::InputForm::Component::ButtonBar;

use EPrints::Plugin::InputForm::Component;

@ISA = ( "EPrints::Plugin::InputForm::Component" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "ButtonBar";
	$self->{visible} = "all";

	return $self;
}

=pod

=item $bool = $component->parse_config( $dom )

Parses the supplied DOM object and populates $component->{config}

=cut

sub parse_config
{
	my( $self, $dom ) = @_;
}

=pod

=item $content = $component->render_content()

Returns the DOM for the content of this component.

=cut


sub render_content
{
	my( $self ) = @_;

	# Handle the buttons

	my $workflow = $self->{workflow};
	my $stage = $workflow->{stage};

	my $order = [];
	if( $workflow->get_first_stage_id ne $stage )
	{
		push @$order, "prev";
	}

	push @$order, "save";

	if( $workflow->get_last_stage_id ne $stage )
	{
		push @$order, "next";
	}

	my $submit_buttons = {
		_order => $order,
		_class => "submission_buttons",
	};

	foreach my $button( @$order )
	{
		$submit_buttons->{$button} = $self->{session}->phrase( "lib/submissionform:action_$button" );
	}

	$submit_buttons->{_order} = $order;

	my $hidden_fields = {
		stage => $stage,
	};

	my $dom = $self->{session}->make_doc_fragment; 

#	my $form = $self->{session}->render_form( "post", $self->{formtarget}."#t" );
	$dom->appendChild( $self->{session}->render_action_buttons( %$submit_buttons ) );
	return $dom; 
}

1;





