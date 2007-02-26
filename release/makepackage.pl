#!/usr/bin/perl -w

# nb.
#
# cvs tag eprints2-2-99-0 system docs_ep2
#
# ./makepackage.pl  eprints2-2-99-0
#
# scp eprints-2.2.99.0-alpha.tar.gz webmaster@www:/home/www.eprints/software/files/eprints2/

=head1 NAME

B<makepackage.pl> - Make an EPrints tarball

=head1 SYNOPSIS

B<makepackage.pl> <version OR nightly>

=head1 ARGUMENTS

=over 4

=item I<version>

EPrints version to build or 'nightly' to build nightly version (current trunk HEAD).

=back

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the full manual page and then exit.

=item B<--list>

List all available versions.

=item B<--revision>

Append a revision to the end of the output name.

=item B<--license>

Filename to read license from (defaults to licenses/gpl.txt)

=item B<--license-summary>

Filename to read license summary from (defaults to licenses/gplin.txt) - gets embedded wherever _B<>_LICENSE__ pragma occurs.

=back

=cut

use Cwd;
use Getopt::Long;
use Pod::Usage;
use strict;
use warnings;

my( $opt_revision, $opt_license, $opt_license_summary, $opt_list, $opt_help, $opt_man );

my @raw_args = @ARGV;

GetOptions(
	'help' => \$opt_help,
	'man' => \$opt_man,
	'revision' => \$opt_revision,
	'license=s' => \$opt_license,
	'license-summary=s' => \$opt_license_summary,
	'list' => \$opt_list,
) || pod2usage( 2 );

pod2usage( 1 ) if $opt_help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $opt_man;

my %codenames= ();
my %ids = ();
open( VERSIONS, "versions.txt" ) || die "can't open versions.txt: $!";
while(<VERSIONS>)
{
	chomp;
	$_ =~ s/\s*#.*$//;
	next if( $_ eq "" );
	$_ =~ m/^\s*([^\s]*)\s*([^\s]*)\s*(.*)\s*$/;
	$ids{$1} = $2;
	$codenames{$1} = $3;
}
close VERSIONS;

if( $opt_list )
{
	print "I can build the following versions:\n".join("\n",sort keys %codenames)."\n\n";
	print "To add a version edit 'versions.txt'\n";
	exit;
}

my $version_path;
my $package_file;

pod2usage( 2 ) if( scalar @ARGV != 1 );

my( $type ) = @ARGV;

my $date = `date +%Y-%m-%d`;
chomp $date;

if( $type eq "nightly" ) 
{ 
	$version_path = "/trunk";
	$package_file = "eprints-build-$date";
}
else
{
	if( !defined $codenames{$type} )
	{
		print "Unknown codename\n";
		print "Available:\n".join("\n",sort keys %codenames)."\n\n";
		exit;
	}
	$version_path = "/tags/".$type;
	$package_file = "eprints-".$ids{$type};
	print "YAY - $ids{$type}\n";
}

erase_dir( "export" );

print "Exporting from SVN...\n";
my $originaldir = getcwd();

mkdir( "export" );

cmd( "svn export http://mocha/svn/eprints$version_path/release/ export/release/")==0 or die "Could not export system.\n";
cmd( "svn export http://mocha/svn/eprints$version_path/system/ export/system/")==0 or die "Could not export system.\n";

my $revision = `svn info http://mocha/svn/eprints$version_path/system/ | grep 'Revision'`;
$revision =~ s/^.*:\s*(\d+).*$/$1/s;
if( $type eq 'nightly' and $opt_revision )
{
	$package_file .= "-r$revision";
}

push @raw_args, 'export'; # The source
push @raw_args, 'package'; # The target
push @raw_args, $revision if $opt_revision; # Optional revision

cmd( "export/release/internal_makepackage.pl", @raw_args );

# stuff

print "Removing temporary directories...\n";
erase_dir( "export" );

my( $rpm_file, $srpm_file);

if( $< != 0 )
{
	print "Not running as root, won't build RPM!\n";
}
elsif( system('which rpmbuild') != 0 )
{
	print "Couldn't find rpmbuild in path, won't build RPM!\n";
}
else
{
	open(my $fh, "rpmbuild -ta $package_file.tar.gz|")
		or die "Error executing rpmbuild: $!";
	while(<$fh>) {
		print $_;
		if( /^Wrote:\s+(\S+.src.rpm)/ )
		{
			$srpm_file = $1;
		}
		elsif( /^Wrote:\s+(\S+.rpm)/ )
		{
			$rpm_file = $1;
		}
	}
	close $fh;
}

print "Done.\n";
print "./upload.pl $package_file.tar.gz\n";
if( $rpm_file )
{
	print "rpm --addsign $rpm_file $srpm_file\n";
	print "$rpm_file\n";
	print "$srpm_file\n";
}

exit;


sub erase_dir
{
	my( $dirname ) = @_;

	if (-d $dirname )
	{
		cmd( "/bin/rm -rf ".$dirname ) == 0 or 
			die "Couldn't remove ".$dirname." dir.\n";
	}
}


sub cmd
{
	print join(' ', @_)."\n";

	return system( @_ );
}

