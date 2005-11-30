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
my $package_version;
my $package_desc;
my $package_file;

my $date = `date +%Y-%m-%d`;
chomp $date;

if( $type eq "nightly" ) 
{ 
	$version_path = "/branches/eprints2";
	$package_version = "eprints-2-cvs-".$date;
	$package_desc = "EPrints Nightly Build - $package_version";
	$package_file = "eprints-2-cvs-$date";
}
else
{
	if( !defined $codenames{$type} )
	{
		print "Unknown codename\n";
		print "Available:\n".join("\n",sort keys %codenames)."\n\n";
		exit;
	}
	$package_version = $ids{$type};
	$version_path = "/tags/".$ids{$type};
	$package_desc = "EPrints ".$ids{$type}." (".$codenames{$type}.") [Born on $date]";
	$package_file = "eprints-".$ids{$type};
	print "YAY - $ids{$type}\n";
}

my $license_file = "licenses/gplin.txt";

erase_dir( "export" );

print "Exporting from SVN...\n";
my $originaldir = getcwd();

system("svn export http://mocha/svn/eprints/$version_path export/")==0 or die "Could not export system.\n";

`export/release/internal_makepackage.pl $type export/  $package_file`;

# stuff

print "Removing temporary directories...\n";
erase_dir( "export" );

print "Done.\n";
print "scp $package_file.tar.gz webmaster\@www:/home/www.eprints/mainsite/htdocs/files/eprints2/\n";

exit;





