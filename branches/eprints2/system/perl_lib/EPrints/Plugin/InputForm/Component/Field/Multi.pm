package EPrints::Plugin::InputForm::Component::Field::Multi;

use EPrints::Plugin::InputForm::Component::Field;

@ISA = ( "EPrints::Plugin::InputForm::Component::Field" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Multi";
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

	if( @fields == 0 )
	{
		# error!
		EPrints::abort( "Multifield with no fields defined." );
	}

	foreach my $field_tag ( @fields )
	{
		my $field = $self->xml_to_metafield( $field_tag );
		push @{$self->{config}->{fields}}, $field;
	}


	if( scalar @title_nodes == 1 )
	{
		my $phrase_ref = $title_nodes[0]->getAttribute( "ref" );
		if( EPrints::Utils::is_set( $phrase_ref ) )
		{
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

	# multi fields don't _have_ to have a title really...	
	if( !defined $self->{config}->{title} ) 
	{
		$self->{config}->{title} = $self->{session}->make_doc_fragment;
	}

	
	if( scalar @help_nodes == 1 )
	{
		my $phrase_ref = $help_nodes[0]->getAttribute( "ref" );
		if( EPrints::Utils::is_set( $phrase_ref ) )
		{
			$self->{config}->{help} = $self->{session}->html_phrase( $phrase_ref );
		}
		else
		{
			my @phrase_dom = $help_nodes[0]->getElementsByTagName( "phrase" );
			if( scalar @phrase_dom == 1 )
			{
				$self->{config}->{help} = $phrase_dom[0];
			}
		}
	}
	else
	{
		# no <help> configured. Do something sensible.
		
		$self->{config}->{help} = $self->{session}->make_doc_fragment;
		foreach my $field ( @{$self->{config}->{fields}} )
		{
			$self->{config}->{help}->appendChild( 
				$field->render_help( 
					$self->{session}, 
					$field->get_type() ) );
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





