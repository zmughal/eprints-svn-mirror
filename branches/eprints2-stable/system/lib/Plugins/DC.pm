
package EPrints::Plugins::DC;
use strict;

EPrints::Plugins::register( 'convert/obj.eprint/dc.struct/default', \&eprint_to_oai_dc );
EPrints::Plugins::register( 'convert/obj.eprint/dc.struct/oai', \&eprint_to_oai_dc );
EPrints::Plugins::register( 'convert/dc.struct/xml.oai_dc/default', \&dc_to_xml_oai_dc );
EPrints::Plugins::register( 'convert/dc.struct/xml.dc/default', \&dc_to_xml );

#####################################
# DC Functions
#####################################

sub eprint_to_oai_dc
{
	my( $eprint, $session ) = @_;

	my @dcdata = ();
	push @dcdata, [ "title", $eprint->get_value( "title" ) ]; 
	
	# grab the creators without the ID parts so if the site admin
	# sets or unsets creators to having and ID part it will make
	# no difference to this bit.

	my $creators = $eprint->get_value( "creators", 1 );
	if( defined $creators )
	{
		foreach my $creator ( @{$creators} )
		{
			push @dcdata, [ "creator", EPrints::Utils::make_name_string( $creator ) ];
		}
	}

	my $subjectid;
	foreach $subjectid ( @{$eprint->get_value( "subjects" )} )
	{
		my $subject = EPrints::Subject->new( $session, $subjectid );
		# avoid problems with bad subjects
		next unless( defined $subject ); 
		push @dcdata, [ "subject", EPrints::Utils::tree_to_utf8( $subject->render_description() ) ];
	}

	push @dcdata, [ "description", $eprint->get_value( "abstract" ) ]; 

	push @dcdata, [ "publisher", $eprint->get_value( "publisher" ) ]; 

	my $editors = $eprint->get_value( "editors", 1 );
	if( defined $editors )
	{
		foreach my $editor ( @{$editors} )
		{
			push @dcdata, [ "contributor", EPrints::Utils::make_name_string( $editor ) ];
		}
	}

	## Date for discovery. For a month/day we don't have, assume 01.
	my $date = $eprint->get_value( "date_effective" );
	$date =~ s/(-0+)+$//;
	push @dcdata, [ "date", $date ];


	my $ds = $eprint->get_dataset();
	push @dcdata, [ "type", $ds->get_type_name( $session, $eprint->get_value( "type" ) ) ];
	
	my $ref = "NonPeerReviewed";
	if( $eprint->is_set( "refereed" ) && $eprint->get_value( "refereed" ) eq "TRUE" )
	{
		$ref = "PeerReviewed";
	}
	push @dcdata, [ "type", $ref ];


	# The identifier is the URL of the abstract page.
	# possibly this should be the OAI ID, or both.
	push @dcdata, [ "identifier", $eprint->get_url() ];


	my @documents = $eprint->get_all_documents();
	my $mimetypes = $session->get_archive->get_conf( "oai", "mime_types" );
	foreach( @documents )
	{
		my $format = $mimetypes->{$_->get_value("format")};
		$format = "application/octet-stream" unless defined $format;
		push @dcdata, [ "format", $format ];
		push @dcdata, [ "relation", $_->get_url() ];
	}

	if( $eprint->is_set( "official_url" ) )
	{
		push @dcdata, [ "relation", $eprint->get_value( "official_url" ) ];
	}
	
	# dc.language not handled yet.
	# dc.source not handled yet.
	# dc.coverage not handled yet.
	# dc.rights not handled yet.

	return \@dcdata;
}

sub dc_to_xml_oai_dc
{
	my( $dcdata, $session ) = @_;

	my $oai_dc = $session->make_element(
		"oai_dc:dc",
		"xmlns:oai_dc" => "http://www.openarchives.org/OAI/2.0/oai_dc/",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => "http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd" );

	$oai_dc->appendChild( 
		EPrints::Plugins::call( 
			'convert/dc.struct/xml.dc/',
			$dcdata,
			$session ) );

	return $oai_dc;
}

sub dc_to_xml
{
	my( $dcdata, $session ) = @_;

	my $f = $session->make_doc_fragment;
	# turn the list of pairs into XML blocks (indented by 8) and add them
	# them to the DC element.
	foreach( @{$dcdata} )
	{
		# produces <dc:key xmlns:dc=>"blah">value</key>
		my $dcel = $session->render_data_element( 
			8, 
			"dc:".$_->[0], 
			$_->[1],
			"xmlns:dc" => "http://purl.org/dc/elements/1.1/" );
		$f->appendChild( $dcel );
	}

	return $f;
}

1;
