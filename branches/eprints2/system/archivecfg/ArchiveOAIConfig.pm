######################################################################
#
#  OAI Configutation for Archive.
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
#
######################################################################

use EPrints::OpenArchives;

sub get_oai_conf { my( $perlurl ) = @_; my $oai={};


##########################################################################
# OAI-PMH 2.0 
#
# 2.0 requires slightly different schemas and XML to v1.1
##########################################################################

# Site specific **UNIQUE** archive identifier.
# See http://www.openarchives.org/ for existing identifiers.
# This may be different for OAI v2.0
# It should contain a dot (.) which v1.1 can't. This means you can use your
# sites domain as (part of) the base ID - which is pretty darn unique.

# IMPORTANT: Do not register an archive with the default archive_id! 
$oai->{v2}->{archive_id} = "generic.eprints.org";

# Exported metadata formats. The hash should map format ids to namespaces.
$oai->{v2}->{metadata_namespaces} =
{
	"oai_dc"    =>  "http://www.openarchives.org/OAI/2.0/oai_dc/",
	"didl"      =>  "urn:mpeg:mpeg21:2002:02-DIDL-NS",
};

# Exported metadata formats. The hash should map format ids to schemas.
$oai->{v2}->{metadata_schemas} =
{
	"oai_dc"    =>  "http://www.openarchives.org/OAI/2.0/oai_dc.xsd",
	"didl"      =>  "http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/did/didmodel.xsd",
};

# Each supported metadata format will need a function to turn
# the eprint record into XML representing that format. The function(s)
# are defined later in this file.
$oai->{v2}->{metadata_functions} = 
{
	"oai_dc"    =>  \&make_metadata_oai_dc_oai2,
	"didl"    =>  \&eprint_to_didl,
};

# Base URL of OAI 2.0
$oai->{v2}->{base_url} = $perlurl."/oai2";

$oai->{v2}->{sample_identifier} = EPrints::OpenArchives::to_oai_identifier(
	$oai->{v2}->{archive_id},
	"23" );

##########################################################################
# GENERAL OAI CONFIGURATION
# 
# This applies to all versions of OAI.
##########################################################################



# Set Configuration
# Rather than harvest the entire archive, a harvester may harvest only
# one set. Sets are usually subjects, but can be anything you like and are
# defined in the same manner as "browse_views". Only id, allow_null, fields
# are used.
$oai->{sets} = [
#	{ id=>"year", allow_null=>1, fields=>"date_effective" },
#	{ id=>"person", allow_null=>0, fields=>"creators.id/editors.id" },
	{ id=>"status", allow_null=>0, fields=>"ispublished" },
	{ id=>"subjects", allow_null=>0, fields=>"subjects" }
];

# Filter OAI export. If you want to stop certain records being exported
# you can add filters here. These work the same as for a search filter.

$oai->{filters} = [

#	{ meta_fields => [ "creators" ], value=>"harnad" }
# Example: don't export any OAI records from before 2003.
#	{ meta_fields => [ "date-effective" ], value=>"2003-" }
];

# Number of results to display on a single search results page

# Information for "Identify" responses.

# "content" : Text and/or a URL linking to text describing the content
# of the repository.  It would be appropriate to indicate the language(s)
# of the metadata/data in the repository.

$oai->{content}->{"text"} = latin1( <<END );
OAI Site description has not been configured.
END
$oai->{content}->{"url"} = undef;

# "metadataPolicy" : Text and/or a URL linking to text describing policies
# relating to the use of metadata harvested through the OAI interface.

# metadataPolicy{"text"} and/or metadataPolicy{"url"} 
# MUST be defined to comply to OAI.

$oai->{metadata_policy}->{"text"} = latin1( <<END );
No metadata policy defined. 
This server has not yet been fully configured.
Please contact the admin for more information, but if in doubt assume that
NO rights at all are granted to this data.
END
$oai->{metadata_policy}->{"url"} = undef;

# "dataPolicy" : Text and/or a URL linking to text describing policies
# relating to the data held in the repository.  This may also describe
# policies regarding downloading data (full-content).

# dataPolicy{"text"} and/or dataPolicy{"url"} 
# MUST be defined to comply to OAI.

$oai->{data_policy}->{"text"} = latin1( <<END );
No data policy defined. 
This server has not yet been fully configured.
Please contact the admin for more information, but if in doubt assume that
NO rights at all are granted to this data.
END
$oai->{data_policy}->{"url"} = undef;

# "submissionPolicy" : Text and/or a URL linking to text describing
# policies relating to the submission of content to the repository (or
# other accession mechanisms).

$oai->{submission_policy}->{"text"} = latin1( <<END );
No submission-data policy defined. 
This server has not yet been fully configured.
END
$oai->{submission_policy}->{"url"} = undef;

# "comment" : Text and/or a URL linking to text describing anything else
# that is not covered by the fields above. It would be appropriate to
# include additional contact details (additional to the adminEmail that
# is part of the response to the Identify request).

# An array of comments to be returned. May be empty.

$oai->{comments} = [ 
	latin1( "This system is running eprints server software (".
		EPrints::Config::get( "version" ).") developed at the ".
		"University of Southampton. For more information see ".
		"http://www.eprints.org/" ) 
];

$oai->{mime_types} = {
	pdf => "application/pdf",
	ps => "application/postscript",
	html => "text/html",
	other => "application/octet-stream",
	ascii => "text/plain"
};

return $oai; }

