package SOAP::ISIWoK;

use Carp;
use SOAP::Lite
#	+trace => "all"
;
use XML::LibXML;
use Exporter;

@ISA = qw( Exporter );

@EXPORT = qw( );
@EXPORT_OK = qw( @WOS_FIELDS @WOS_EDITIONS @WOS_INDEXES @WOS_LANGUAGES @WOS_DOCUMENT_TYPES );
%EXPORT_TAGS = (
	wos => [qw( @WOS_FIELDS @WOS_EDITIONS @WOS_INDEXES @WOS_LANGUAGES @WOS_DOCUMENT_TYPES )]
);

@WOS_FIELDS = (
	abbrev_iso => '',
	abbrev_11 => '',
	abbrev_22 => 'Journal name abbreviation',
	abbrev_29 => '',
	abstract => 'The abstract of the article',
	article_no => '',
	article_nos => 'Article number',
	author => 'Any additional authors',
	authors => 'All authors',
	bib_date => 'Cover date',
	bib_id => 'Volume, issue, special, pages and year data',
	bib_issue => 'Volume and year data',
	bib_misc => '',
	bib_pagecount => '',
	bib_pages => 'Begin and end pages',
	bib_vol => 'Issue and volume',
	bk_binding => '',
	bk_ordering => '',
	bk_prepay => '',
	bk_price => '',
	bk_publisher => '',
	book_authors => '',
	book_corpauthor => '',
	book_chapters => '',
	book_desc => '',
	book_editor => '',
	book_editors => '',
	book_note => '',
	book_notes => '',
	book_series => '',
	book_subtitle => '',
	bs_subtitle => '',
	bs_title => '',
	categories => '',
	category => '',
	conference => '',
	conferences => '',
	conf_city => '',
	conf_date => '',
	conf_end => '',
	conf_host => '',
	conf_id => '',
	conf_location => '',
	conf_start => '',
	conf_title => '',
	conf_sponsor => '',
	conf_sponsors => '',
	conf_state => '',
	copyright => 'Copyright notice',
	corp_authors => 'Corporate authors',
	doctype => 'Document type',
	editions => 'Edition code (or codes).',
	editor => '',
	email => '',
	emails => 'Author email addresses',
	email_addr => '',
	heading => '',
	headings => '',
	ids => 'ISI TGA number',
	io => '',
	isbn => '',
	issn => 'International Standard Serial Number',
	issue_ed => '',
	issue_title => '',
	item_enhancedtitle => '',
	item_title => 'Item title',
	i_cid => '',
	i_ckey => 'Cluster key',
	keyword => '',
	keywords => 'Author keywords',
	keywords_plus => 'ISI generated keywords',
	lang => '',
	languages => 'Primary language',
	load => '',
	meeting_abstract => '',
	name => '',
	p => '',
	primaryauthor => 'Primary author',
	primarylang => '',
	publisher => '',
	pubtype => 'Publication type',
	pub_address => '',
	pub_city => '',
	pub_url => '',
	ref => '',
	refs => 'The recid values of any cited references',
	reprint => 'Reprint address',
	research_addrs => 'Research address',
	research => '',
	reviewed_work => '',
	rp_address => '',
	rp_author => '',
	rp_city => '',
	rp_country => '',
	rp_organization => '',
	rp_state => '',
	rp_street => '',
	rp_suborganization => '',
	rp_suborganizations => '',
	rp_zip => '',
	rp_zips => '',
	rs_address => '',
	rs_city => '',
	rs_country => '',
	rs_organization => '',
	rs_state => '',
	rs_street => '',
	rs_suborganization => '',
	rs_suborganizations => '',
	rs_zip => '',
	rs_zips => '',
	rw_author => '',
	rw_authors => '',
	rw_lang => '',
	rw_langs => '',
	rw_year => '',
	source_abbrev => 'Abbreviated name of the journal',
	source_editors => '',
	source_series => '',
	source_title => 'Full name of the journal',
	sq => '',
	subject => '',
	subjects => 'Subjects',
	ui => '',
	unit => '',
	units => '',
	ut => 'ISI UT identifier',
);

@WOS_SORT_FIELDS = (
	'Date' => 'WOS inclusion date order.',
	'Relevance' => 'The relevance of each record to the search request.',
	'Times Cited' => 'The number of times each record is cited.',
);

@WOS_EDITIONS = (
	SCI => 'Science Citation Index',
	SSCI => 'Social Sciences Citation Index',
	AHCI => 'Arts & Humanities Citation Index',
	IC => 'Index Chemicus',
	ISTP => 'Science & Technology Proceedings',
	ISSHP => 'Social Sciences & Humanities Proceedings',
	CCR => 'Current Chemical Reactions',
);

