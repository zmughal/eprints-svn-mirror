package EPrints::Misc;

use EPrints::Field;
use EPrints::XML;
use EPrints::Session;
use Carp;


my $archives = {};

sub getArchive
{
	my( $archive_id ) = @_;

	if( !defined $archives->{$archive_id} )
	{
		my $loaded = EPrints::Archive->new( $archive_id );
		$archives->{$archive_id} = $loaded;
	}
	
	return $archives->{$archive_id};
}


sub ok_id_str
{
	my( $string ) = @_;

	return( $string =~ m/^[a-z][_a-z0-9]*$/ );
}

sub xml_to_field
{
	my( $xml ) = @_;

	# should have been passed a <field> element

	my $name = $xml->getAttribute( 'name' );

	unless( ok_id_str( $name ) )
	{
		die "bad id string name in field conf: $name";
	}

	my $type_node;
	foreach my $tag ( $xml->getChildNodes )
	{
		next unless( $tag->getNodeName eq 'type' );
		$type_node = $tag;
		last;
	}
	unless( defined $type_node )
	{
		die "field $name does not have a type";
	}

	my $type = xml_to_type( $type_node );

	return EPrints::Field->new( $name, $type );
}

sub xml_to_dataset
{
	my( $xml ) = @_;

	my $name = $xml->getAttribute( 'name' );
	my $type_xml = ($xml->getElementsByTagName( "type" ))[0];


	my $type_name = $type_xml->getAttribute( 'class' );

	unless( ok_id_str( $type_name ) )
	{
		die "bad id string class in (dataset) type conf: $type_name";
	}

	my %p = _xml_to_type_options( $type_xml );
	$p{"class"} = $type_name;
	$p{"name"} = $name;
	return EPrints::Type::create( %p );
}

sub xml_to_type
{
	my( $xml ) = @_;

	# should have been passed a <type> element

	my $name = $xml->getAttribute( 'class' );

	unless( ok_id_str( $name ) )
	{
print $xml->toString."!\n";
		die "bad id string class in type conf: $name";
	}

	my %p = _xml_to_type_options( $xml );
	$p{"class"} = $name;
	return EPrints::Type::create( %p );
}

sub _xml_to_type_options
{
	my( $xml ) = @_;

	my %p;

	$p{"types"} = [];
	$p{"fields"} = [];
	foreach my $tag ( $xml->getChildNodes )
	{
		my $tn = $tag->getNodeName;
		if( $tn eq 'type' )
		{
			push @{$p{"types"}}, xml_to_type( $tag );
		}
		if( $tn eq 'field' )
		{
			push @{$p{"fields"}}, xml_to_field( $tag );
		}
	}

	return %p;
}



1;
