package SOAP::ISIWoK::Lite;

use 5.008;

use LWP::UserAgent;
use XML::LibXML;
use XML::LibXML::XPathContext;

use strict;

our $VERSION = '1.02';

our $ISI_ENDPOINT = "http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve";
our $ISI_NS = "http://esti.isinet.com/soap/search";

our $SOAP_SCHEMA = 'http://schemas.xmlsoap.org/soap/envelope/';
our $ISI_SCHEMA = 'http://esti.isinet.com/soap/search';

sub new
{
	my( $class, %self ) = @_;

	$self{ua} ||= LWP::UserAgent->new;

	my $self = bless \%self, ref($class) || $class;

	return $self;
}

sub _search_xml
{
	my( $self, @args ) = @_;

	my $doc = XML::LibXML::Document->new( '1.0', 'UTF-8' );
	my $Envelope = $doc->createElementNS($SOAP_SCHEMA, 'soap:Envelope');
	$doc->setDocumentElement( $Envelope );
	$Envelope->setAttribute(
		'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
	);
	$Envelope->setAttribute(
		'xmlns:soapenc' => 'http://schemas.xmlsoap.org/soap/encoding/'
	);
	$Envelope->setAttribute(
		'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'
	);
	$Envelope->setAttribute(
		'soap:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/'
	);
	my $Body = $doc->createElementNS($SOAP_SCHEMA, 'soap:Body');
	$Envelope->appendChild( $Body );
	my $searchRetrieve = $doc->createElementNS($ISI_SCHEMA, 'searchRetrieve');
	$Body->appendChild( $searchRetrieve );

	for(my $i = 0; $i < $#args; $i+=2)
	{
		my $node = $doc->createElementNS($ISI_SCHEMA, $args[$i]);
		$searchRetrieve->appendChild( $node );
		$node->appendText( $args[$i+1] );
	}

	return $doc;
}

sub search
{
	my( $self, $query, %opts ) = @_;

	my $offset = exists $opts{offset} ? $opts{offset} : 1;
	my $max = exists $opts{max} ? $opts{max} : 10;
	my $database = exists $opts{database} ? $opts{database} : "WOS";
	my $fields = exists $opts{fields} ? $opts{fields} : [qw( times_cited )];
	my $sort = exists $opts{sort} ? $opts{sort} : "Relevance";

	my $doc = $self->_search_xml(
		databaseID => $database,
		query => $query,
		depth => "",
		editions => "",
		'sort' => $sort,
		firstRec => "$offset",
		numRecs => "$max",
		fields => "@$fields",
	);

	my $req = HTTP::Request->new( "POST", $ISI_ENDPOINT, HTTP::Headers->new(
			SOAPAction => '"searchRetrieve"'
		), $doc->toString( 1 ) );

	my $r = $self->{ua}->request( $req );
	if( !$r->is_success )
	{
		Carp::croak( soap_error( $r ) );
	}

	my %response;

	my $response = XML::LibXML->new->parse_string( $r->content );
	my $xpc = XML::LibXML::XPathContext->new( $response->documentElement );
	$xpc->registerNs( soap => $SOAP_SCHEMA );
	$xpc->registerNs( isi => $ISI_SCHEMA );

	foreach my $node ($xpc->findnodes('/soap:Envelope/soap:Body/isi:searchRetrieveResponse/searchRetrieveReturn/*'))
	{
		$response{$node->localName} = $node->textContent;
	}

	if( !$response{records} )
	{
		Carp::croak( $r->content );
	}

	# <records> contains the actual response XML
	my $rdoc = XML::LibXML->new->parse_string( delete $response{records} );
	# set all other responses as attributes on the <records> DOC
	foreach my $key (keys %response)
	{
		$rdoc->documentElement->setAttribute( $key => $response{$key} );
	}

	return $rdoc;
}

sub soap_error
{
	my( $r ) = @_;

	my $doc = eval { XML::LibXML->new->parse_string( $r->content ) };
	if( $@ )
	{
		return $r->status_line . "\n" . $r->content;
	}

	my $response = XML::LibXML->new->parse_string( $r->content );
	my $xpc = XML::LibXML::XPathContext->new( $response->documentElement );
	$xpc->registerNs( soap => $SOAP_SCHEMA );
	$xpc->registerNs( isi => $ISI_SCHEMA );

	my( $faultcode ) = $xpc->findnodes('/soap:Envelope/soap:Body/soap:Fault/faultcode');
	my( $faultstring ) = $xpc->findnodes('/soap:Envelope/soap:Body/soap:Fault/faultstring');

	$faultcode = defined($faultcode) ? $faultcode->textContent : undef;
	$faultstring = defined($faultstring) ? $faultstring->textContent : undef;

	if( $faultcode )
	{
		return "Server reported $faultcode: $faultstring";
	}

	return $r->status_line . "\n" . $r->content;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

SOAP::ISIWoK::Lite - search and query the ISI Web of Knowledge

=head1 SYNOPSIS

  use SOAP::ISIWoK::Lite;

  my $wok = SOAP::ISIWoK::Lite->new();

  my $doc = $wok->search( "AU = (Brody)" );

  # e.g. retrieve next set of records
  $doc = $wok->search( "AU = (Brody)", offset => 10, max => 20 );

  print $doc->toString;

=head1 DESCRIPTION

This module is a lighter version that doesn't use L<SOAP::Lite>.

=head1 SEE ALSO

L<SOAP::ISIWoK>, L<SOAP::Lite>, http://www.isiknowledge.com/

=head1 AUTHOR

Timothy D Brody, E<lt>tdb2@ecs.soton.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Tim D Brody

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
