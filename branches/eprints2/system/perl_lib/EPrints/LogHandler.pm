######################################################################
#
# EPrints::LogHandler
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

EPrints::LogHandler - Main handler for Apache log events

=head1 CONFIGURATION

To enable the LogHandler add to your ArchiveConfig:

   $c->{loghandler}->{enable} = 1;

=head1 METHODS

=over 4

=cut

package EPrints::LogHandler;

use strict;
use warnings;

use Geo::IP::PurePerl;
our $GEOIP_DB = Geo::IP::PurePerl->new( GEOIP_STANDARD );

#use Apache::RequestRec;
#use Apache::Connection;

sub handler
{
	my( $r ) = @_;

	my $session = new EPrints::Session;
	return EPrints::AnApache::DECLINED unless defined $session;

	my $repository = $session->get_repository;

	my $c = $r->connection;
	my $ip = $c->remote_ip;
	my $doc = $r->filename;

	my $rft = $r->uri;
	my $rfr = $r->headers_in->{ "Referer" };
	my $svc = '';

	# Ignore stylesheets
	if( $rft =~ /\.css$/ )
	{
		return EPrints::AnApache::OK;
	}
	
	# Track requests to external links
	if( $doc and $doc =~ /redirect$/ )
	{
	}
	# translate referent to an eprint id
	elsif( defined(my $eprintid = uri_to_eprintid( $session, $r->uri )) )
	{
		$rft = $eprintid;
		if( defined(my $docid = uri_to_docid( $session, $eprintid, $r->uri )) )
		{
			$doc = $docid;
		}
	}
	
	# referrer is HTTP Referer
	if( $rfr )
	{
		if( $rfr !~ /^https?:/ )
		{
			$rfr = '';
		}
		elsif( defined(my $eprintid = uri_to_eprintid( $session, $r->uri )) )
		{
			$rfr = $eprintid;
		}
	}

	my $data = EPrints::DataObj::Access->get_defaults(
		$session,
		{
			requester_id => 'urn:ip:' . $ip,
			requester_user_agent => $r->headers_in->{ "User-Agent" },
			requester_country => $GEOIP_DB->country_code_by_addr( $ip ),
			requester_institution => undef,
			referring_entity_id => $rfr,
			service_type_id => $svc,
			referent_id => $rft,
			referent_docid => $doc,
		});

	EPrints::DataObj::Access->create_from_data(
		$session,
		$data,
		$session->get_repository->get_dataset( "accesslog" )
	);
	
	return EPrints::AnApache::OK;
}

=item $id = EPrints::LogHandler::uri_to_eprintid( $session, $uri )

Returns the eprint id that $uri corresponds to, or undef.

=cut

sub uri_to_eprintid
{
	my( $session, $uri ) = @_;

	# uri is something like /xxxxxx/?
	if( $uri =~ m#/(\d+)/# )
	{
		return 'info:oai:' . $session->get_repository->get_id . ':' . 1 * $1;
	}
	
	undef;
}

=item $id = EPrints::LogHandler::uri_to_docid( $session, $eprintid, $uri )

Returns the docid that $uri corresponds to (given the $eprintid), or undef.

=cut

sub uri_to_docid
{
	my( $session, $eprintid, $uri ) = @_;

	if( $uri =~ m#/(\d+)/(\d+)/# )
	{
		return $eprintid . '#' . 1 * $2;
	}

	undef;
}

1;
