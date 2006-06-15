package EPrints::Plugin::InputForm::Component::FieldComponent::MultiComponent;

use EPrints::Plugin::InputForm::Component::FieldComponent;

@ISA = ( "EPrints::Plugin::InputForm::Component::FieldComponent" );

use Unicode::String qw(latin1);

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

	my @fields = $config_dom->getElementsByTagName( "field" );
	my @title_nodes = $config_dom->getElementsByTagName( "title" );
	my @help_nodes  = $config_dom->getElementsByTagName( "help" );

	if( scalar @title_nodes == 1 )
	{
		if( $title_nodes[0]->hasAttribute( "ref" ) )
		{
			my $phrase_ref = $title_nodes[0]->getAttribute( "ref" );
			$self->{config}->{title} = $self->{session}->html_phrase( $phrase_ref );
		}
		else
		{
			my @phrase_dom = $title_nodes[0]->getElementsByTagName( "phrase" );
			if( scalar @phrase_dom == 1 )
			{
				$self->{config}->{title} = $phrase_dom[0];
			}
		}
	}
	
	if( scalar @help_nodes == 1 )
	{
		if( $help_nodes[0]->hasAttribute( "ref" ) )
		{
			my $phrase_ref = $help_nodes[0]->getAttribute( "ref" );
			$self->{config}->{help} = $self->{session}->html_phrase( $phrase_ref );
		}
		else
		{
			my @phrase_dom = $help_nodes[0]->getElementsByTagName( "phrase" );
			if( scalar @phrase_dom == 1 )
			{
				$self->{config}->{title} = $phrase_dom[0];
			}
		}
	}

	if( scalar @fields < 1 )
	{

		print STDERR "Meep!\n";
	}
	else
	{
		foreach my $field_tag ( @fields )
		{
			my $field = $self->xml_to_metafield( $field_tag );
			push @{$self->{config}->{fields}}, $field;
			
		}
	}
}

sub render_content
{
	my( $self, $surround ) = @_;

	my $table = $self->{session}->make_element( "table" );
	my $tbody = $self->{session}->make_element( "tbody", class => "sidetable" );
	$table->appendChild( $tbody );
	my ($th, $tr, $td);
	foreach my $field ( @{$self->{config}->{fields}} )
	{
		$tr = $self->{session}->make_element( "tr" );
		
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
		$th = $self->{session}->make_element( "th" );
		$th->appendChild( $field->render_name( $self->{session} ) );

 
		if( $field->{required} eq "yes" ) # moj: Handle for_archive
		{
			$th->appendChild( $surround->get_req_icon );
		}
		
		$td = $self->{session}->make_element( "td" );
		$td->appendChild( $field->render_input_field( $self->{session}, $value ) );
		$tr->appendChild( $th );
		$tr->appendChild( $td );
		$tbody->appendChild( $tr );
	}
	return $table;
}

sub render_help
{
	my( $self, $surround ) = @_;
	return $self->{config}->{help};
}

sub render_title
{
	my( $self, $surround ) = @_;
	return $self->{config}->{title};
}


sub is_collapsed
{
	my( $self ) = @_;
	return $self->are_all_collapsed( $self->{config}->{fields} );
}

1;





