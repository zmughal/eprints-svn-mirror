package EPrints::Plugin::Component::FieldComponent;

use EPrints::Plugin::Component;

@ISA = ( "EPrints::Plugin::Component" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "FieldComponent";
	$self->{visible} = "all";

	return $self;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;

	# Set up $self->{config} with $self->{config}->{metafield}
}

=pod

=item $dom = $fieldcomponent->update_from_form( $session )

Set the values of the object we are working with from the submitted form.

=cut

sub update_from_form
{
	my( $self, $session ) = @_;
	my $value = $self->{config}->{metafield}->form_value( $session );
	$self->{dataobj}->set_value( $self->{field}, $value );
}

=pod

=item @problems = $fieldcomponent->validate( $session )

Returns a set of problems (DOM objects) if the component is unable to validate.

=cut

sub validate
{
	my( $self, $session ) = @_;

	# moj: Requirement validation can be done at a workflow level.

	my $for_archive = 1; # moj: 

	my $field = $self->{field};
	my $metafield = $self->{config}->{metafield};
	my @problems;

	if( $self->is_required() && !$self->{dataobj}->is_set( $field ) )
	{
		my $problem = $session->html_phrase(
			"lib/eprint:not_done_field" ,
			fieldname=> $metafield->render_name( $session ) );
		push @problems, $problem;
	}
	
	push @problems, $session->get_archive()->call(
		"validate_field",
		$metafield,
		$self->{dataobj}->get_value( $field ),
		$session,
		$for_archive );

	$self->{problems} = \@problems;

	return @problems;
}

=pod

=item $bool = $component->is_required()

returns true if this component is required to be completed before the
workflow may proceed

=cut

sub is_required
{
	my( $self ) = @_;
	return $self->{stage}->get_workflow->is_required( 
		$self->{config}->{metafield} );
}

=pod

=item $help = $component->render_help( $session )

Returns DOM containing the help text for this component.

=cut

sub render_help
{
	my( $self, $session ) = @_;
	return $self->{config}->{metafield}->render_help( 
		$session, 
		$self->{config}->{metafield}->get_type() );
}

=pod

=item $name = $component->get_name()

Returns the unique name of this field (for prefixes, etc).

=cut

sub get_name
{
	my( $self ) = @_;
	return $self->{config}->{metafield}->get_name();
}

=pod

=item $title = $component->render_title( $session )

Returns the title of this component as a DOM object.

=cut

sub render_title
{
	my( $self, $session ) = @_;
	return $self->{config}->{metafield}->render_name( $session );
}

=pod

=item $content = $component->render_content( $session )

Returns the DOM for the content of this component.

=cut

sub render_content
{
	my( $self, $session ) = @_;
	
	my $value;
	if( $self->{dataobj} )
	{
		$value = $self->{dataobj}->get_value( $self->{field} );
	}
	else
	{
		$value = $self->{default};
	}

	return $self->{config}->{metafield}->render_input_field( $session, $value );
}

######################################################################
1;
