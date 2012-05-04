package EPrints::Plugin::Import::OAIPMH::OAI_DC;

use strict;
use warnings;

use EPrints::Plugin::Import::OAIPMH;
our @ISA = qw/ EPrints::Plugin::Import::OAIPMH /;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = 'OAI-PMH Importer - OAI DC';
	$self->{visible} = "none";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	# this will be a parameter when the target URL is harvested
	$self->{metadataPrefix} = 'oai_dc';

	return $self;
}

sub xml_to_epdata
{
	my( $self, $xml ) = @_;

	my $epdata = {};

	# Basic examples
	
	# Single value fields:
	my $title = $self->get_node_content( $xml, 'title' );
	$epdata->{title} = $title if( defined $title );

	my $abstract = $self->get_node_content( $xml, 'description' );
	$epdata->{abstract} = $abstract if( defined $abstract );

	# Multiple values fields - the method returns an ARRAY REF (ie array pointer)
	my $languages = $self->get_node_content_multiple( $xml, 'language' );

	# etc.

	return $epdata;
}

sub import_documents
{
        my( $self, $eprint, $xml ) = @_;

	# Stub that gives you a chance to download a file and to attach it to the eprint object
	# Might not be relevant to the Metadata schema (oai_dc) you're using...

	# get the URL to the document 
	# my $url = $self->get_node_content( $xml, 'official_url' );
	#
	# my $doc = $self->create_document( $url, $eprint );
	#
	# that's it, the file was hopefully downloaded and the new doc created
	#

}


1;


