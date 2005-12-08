package EPrints::Plugin::Output::OldXML;

# eprint needs magic documents field

# documents needs magic files field

use Unicode::String qw( utf8 );

use EPrints::Plugin::Output;

@ISA = ( "EPrints::Plugin::Output" );

use strict;

# The utf8() method is called to ensure that
# any broken characters are removed. There should
# not be any broken characters, but better to be
# sure.

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "output/oldxml";
	$d{name} = "XML (eprints 2.3 style)";
	$d{accept} = [ 'list/*', 'dataobj/*' ];
	$d{visible} = "";
	$d{suffix} = ".xml";
	$d{mimetype} = "text/xml";

	return %d;
}





sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	my $toplevel = $type."s";

	my $r = [];

	my $part;
	$part = '<?xml version="1.0" encoding="utf-8" ?><eprintsdata xmlns="http://eprints.org/ep2/data">'."\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	foreach my $dataobj ( $opts{list}->get_records )
	{
		$part = $plugin->output_dataobj( $dataobj, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	}	

	$part= "</eprintsdata>\n";
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

	return EPrints::XML::to_string( $xml );
}

sub xml_dataobj
{
	my( $plugin, $dataobj ) = @_;

	return $dataobj->to_xml( version=>1, no_xmlns=>1 );
}

1;
