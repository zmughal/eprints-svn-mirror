package SOAP::ISIWoK;

use Carp;
use SOAP::Lite
#	+trace => "all"
;
use XML::LibXML;

use 5.008;
use strict;

our $VERSION = '1.02';

our $ISI_ENDPOINT = "http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve";
our $ISI_NS = "http://esti.isinet.com/soap/search";

sub new
{
	my( $class, %self ) = @_;

	my $self = bless \%self, ref($class) || $class;

	return $self;
}

sub _soap
{
	my( $self ) = @_;

	my $soap = SOAP::Lite->new();
	$soap->proxy( $ISI_ENDPOINT );

# don't include namespace in actions
	$soap->on_action(sub { qq("$_[1]") });
#$soap->on_fault(sub { print STDERR "Error: $_[1]" });

# don't guess auto types
	$soap->autotype(0);
# send pretty-printed XML
	$soap->readable(1);
# put everything in the ISI namespace
	$soap->default_ns($ISI_NS);

	return $soap;
}

sub search
{
	my( $self, $query, %opts ) = @_;

	my $offset = exists $opts{offset} ? $opts{offset} : 1;
	my $max = exists $opts{max} ? $opts{max} : 10;
	my $database = exists $opts{database} ? $opts{database} : "WOS";
	my $fields = exists $opts{fields} ? $opts{fields} : [qw( times_cited )];

	my $soap = $self->_soap();

	# ISI requires every argument be included, even if it's blank
	my $som = $soap->call("searchRetrieve",
			SOAP::Data->name("databaseID")->value($database),
			SOAP::Data->name("query")->value($query),
			# depth is the time period
			SOAP::Data->name("depth")->value(""),
			# editions is SCI, SSCI etc.
			SOAP::Data->name("editions")->value(""),
			# sort by descending relevance
			SOAP::Data->name("sort")->value("Relevance"),
			# start returning records at 1
			SOAP::Data->name("firstRec")->value("$offset"),
			# return upto 10 records
			SOAP::Data->name("numRecs")->value("$max"),
			# NOTE: if no fields are specified all are returned, times_cited is
			# an option
			SOAP::Data->name("fields")->value(join(" ", @$fields)),
		);
	# something went wrong
	if( $som->fault )
	{
		Carp::croak "ISI responded with error: " . $som->fault->{ faultstring };
	}

	my $result = $som->result;

	my $total = $result->{"recordsFound"};

	my $doc = XML::LibXML->new->parse_string( $result->{records} );
	my $records = $doc->documentElement;
	$records->setAttribute( recordsFound => $total );

	return $doc;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

SOAP::ISIWoK - search and query the ISI Web of Knowledge

=head1 SYNOPSIS

  use SOAP::ISIWoK;

  my $wok = SOAP::ISIWoK->new();

  my $results = $wok->search( "AU = (Brody)" );
  my $results = $wok->search( "AU = (Brody)", offset => 10, max => 20 );

  print $results->[0]->{title};

=head1 DESCRIPTION

This module is a thin wrapper for the ISI Web of Knowledge SOAP interface.

=head1 ISI QUERY FORMAT

	AU = (Brody) and TI = (citation impact)

A search query consists of I<index> = I<terms> where I<index> is one of the indexes listed below. I<terms> is one or more terms in double quotes (") or parentheses ('(' and ')').

Multiple operands can be joined using logical operators:

=over 4

=item same

Results in all records in which both operands are found together in the same sentence. A sentence is a period delimited string. A field that does not contain period delimited strings is treated as a single sentence. If a 'same' operator joins two query expressions, then both query expressions must have the same index.

=item not

Results in all records represented in the left operand but not the right operand.

=item and

Results in all records represented in the both the left operand and the right operand.

=item or

Results in all records represented in either or both the left operand and the right operand.

=back

=head2 Search Indexes

	AD	Address
	AU	Author
	CA	Cited Author
	CI	City
	CT	Conference
	CU	Country
	CW	Cited Work
	CY	Cited Year
	DT	Document Type
	GP	Group Author
	LA	Language
	OG	Organization
	PS	Province/State
	PY	Pub Year
	SA	Street Address
	SG	Sub-organization
	SO	Source
	TI	Title
	TS	Topic
	UT	ut
	ZP	Zip/Postal Code

=head2 EXPORT

None by default.


=head1 HISTORY

=over 8

=item 0.01

Original version; created by h2xs 1.23 with options

  -n
	SOAP::ISIWoK
	-e
	-A
	-C
	-X
	-c
	-b
	5.8.0

=back



=head1 SEE ALSO

L<SOAP::Lite>, http://www.isiknowledge.com/

=head1 AUTHOR

Timothy D Brody, E<lt>tdb2@ecs.soton.ac.uk<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Tim D Brody

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
