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

=pod

=item $dom = $fieldcomponent->render_field()

Returns DOM for the input field of this component. This may be overridden to provide
extra functionality,

=cut

sub render_field
{
	my( $self, $session, $metafield, $value ) = @_;
	return $metafield->render_input_field( $session, $value );
}

=pod

=item $dom = $fieldcomponent->render_shell()

Returns DOM representing the 'shell' of the component - i.e. a container including
help information, the field name, and an indication of its requirement. 

Parameters:
help - the DOM to render as the help text
req - true if this field is required, false if not
title - the DOM to render as the title text
name - a unique ID for reference.

=cut

sub render_shell
{
	my( $self, %params) = @_;
	
	my $session = $params{session};

	my $shell = $session->make_element( "div", class => "wf_component" );
	$shell->appendChild( $self->render_title( $session, $params{title}, $params{req}, $params{name} ) );
	$shell->appendChild( $self->render_help( $session, $params{help}, $params{name} ) );
	return $shell;
}

sub render_help
{
	my( $self, $session, $help, $name ) = @_;
	my $helpdiv = $session->make_element( "div", class => "wf_help", style => "display: none", id => "help_$name" );
	$helpdiv->appendChild( $help ); 
	return $helpdiv;
}

sub render_title
{
	my( $self, $session, $title, $req, $name) = @_;
	
	my $helpimg = $session->make_element( "img", src => "/images/help.gif", class => "wf_help_icon", border => "0" );
	my $reqimg = $session->make_element( "img", src => "/images/req.gif", class => "wf_req_icon", border => "0" );

	my $titlediv = $session->make_element( "div", class => "wf_title" );

	my $helplink = $session->make_element( "a", onClick => "doToggle('help_$name')" );
	$helplink->appendChild($helpimg);

	$titlediv->appendChild( $helplink );
	
	if($req)
	{
		$titlediv->appendChild( $reqimg );
	}
	
	$titlediv->appendChild( $session->make_text(" ") );
	$titlediv->appendChild( $title );

	return $titlediv;
}

=pod

=item @problems = $plugin->validate()

Returns a set of problems (DOM objects) if the component is unable to validate.

=cut


sub validate
{
	return 1;
}

sub render
{
	my( $self, $defobj, $params ) = @_;
	my $session = $params->{session};
	my $field = $self->{field};
	my $user_ds = $session->get_repository->get_dataset( "eprint" );
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

	# Get a few values
	my $title = $metafield->render_name( $session );
	my $help  = $metafield->render_help( $session, $metafield->get_type() );
	my $name  = $metafield->get_name;
	my $req   = $user_ds->field_required_in_type( $metafield, "article" );

	# Get the shell
	my $outer = $self->render_shell( 
		session => $session, 
		title => $title,
		help => $help,
		req => $req,
		name => $name );
		
		
	# Render the input
	
	my $div = $session->make_element( "div", class => "wf_input" );

	$div->appendChild( $self->render_field( $session, $metafield, $value ) );
	$outer->appendChild( $div );
	return $outer;
}

1;





