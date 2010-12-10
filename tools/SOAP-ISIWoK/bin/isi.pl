#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use Pod::Usage;
use Getopt::Long;
use SOAP::ISIWoK::Lite;

use strict;
use warnings;

=head1 NAME

isi.pl - query ISI Web of Science

=head1 SYNOPSIS

isi.pl B<query>

=head1 ARGUMENTS

=over 8

=item B<isi.pl> query

Queries ISI with the given query (a single string) e.g.:

	"OG=(University of Southampton)"

=back

=head1 OPTIONS

=over 8

=item help

Show help.

=item man

Show man page.

=item offset

Set the search offset (starting at 0), defaults to 0.

=item max

Maximum number of records to find, defaults to 10.

=item database

The ISI database to search, defaults to 'WOS'.

=item fields

A comma-separated list of extra fields to return, defaults to 'times_cited'.

=item sort

The index to sort by, defaults to 'Relevance'.

=back

=head1 EXAMPLES

	# search by organisation
	./isi.pl "OG=(Univ Southampton)"

	# find the next 10 records
	./isi.pl --offset 10 "OG=(Univ Southampton)"

	# more complex query
	./isi.pl "AU=(Brody, T) and OG=(Southampton) and PY=(2007-2010)"

=head1 AUTHOR

Copyright 2010 Timothy D Brody E<lt>tdb2@ecs.soton.ac.ukE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

my( $opt_help, $opt_man );
my $opt_offset = 0;
my $opt_max = 10;
my $opt_database = "WOS";
my $opt_fields = "times_cited";
my $opt_sort = "Relevance";

GetOptions(
	'help|?' => \$opt_help,
	'man' => \$opt_man,
	'offset=i' => \$opt_offset,
	'max=i' => \$opt_max,
	'database=s' => \$opt_database,
	'fields=s' => \$opt_fields,
	'sort=s' => \$opt_sort,
) or pod2usage( 2 );

pod2usage( 1 ) if $opt_help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $opt_man;
pod2usage( 2 ) if @ARGV != 1;

$opt_offset += 1; # WoS is 1-indexed
my @fields = split /\s*,\s*/, $opt_fields;
my $query = shift @ARGV;

my $wok = SOAP::ISIWoK::Lite->new;

# search will croak on error
my $results = $wok->search( $query,
		offset => $opt_offset,
		max => $opt_max,
		database => $opt_database,
		fields => \@fields,
		sort => $opt_sort,
	);

print $results->toString;