@WOS_INDEXES = (
	AD => 'Address',
	AU => 'Author',
	CA => 'Cited Author',
	CI => 'City',
	CT => 'Conference',
	CU => 'Country',
	CW => 'Cited Work',
	CY => 'Cited Year',
	DT => 'Document Type',
	GP => 'Group Author',
	LA => 'Language',
	OG => 'Organization',
	PS => 'Province/State',
	PY => 'Pub Year',
	SA => 'Street Address',
	SG => 'Sub-organization',
	SO => 'Source',
	TI => 'Title',
	TS => 'Topic',
	UT => 'ISI UT identifier',
	ZP => 'Zip/Postal Code',
);

# LA index
@WOS_LANGUAGES = (
	'AF' => 'Afrikaans',
	'AR' => 'Arabic',
	'BE' => 'Bengali',
	'BU' => 'Bulgarian',
	'BY' => 'Byelorussian',
	'CA' => 'Catalan',
	'CH' => 'Chinese',
	'CR' => 'Croatian',
	'CZ' => 'Czech',
	'DA' => 'Danish',
	'DU' => 'Dutch',
	'EN' => 'English',
	'ES' => 'Estonian',
	'FI' => 'Finnish',
	'FL' => 'Flemish',
	'FR' => 'French',
	'GA' => 'Gaelic',
	'GL' => 'Galician',
	'GN' => 'Georgian',
	'GE' => 'German',
	'GR' => 'Greek',
	'HE' => 'Hebrew',
	'HU' => 'Hungarian',
	'IC' => 'Icelandic',
	'IT' => 'Italian',
	'JA' => 'Japanese',
	'KO' => 'Korean',
	'LA' => 'Latin',
	'MC' => 'Macedonian',
	'XX' => 'Multi-Language',
	'NO' => 'Norwegian',
	'PE' => 'Persian',
	'PO' => 'Polish',
	'PT' => 'Portuguese',
	'PR' => 'Provencal',
	'RM' => 'Rumanian',
	'RS' => 'Russian',
	'SE' => 'Serbian',
	'SC' => 'Serbo-Croatian',
	'SK' => 'Slovak',
	'SL' => 'Slovene',
	'SP' => 'Spanish',
	'SW' => 'Swedish',
	'TU' => 'Turkish',
	'UK' => 'Ukrainian',
	'WE' => 'Welsh',
);

# DT index
@WOS_DOCUMENT_TYPES = (
	'2' => 'Abstract of Published Item',
	'A' => 'Art Exhibit Review',
	'@' => 'Article',
	'7' => 'Bibliography',
	'I' => 'Biographical-Item',
	'B' => 'Book Review',
	'K' => 'Chronology',
	'C' => 'Correction',
	'C' => 'Correction, Addition',
	'Z' => 'Dance Performance Review',
	'0' => 'Database Review',
	'D' => 'Discussion',
	'E' => 'Editorial Material',
	'X' => 'Excerpt',
	'O' => 'Fiction, Creative Prose',
	'F' => 'Film Review',
	'8' => 'Hardware Review',
	'I' => 'Item About an Individual',
	'L' => 'Letter',
	'M' => 'Meeting Abstract',
	'J' => 'Music Performance Review',
	'S' => 'Music Score',
	'G' => 'Music Score Review',
	'5' => 'News Item',
	'N' => 'Note',
	'Y' => 'Poetry',
	'H' => 'Record Review',
	'6' => 'Reprint',
	'R' => 'Review',
	'Q' => 'Script',
	'9' => 'Software Review',
	'V' => 'TV Review, Radio Review',
	'V' => 'TV Review, Radio Review, Video',
	'T' => 'Theater Review',
);

use 5.008;
use strict;

our $VERSION = '1.03';

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

  print $results->toString;

=head1 DESCRIPTION

This module is a thin wrapper for the ISI Web of Knowledge SOAP interface.

It takes a search description and returns the resulting XML response from ISI as a L<XML::LibXML> document. Parsing the search result is outside of the scope of this module.

To access the ISI WoK interface you will need a subscription to ISI WoK and arrange for access to their Web services server (you'll need to talk to your ISI representative).

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
	UT	ISI UT identifier
	ZP	Zip/Postal Code

=head2 EXPORT

None by default.


=head1 HISTORY

=over 8

=item 1.03

Fixed some issues in the POD.

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

Timothy D Brody, E<lt>tdb2@ecs.soton.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Tim D Brody, University of Southampton, UK

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