######################################################################
#
# $domfragment = make_metadata_oai_dc( $eprint, $session )
#
######################################################################
# $eprint
# - the EPrints::EPrint to be converted
# $session
# - the current EPrints::Session
#
# returns: ( $xhtmlfragment, $title )
# - a DOM tree containing the metadata from $eprint in oai_dc - 
# unqualified dublin-core.
######################################################################
# This subroutine takes an eprint object and renders the XML DOM
# to export as the oai_dc default format in OAI.
#
# If supporting other metadata formats, it's probably best to start
# by copying this method, and modifying it.
#
# It uses a seperate function to actually map to the DC, this is
# so it can be called by the metadata_links function in the 
# ArchiveRenderConfig.pm - saves having to map it to unqualified
# DC in two places.
#
######################################################################

sub make_metadata_oai_dc
{
	my( $eprint, $session ) = @_;

	my @dcdata = &eprint_to_unqualified_dc( $eprint, $session );

	my $archive = $session->get_archive();

	# return undef here, if you don't support this metadata format for 
	# this record.  ( But this is "oai_dc" so we have to support it! )

	# Get the namespace & schema.
	# We could hard code them here, but getting the values from our
	# own configuration should avoid getting our knickers in a twist.
	
	my $oai_conf = $archive->get_conf( "oai" );
	my $namespace = $oai_conf->{metadata_namespaces}->{oai_dc};
	my $schema = $oai_conf->{metadata_schemas}->{oai_dc};

	my $dc = $session->make_element(
		"dc",
		"xmlns" => "http://www.openarchives.org/OAI/2.0/oai_dc/",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" =>
	 "http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd" );

	# turn the list of pairs into XML blocks (indented by 8) and add them
	# them to the DC element.
	foreach( @dcdata )
	{
		$dc->appendChild(  $session->render_data_element( 8, $_->[0], $_->[1] ) );
		# produces <key>value</key>
	}

	return $dc;
}

######################################################################
#
# $domfragment = make_metadata_oai_dc_oai2( $eprint, $session )
#
######################################################################
#
# Identical to make_metadata_oai_dc except with a few changes
# for the new version of the protocol.
#
######################################################################

