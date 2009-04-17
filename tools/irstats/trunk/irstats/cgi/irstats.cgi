#!/usr/bin/perl -w -I/opt/eprints3/perl_lib

##############################################################################
### Configuration ###
##############################################################################

# awstats modules
use lib "/var/www/awstats/lib";

# ChartDirector
use lib "/opt/eprints3/perl_lib/ChartDirector";

use IRStats;
use EPrints;

# The path to IRStat's configuration file

##############################################################################
### End of Configuration ###
##############################################################################

use encoding 'utf8';
IRStats::handler();

1;

__END__

=head1 SYNOPSIS

B<irstats.pl> [OPTIONS] <ARGUMENTS>

=head1 OPTIONS

=over 8

=item --help

Print the help.

=item --man

Print the man page.

=item --config <config file>

Specify an alternate configuration file.

=item --verbose

Be more verbose (repeatable).

=back

=head1 ARGUMENTS

=over 4

=item COMMAND

The command to execute, see man page for details.

=back

=head1 COMMANDS

The following commands are available:

=over 4

=item import_metadata

Import metadata from source CSV files.

=item update_table

Update the access log table from the database.

=item convert_ip_to_host

Convert IP addresses to hostnames in the database.

=item extract_metadata_from_archive

Extract metadata from an eprints 2 archive.

=item extract_generic_eprints

=item extract_generic_dspace

Extract some basic citation/eprints data for GNU EPrints and DSpace respectively. These mechanisms don't support sets at all.

=back
