package EPrints::Plugin::InputForm::Component::FieldComponent::MultiComponent;

use EPrints::Plugin::InputForm::Component::FieldComponent;

@ISA = ( "EPrints::Plugin::InputForm::Component::FieldComponent" );

use Unicode::String qw(latin1);
use EPrints::InputField;

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "MultiComponent";
	$self->{visible} = "all";

	return $self;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;
	
	$self->{config}->{fields} = [];

# moj: We need some default phrases for when these aren't specified.
#	$self->{config}->{title} = ""; 
#	$self->{config}->{help} = ""; 

	my @fields = $config_dom->getElementsByTagName( "wf:field" );
	my @title_nodes = $config_dom->getElementsByTagName( "title" );
	my @help_nodes  = $config_dom->getElementsByTagName( "help" );

	if( scalar @title_nodes == 1 )
	{
		if( $title_nodes[0]->hasAttribute( "ref" ) )
		{
			$self->{config}->{title} = $title_nodes[0]->getAttribute( "ref" );
		}
	}
	
	if( scalar @help_nodes == 1 )
	{
		if( $help_nodes[0]->hasAttribute( "ref" ) )
		{
			$self->{config}->{help} = $help_nodes[0]->getAttribute( "ref" );
		}
	}

	if( scalar @fields < 1 )
	{

		print STDERR "Meep!\n";
	}
	else
	{
		foreach my $field ( @fields )
		{
			my $input_field = new EPrints::InputField( dom => $field, dataobj => $self->{dataobj} );
			push @{$self->{config}->{fields}}, $input_field;
			
		}
	}
}

sub render_content
{
	my( $self, $session, $surround ) = @_;

	my $table = $session->make_element( "table" );
	my $tbody = $session->make_element( "tbody", class => "sidetable" );
	$table->appendChild( $tbody );
	my ($th, $tr, $td);
	foreach my $field ( @{$self->{config}->{fields}} )
	{
		$tr = $session->make_element( "tr" );
		
		# Get the field and its value/default
		my $value;
		
		if( $self->{dataobj} )
		{
			$value = $self->{dataobj}->get_value( $field->{name} );
		}
		else
		{
			$value = $self->{default};
		}
		
		# Append field
		$th = $session->make_element( "th" );
		$th->appendChild( $field->{handle}->render_name( $session ) );

 
		if( $field->{required} eq "yes" ) # moj: Handle for_archive
		{
			$th->appendChild( 
				$surround->get_req_icon( $session ) );
		}
		
		$td = $session->make_element( "td" );
		$td->appendChild( $field->{handle}->render_input_field( $session, $value ) );
		$tr->appendChild( $th );
		$tr->appendChild( $td );
		$tbody->appendChild( $tr );
	}
	return $table;
}

sub render_help
{
	my( $self, $session, $surround ) = @_;
	my $phrase = $session->html_phrase( $self->{config}->{help} );
	return $phrase;
}

sub render_title
{
	my( $self, $session, $surround ) = @_;
	my $phrase = $session->html_phrase( $self->{config}->{title} );
	return $phrase;
}


sub is_collapsed
{
	my( $self, $session ) = @_;
	return $self->are_all_collapsed( $self->{config}->{fields} );
}

1;