sub make_metadata_oai_dc_oai2
{
	my( $eprint, $session ) = @_;

	my @dcdata = &eprint_to_unqualified_dc( $eprint, $session );

	my $archive = $session->get_archive();

	# Get the namespace & schema.
	# We could hard code them here, but getting the values from our
	# own configuration should avoid getting our knickers in a twist.
	
	my $oai_conf = $archive->get_conf( "oai", "v2" );
	my $namespace = $oai_conf->{metadata_namespaces}->{oai_dc};
	my $schema = $oai_conf->{metadata_schemas}->{oai_dc};

	my $oai_dc = $session->make_element(
		"oai_dc:dc",
		"xmlns:oai_dc" => $namespace,
		"xmlns:dc" => "http://purl.org/dc/elements/1.1/",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => $namespace." ".$schema );

	# turn the list of pairs into XML blocks (indented by 8) and add them
	# them to the DC element.
	foreach( @dcdata )
	{
		$oai_dc->appendChild(  $session->render_data_element( 8, "dc:".$_->[0], $_->[1] ) );
		# produces <key>value</key>
	}

	return $oai_dc;
}

######################################################################
#
# $dc = eprint_to_unqualified_dc( $eprint, $session )
#
######################################################################
# $eprint
# - the EPrints::EPrint to be converted
# $session
# - the current EPrints::Session
#
# returns: array of array refs. 
# - the array refs are 2 item arrays containing dc fieldname and value
# eg. [ "title", "Bacon and Toast Experiments" ]
######################################################################
# This function is called by make_metadata_oai_dc and metadata_links.
#
# It maps an EPrint object into unqualified dublincore. 
#
# It is not called directly from the EPrints system.
#
######################################################################

sub eprint_to_unqualified_dc
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
	if( defined $date )
	{
		$date =~ s/(-0+)+$//;
		push @dcdata, [ "date", $date ];
	}


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

	return @dcdata;
}

