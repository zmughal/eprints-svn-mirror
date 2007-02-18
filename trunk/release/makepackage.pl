#!/usr/bin/perl -w

use Cwd;
use strict;

# nb.
#
# cvs tag eprints2-2-99-0 system docs_ep2
#
# ./makepackage.pl  eprints2-2-99-0
#
# scp eprints-2.2.99.0-alpha.tar.gz webmaster@www:/home/www.eprints/software/files/eprints2/

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

my( $type ) = @ARGV;

if( !defined $type || $type eq "" ) 
{ 
	print "NO TYPE!\n"; 
	exit 1; 
}

my $version_path;
my $package_file;

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

my $license_file = "licenses/gplin.txt";

erase_dir( "export" );

print "Exporting from SVN...\n";
my $originaldir = getcwd();

mkdir( "export" );

cmd( "svn export http://mocha/svn/eprints$version_path/release/ export/release/")==0 or die "Could not export system.\n";
cmd( "svn export http://mocha/svn/eprints$version_path/system/ export/system/")==0 or die "Could not export system.\n";

my $revision = `svn info http://mocha/svn/eprints$version_path/system/ | grep 'Revision'`;
$revision =~ s/^.*:\s*(\d+).*$/$1/s;
if( $type eq 'nightly' )
{
	$package_file .= "-r$revision";
}

cmd( "export/release/internal_makepackage.pl $type export package $revision" );

# stuff

print "Removing temporary directories...\n";
erase_dir( "export" );

print "Done.\n";
print "./upload.pl $package_file.tar.gz\n";

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
	my( $cmd ) = @_;

	print "$cmd\n";

	return system( $cmd );
}

