package EPrints::Plugin::Export::XML;

use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "EP3 XML";
	$self->{accept} = [ 'list/*', 'dataobj/*' ];
	$self->{visible} = "all";
	$self->{xmlns} = "http://eprints.org/ep2/data/2.0";

	return $self;
}





sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	my $toplevel = $type."s";
	my $namespace = EPrints::XML::namespace( "data", "2" );
	
	my $r = [];

	my $part;
	$part = '<?xml version="1.0" encoding="utf-8" ?>'."\n<$toplevel xmlns=\"$namespace\">\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	$opts{list}->map( sub {
		my( $handle, $dataset, $item ) = @_;

		my $part = $plugin->output_dataobj( $item, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	} );

	$part= "</$toplevel>\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}


	if( defined $opts{fh} )
	{
		return;
	}

	return join( '', @{$r} );
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $itemtype = $dataobj->get_dataset->confid;

	my $xml = $plugin->xml_dataobj( $dataobj );

	EPrints::XML::tidy( $xml, {}, 1 );

	return "  " . EPrints::XML::to_string( $xml ) . "\n";
}

sub xml_dataobj
{
	my( $plugin, $dataobj ) = @_;

	return $dataobj->to_xml;
}

1;