sub eprint_to_didl
{
	my( $eprint, $session ) = @_;

	my $didl = $session->make_element( 
		"didl:DIDL",
		"xmlns:didl"=>"urn:mpeg:mpeg21:2002:02-DIDL-NS",
		"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation"=>"urn:mpeg:mpeg21:2002:02-DIDL-NS 
			 http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/did/didmodel.xsd" );
	my $item = $session->make_element( "didl:Item" );
	$didl->appendChild( $item );


	my $d1 = $session->make_element( "didl:Descriptior" );
	my $s1 = $session->make_element( "didl:Statement", mimeType=>"application/xml; charset=utf-8" );
	my $ident = $session->make_element( 
		"dii:Identifier",
		"xmlns:dii"=>"urn:mpeg:mpeg21:2002:01-DII-NS",
		"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation"=>"urn:mpeg:mpeg21:2002:01-DII-NS
		 	http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/dii/dii.xsd" );
	$ident->appendChild( $session->make_text( $eprint->get_url ) );
	$s1->appendChild( $ident );
	$d1->appendChild( $s1 );
	$item->appendChild( $d1 );


	my $d2 = $session->make_element( "didl:Descriptior" );
	my $s2 = $session->make_element( "didl:Statement", mimeType=>"application/xml; charset=utf-8" );
	$s2->appendChild( make_metadata_oai_dc_oai2( $eprint, $session ) );
	$d2->appendChild( $s2 );
	$item->appendChild( $d2 );

	my $mimetypes = $session->get_archive->get_conf( "oai", "mime_types" );
	foreach my $doc ( $eprint->get_all_documents )
	{
		my $comp = $session->make_element( "didl:Component" );
		$item->appendChild( $comp );


		my $d3 = $session->make_element( "didl:Descriptior" );
		my $s3 = $session->make_element( "didl:Statement", mimeType=>"application/xml; charset=utf-8" );
		my $i3 = $session->make_element( 
			"dii:Identifier",
			"xmlns:dii"=>"urn:mpeg:mpeg21:2002:01-DII-NS",
			"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
			"xsi:schemaLocation"=>"urn:mpeg:mpeg21:2002:01-DII-NS
		 	    http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/dii/dii.xsd" );
		$i3->appendChild( $session->make_text( $doc->get_baseurl ) );
		$s3->appendChild( $i3 );
		$d3->appendChild( $s3 );
		$comp->appendChild( $d3 );

		my %files = $doc->files;
		foreach my $file ( keys %files )
		{
			my $res = $session->make_element( "didl:Resource", 
					mimeType=>$format,
					ref=>$doc->get_url( $file ) );
			$comp->appendChild( $res );
		}
	}

	
#    <didl:Resource mimeType="application/pdf" ref="http://amsacta.cib.unibo.it/archive/
 #	      00000014/01/GaAs_1_Vorobiev.pdf"/>
	return $didl;
}


my $x =<<END;
corrected.
	 <didl:DIDL
		 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
		 xmlns:didl="urn:mpeg:mpeg21:2002:02-DIDL-NS"
		 xsi:schemaLocation="urn:mpeg:mpeg21:2002:02-DIDL-NS
		 	http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/did/didmodel.xsd">
	 <dii:Identifier
		 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
		 xsi:schemaLocation="urn:mpeg:mpeg21:2002:01-DII-NS
		 http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/dii/dii.xsd"
		 	xmlns:dii="urn:mpeg:mpeg21:2002:01-DII-NS">http://ep2stable.ecs.soton.ac.uk/45/</dii:Identifier>





<didl:DIDL  xmlns:didl="urn:mpeg:mpeg21:2002:02-DIDL-NS"
		  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
		  xsi:schemaLocation="urn:mpeg:mpeg21:2002:02-DIDL-NS
		  http://purl.lanl.gov/STB-RL/schemas/2004-11/DIDL.xsd">
<didl:Item>
      <didl:Descriptor>
	    <didl:Statement mimeType="application/xml; charset=utf-8">
		  <dii:Identifier
			      xmlns:dii="urn:mpeg:mpeg21:2002:01-DII-NS"
			      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
			      xsi:schemaLocation="urn:mpeg:mpeg21:2002:01-DII-NS
			      http://purl.lanl.gov/STB-RL/schemas/2003-09/DII.xsd">
		      http://amsacta.cib.unibo.it/archive/00000014/
		  </dii:Identifier>
	    </didl:Statement>
      </didl:Descriptor>
      <didl:Descriptor>
	    <didl:Statement mimeType="application/xml; charset=utf-8">
		 <oai_dc:dc xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
		       xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/
		       http://www.openarchives.org/OAI/2.0/oai_dc.xsd"
		       xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
		       xmlns:dc="http://purl.org/dc/elements/1.1/">
		  <dc:title>A Simple Parallel-Plate Resonator Technique for Microwave.
		      Characterization of Thin Resistive Films
		  </dc:title>
		  <dc:creator>Vorobiev, A.</dc:creator>
		  <dc:subject>ING-INF/01 Elettronica</dc:subject>
		  <dc:description>A parallel-plate resonator method is proposed for
		      non-destructive characterisation of resistive films used in microwave
		      integrated circuits. A slot made in one ...
		  </dc:description>
		  <dc:publisher>Microwave engineering Europe</dc:publisher>
		  <dc:date>2002</dc:date>
		  <dc:type>Documento relativo ad una Conferenza o altro Evento</dc:type>
		  <dc:type>PeerReviewed</dc:type>
		  <dc:identifier>
		      http://amsacta.cib.unibo.it/archive/00000014/
		  </dc:identifier>
		  <dc:format>application/pdf</dc:format>
		 </oai_dc:dc>
	    </didl:Statement>
      </didl:Descriptor>
      <didl:Component>
	    <didl:Resource mimeType="application/pdf" ref="http://amsacta.cib.unibo.it/archive/
	       00000014/01/GaAs_1_Vorobiev.pdf"/>
      </didl:Component>
</didl:Item>
</didl:DIDL>
END


1;
