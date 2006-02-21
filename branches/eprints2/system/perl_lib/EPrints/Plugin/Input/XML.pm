package EPrints::Plugin::Input::XML;

use strict;

use EPrints::Plugin::Input::DefaultXML;

our @ISA = qw/ EPrints::Plugin::Input::DefaultXML /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "XML";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/*', 'dataobj/*' ];

	return $self;
}

sub top_level_tag
{
	my( $plugin, $dataset ) = @_;

	return $dataset->confid."s";
}

sub xml_to_dataobj
{
	my( $plugin, $dataset, $xml ) = @_;

	my $data = $plugin->xml_to_data( $dataset, $xml );

	return $plugin->data_to_dataobj( $dataset, $data );
}

sub xml_to_data
{
	my( $plugin, $dataset, $xml ) = @_;

	my @fields = $dataset->get_fields;
	my @fieldnames = ();
	foreach( @fields ) { push @fieldnames, $_->get_name; }

	my %toprocess = $plugin->get_known_nodes( $xml, @fieldnames );

	my $data = {};
	foreach my $fn ( keys %toprocess )
	{
		my $field = $dataset->get_field( $fn );
		$data->{$fn} = $plugin->xml_field_to_data( $dataset, $field, $toprocess{$fn} );
	}
	return $data;
}

sub xml_to_file
{
	my( $plugin, $dataset, $xml ) = @_;

	my %toprocess = $plugin->get_known_nodes( $xml, qw/ filename filesize url data / );

	my $data = {};
	foreach my $part ( keys %toprocess )
	{
		$data->{$part} = $plugin->xml_to_text( $toprocess{$part} );
	}
	
	return $data;
}


sub xml_field_to_data
{
	my( $plugin,$dataset,$field,$xml ) = @_;

	unless( $field->get_property( "multiple" ) )
	{
		return $plugin->xml_field_to_data_single( $dataset,$field,$xml );
	}

	my $data = [];
	my @list = $xml->getChildNodes;
	foreach my $el ( @list )
	{
		next unless EPrints::XML::is_dom( $el, "Element" );
		my $type = $el->getNodeName;
		if( $field->is_type( "subobject" ) )
		{
			my $expect = $field->get_property( "datasetid" );
			if( $type ne $expect )
			{
				$plugin->warning( "<$type> where <$expect> was expected inside <".$field->get_name.">" );
				next;
			}
			my $sub_dataset = $plugin->{session}->get_archive->get_dataset( $expect );
			push @{$data}, $plugin->xml_to_data( $sub_dataset,$el );
			next;
		}

		if( $field->is_type( "file" ) )
		{
			if( $type ne "file" )
			{
				$plugin->warning( "<$type> where <file> was expected inside <".$field->get_name.">" );
				next;
			}
			push @{$data}, $plugin->xml_to_file( $dataset,$el );
			next;
		}

		if( $type ne "item" )
		{
			$plugin->warning( "<$type> where <item> was expected inside <".$field->get_name.">" );
			next;
		}
		push @{$data}, $plugin->xml_field_to_data_single( $dataset,$field,$el );
	}

	return $data;
}

sub xml_field_to_data_single
{
	my( $plugin,$dataset,$field,$xml ) = @_;

	unless( $field->get_property( "hasid" ) )
	{
		return $plugin->xml_field_to_data_noid( $dataset, $field, $xml );
	}

	my %toprocess = $plugin->get_known_nodes( $xml, qw/ id main / );

	my $data = {};
	if( defined $toprocess{id} ) 
	{
		$data->{id} = $plugin->xml_to_text( $toprocess{id} );
	}
	if( defined $toprocess{main} ) 
	{
		$data->{main} = $plugin->xml_field_to_data_noid( $dataset, $field, $toprocess{main} );
	}
	return $data;


}

sub xml_field_to_data_noid
{
	my( $plugin,$dataset,$field,$xml ) = @_;

#	unless( $field->get_property( "multiple" ) )
#	{
#		return $plugin->xml_field_to_data_single( $dataset,$field,$xml );
#	}
	return $plugin->xml_field_to_data_basic( $dataset, $field, $xml );
}

sub xml_field_to_data_basic
{
	my( $plugin,$dataset,$field,$xml ) = @_;

	unless( $field->is_type( "name" ) )
	{
		return $plugin->xml_to_text( $xml );
	}

	my %toprocess = $plugin->get_known_nodes( $xml, qw/ given family lineage honourific / );

	my $data = {};
	foreach my $part ( keys %toprocess )
	{
		$data->{$part} = $plugin->xml_to_text( $toprocess{$part} );
	}
	return $data;
}

sub get_known_nodes
{
	my( $plugin, $xml, @whitelist ) = @_;

	my @list = $xml->getChildNodes;
	my %map = ();
	foreach my $el ( @list )
	{
		next unless EPrints::XML::is_dom( $el, "Element" );
		if( defined $map{$el->getNodeName()} )
		{
			$plugin->warning( "<$el> appears twice in one parent." );
			next;
		}
		$map{$el->getNodeName()} = $el;
	}

	my %toreturn = ();
	foreach my $oknode ( @whitelist ) 
	{
		next unless defined $map{$oknode};
		$toreturn{$oknode} = $map{$oknode};
		delete $map{$oknode};
	}

	foreach my $name ( keys %map )
	{
		$plugin->warning( "Unexpected element: <$name>" );
		$plugin->warning( "Expected <".join("> <",@whitelist).">" );
	}
	return %toreturn;
}



	


	

1;
