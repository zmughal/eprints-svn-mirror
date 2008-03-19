package EPrints::Plugin::Export::XML_Schema;

use Unicode::String qw( utf8 );

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "XML Schema";
	$self->{accept} = [ 'list/metafield' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xsd";
	$self->{mimetype} = "text/xml; charset=utf-8";
	
	return $self;
}


sub output_list
{
	my( $plugin, %opts ) = @_;

	my $session = $plugin->{session};

	my @records = $opts{list}->get_records;

	my %elements;
	my %types;

	for(@records)
	{
		my $field = $_->get_field( $session );

		my $datasetid = $_->get_value( "mfdatasetid" );
		my $element = $field->render_xml_schema( $session );
		push @{$elements{$datasetid}}, $element;

		foreach my $sub_field ($field, @{$field->{fields_cache}||[]})
		{
			my $type = $sub_field->get_xml_schema_type();
			if( $type !~ /^xs:/ )
			{
				$types{$type} ||= $sub_field->render_xml_schema_type( $session );
			}
		}
	}

	my $schema = $session->make_element( "xs:schema",
		"targetNamespace" => "http://eprints.org/ep2/data/2.0",
		"xmlns" => "http://eprints.org/ep2/data/2.0",
		"xmlns:xs" => "http://www.w3.org/2001/XMLSchema",
		"elementFormDefault" => "qualified",
	);

	foreach my $datasetid (sort keys %elements)
	{
		# root element for this dataset
		my $root = $session->make_element( "xs:element", name => "${datasetid}s" );
		$schema->appendChild( $root );
		my $complexType = $session->make_element( "xs:complexType" );
		$root->appendChild( $complexType );
		my $choice = $session->make_element( "xs:choice", minOccurs => "0", maxOccurs => "unbounded" );
		$complexType->appendChild( $choice );
		my $element = $session->make_element( "xs:element", name => $datasetid, type => "dataset_$datasetid" );
		$choice->appendChild( $element );

		# dataset schema
		$complexType = $session->make_element( "xs:complexType", name => "dataset_$datasetid" );
		$schema->appendChild( $complexType );

		# dataset fields
		my $datasetAll = $session->make_element( "xs:all", "minOccurs" => 0 );
		$complexType->appendChild( $datasetAll );
		foreach my $field_schemas (@{$elements{$datasetid}})
		{
			$datasetAll->appendChild( $field_schemas );
		}

		# dataset "id" attribute (attributes follow elements in schema)
		my $id = $session->make_element( "xs:attribute", name => "id", type => "xs:anyURI" );
		$complexType->appendChild( $id );
	}

	foreach my $type (sort keys %types)
	{
		$schema->appendChild( $types{$type} );
	}

	my $xml = <<EOX;
<?xml version="1.0"?>

EOX
	$xml .= $schema->toString(1);
	$xml .= "\n";

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $xml;
		return;
	}

	return $xml;
}

1;
