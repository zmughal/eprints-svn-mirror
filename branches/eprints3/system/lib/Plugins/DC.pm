
package EPrints::Plugins::DC;
use strict;
use EPrints::Session;

EPrints::Plugins::register( 'convert/obj.eprint/dc.struct/default', \&eprint_to_oai_dc );
EPrints::Plugins::register( 'convert/obj.eprint/dc.struct/oai', \&eprint_to_oai_dc );
EPrints::Plugins::register( 'convert/dc.struct/xml.oai_dc/default', \&dc_to_xml_oai_dc );
EPrints::Plugins::register( 'convert/dc.struct/xml.dc/default', \&dc_to_xml );

#####################################
# DC Functions
#####################################

sub eprint_to_oai_dc
{
	my( $eprint ) = @_;

	return &ARCHIVE->call( 'eprint_to_unqualified_dc', $eprint, &SESSION );
}

sub dc_to_xml_oai_dc
{
	my( $dcdata ) = @_;

	my $oai_dc = &SESSION->make_element(
		"oai_dc:dc",
		"xmlns:oai_dc" => "http://www.openarchives.org/OAI/2.0/oai_dc/",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => "http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd" );

	$oai_dc->appendChild( 
		&ARCHIVE->plugin(
			'convert/dc.struct/xml.dc/',
			$dcdata ) );

	return $oai_dc;
}

sub dc_to_xml
{
	my( $dcdata ) = @_;

	my $f = &SESSION->make_doc_fragment;
	# turn the list of pairs into XML blocks (indented by 8) and add them
	# them to the DC element.
	foreach( @{$dcdata} )
	{
		# produces <dc:key xmlns:dc=>"blah">value</key>
		my $dcel = &SESSION->render_data_element( 
			8, 
			"dc:".$_->[0], 
			$_->[1],
			"xmlns:dc" => "http://purl.org/dc/elements/1.1/" );
		$f->appendChild( $dcel );
	}

	return $f;
}

1;
