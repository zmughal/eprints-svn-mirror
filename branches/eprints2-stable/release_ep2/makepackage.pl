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


my %codenames = (
	"eprints2-alpha-1" => "anchovy",
	"eprints2-alpha-2" => "pepperoni",
	"eprints2-pre-1"   => "fishfinger",
	"eprints2-pre-2"   => "ovenchip",
	"eprints2-pre-3"   => "toast",
	"eprints2-pre-4"   => "noodle",
	"eprints2-pre-5"   => "bovex",
	"eprints2-pre-6"   => "baconbits",
	"eprints2-pre-7"   => "limepickle",
	"eprints2-2-0"   => "olive",
	"eprints-2-0-1pre1"   => "mangogoo",
	"eprints2-0-1"   => "tuna",
	"eprints2-1-pre-1"   => "onionring",
	"eprints2-1-pre-2"   => "misosoup",
	"eprints2-1-pre-3"   => "friedeel",
	"eprints2-1-pre-4"   => "sossy",
	"eprints2-1-pre-5"   => "chickendonner",
	"eprints2-1"   => "pineapple",
	"eprints2-1-1-pre-1" => "chillioil",
	"eprints2-1-1" => "sweetcorn",
	"eprints2-2-0-pre-1" => "candycorn",
	"eprints2-2-0-pre-2" => "bobbing-apple",
	"eprints-2-2" => "pumpkin",
	"eprints-2-2-1" => "pepper",
	"eprints2-3-0-tardis-1" => "devildoll",
	"eprints2-3-0-tardis-2" => "spacemutiny",
	"eprints2-3-0-pre-1" => "princeofspace",
	"eprints2-3-0-pre-2" => "agentforharm",
	"eprints2-2-99-0" => "extracrust",
	"eprints2-2-99-1" => "webfoot",
	"eprints2-2-99-2" => "makeroomforthetuna",
	"eprints2-2-99-3" => "whydoesithurt",
	"eprints2-2-99-4" => "Hope Springs Eternal",
	"eprints2-2-99-5" => "Make Mine a Ninety-Nine",
	"eprints2-2-99-6" => "It will be over by Christmas...",


	"eprints2-3" => "Hoi Sin Duck"

);

my %ids = (
	"eprints2-pre-6"   => "2.0.pre-6",
	"eprints2-2-0"     => "2.0",
	"eprints-2-0-1pre1"     => "2.0.1.pre-1",
	"eprints2-0-1"     => "2.0.1",
	"eprints2-1-pre-1"     => "2.1",
	"eprints2-1-pre-2"     => "2.1.pre-2",
	"eprints2-1-pre-3"     => "2.1.pre-3",
	"eprints2-1-pre-4"     => "2.1.pre-4",
	"eprints2-1-pre-5"     => "2.1.pre-5",
	"eprints2-1"     => "2.1",
	"eprints2-1-1-pre-1" => "2.1.1.pre-1",
	"eprints2-1-1" => "2.1.1",
	"eprints2-2-0-pre-1" => "2.2-pre-1",
	"eprints2-2-0-pre-2" => "2.2-pre-2",
	"eprints-2-2" => "2.2",
	"eprints-2-2-1" => "2.2.1",
	"eprints2-3-0-tardis-1" => "2.3.0-tardis-1",
	"eprints2-3-0-tardis-2" => "2.3.0-tardis-2",
	"eprints2-3-0-pre-1" => "2.3.0-pre-1",
	"eprints2-3-0-pre-2" => "2.3.0-pre-2",
	"eprints2-2-99-0" => "2.2.99.0-alpha",
	"eprints2-2-99-1" => "2.2.99.1-alpha",
	"eprints2-2-99-2" => "2.2.99.2-alpha",
	"eprints2-2-99-3" => "2.2.99.3-alpha",
	"eprints2-2-99-4" => "2.2.99.4-beta",
	"eprints2-2-99-5" => "2.2.99.5-beta",
	"eprints2-2-99-6" => "2.2.99.6-beta",


	"eprints2-3" => "2.3.0"
);

my( $type ) = @ARGV;

if( !defined $type || $type eq "" ) 
{ 
	print "NO TYPE!\n"; 
	exit 1; 
}

my $version_tag;
my $package_version;
my $package_desc;
my $package_file;

my $date = `date +%Y-%m-%d`;
chomp $date;

if( $type eq "nightly" ) 
{ 
	$version_tag = "eprints2-stable";
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
	$version_tag = $type;
	$package_version = $ids{$type};
	$package_desc = "EPrints $ids{$type} (".$codenames{$type}.") [Born on $date]";
	$package_file = "eprints-".$ids{$type};
	print "YAY - $ids{$type}\n";
}

my $whoami = `whoami`;
chomp $whoami;
$ENV{"CVSROOT"} = ":pserver:$whoami\@cvs.iam.ecs.soton.ac.uk:/home/iamcvs/CVS";

my $license_file = "licenses/gplin.txt";

erase_dir( "package" );
erase_dir( "export" );

print "Making directories...\n";
mkdir("package") or die "Couldn't create package directory\n";
mkdir("export") or die "Couldn't create export directory\n";

print "Exporting from CVS...\n";
my $originaldir = getcwd();
chdir "export";
system("cvs export -r $version_tag eprints/system >/dev/null")==0 or die "Could not export system.\n";
system("cvs export -r $version_tag eprints/docs_ep2 >/dev/null")==0 or die "Could not export docs.\n";
print "Removing .cvsignore files...\n";
system("/bin/rm `find . -name '.cvsignore'`")==0 or die "Couldn't remove.";
chdir "eprints/system";

my @installerfiles = ( 
	'perlmodules.pl',
	'aclocal.m4',
	'autogen.sh',
	'configure.in',
	'df-check.pl',
	'install.pl.in' );
foreach( @installerfiles )
{
	system("cp $originaldir/$_ $_");
}
system("./autogen.sh");

my @files = @installerfiles;
foreach my $dir ( "archivecfg", "bin", "cgi", "cgi/users", "lib" )
{
	opendir( DIR, $dir );
	my $file;
	while( $file = readdir( DIR ) )
	{
		next if $file=~m/^\./; # not if it starts with .
		next unless( -f "$dir/$file" );
		push @files, "$dir/$file";
	}
	closedir( DIR );
}
my $license = "";
open( FILE, "$originaldir/$license_file" );
while( <FILE> ) { $license .= $_; }
close FILE;
my $genericpod = "";
open( FILE, "pod/generic.pod" );
while( <FILE> ) { $genericpod .= $_; }
close FILE;
foreach my $file ( @files )
{
	insert_data( "__GENERICPOD__", $genericpod, $file, 1 );
	insert_data( "__LICENSE__", $license, $file, 1 );
	insert_data( "__VERSION__", $package_version, $file );
}


# Build docs - cjg Mike this needs to be smarter about what to copy (alpha/beta etc)
print "Build Docs...\n"	;
chdir $originaldir."/export/eprints/docs_ep2";
`./mkdocs.pl`;
	
print "Making tarfile...\n";
chdir $originaldir."/package";

print "Making dirs...\n";
open(DIRCONF, "$originaldir/conf/dirs.conf");
mkdir("eprints");
while(<DIRCONF>)
{
	chomp;
	mkdir("eprints/$_");
}
close(DIRCONF);

print "Copying files...\n";
open(FILECONF, "$originaldir/conf/files.conf");
while(<FILECONF>)
{
	chomp;
	next if /^#/;
	s/\s*#.*$//;
	next if /^\s*$/;
	my( $from, $to, $recurse ) = split /\t/;
	my $recstr = "";
	$recstr = "-r" if (defined $recurse);
	my $cmd = "cp $recstr $originaldir/export/$from eprints/$to";
	print "$cmd\n";
	system( $cmd );
}
close(FILECONF);

chdir $originaldir."/package";

# Add documents dir
mkdir("eprints/html/documents");

# Do version
open(FILEOUT, ">eprints/VERSION");
print FILEOUT $package_version."\n";
print FILEOUT $package_desc."\n";
close(FILEOUT);

# my @phrasefiles = ();
# # Build up list from export.
# opendir(PHRSDIR, "$originaldir/export/eprints/system/phrases");
# while($item = readdir(PHRSDIR))
# {
# if (-d $item || $item =~ /^\./ ) { next; }	
# push(@phrasefiles, $item);
# }
# closedir(PHRSDIR);
# 
# Nasty...
#	foreach $l (@langs)
#	{
#		$currarch = 0;
#		$currsys = 0;
#		foreach(@files)
#		{
#			if (/archive-$l-([0-9]+)/)
#			{
#				if ($1>$currarch) { $currarch = $1; }
#			}
#			elsif (/system-$l-([0-9]+)/)
#			{
#				if ($1>$currsys) { $currsys = $1; }
#			}
#		}
#		if ($l eq "en")
#		{
#			$enarch = $currarch;
#			$ensys	= $currsys;
#		}
#		next if ($l eq "en");
#
#		print "For language $l:\n";
#		print "Newest arch: archive-$l-$currarch\n";
#		print "Newest sys: system-$l-$currsys\n";
#		if ($currsys>0)
#		{
#			print "Copying $l language file.\n";	
#			system("cp $originaldir/export/eprints/system/phrases/system-$l-$currsys eprints/cfg/system-phrases-$l.xml");
#		}	
#		else
#		{
#			print "Copying English language file as placeholder\n";
#			system("cp $originaldir/export/eprints/system/phrases/system-en-$ensys eprints/cfg/system-phrases-$l.xml");
#		}
#
#		if ($currarch>0)
#		{
#			print "Copying $l language file.\n";
#			system("cp $originaldir/export/eprints/system/phrases/archive-$l-$currarch eprints/defaultcfg/phrases-$l.xml");
#		}
#		else
#		{
#			print "Copying English language file as placeholder\n";
#			system("cp $originaldir/export/eprints/system/phrases/archive-en-$enarch eprints/defaultcfg/phrases-$l.xml");
#		}
#	}
#	# ...Nasty
#
#	if ($is_proper_release == 0)
#	{
#		# Here we copy over the nightly language files
#		foreach $l (@langs)
 #               {
#			if (-e "$originaldir/export/eprints/system/phrases/archive-$l-current")
#			{
#				print "Transferring $l phrases...\n";
#				system("cp $originaldir/export/eprints/system/phrases/archive-$l-current eprints/defaultcfg/phrases-$l.xml");
#			}
#			if (-e "$originaldir/export/eprints/system/phrases/system-$l-current")
#			{
#				print "Transferring $l system phrases...\n";
#				system("cp $originaldir/export/eprints/system/phrases/system-$l-current eprints/cfg/system-phrases-$l.xml");
#			}
#		}
#	}
#	elsif($is_proper_release == 1)
#	{
#		# Here we copy over the Alpha language files
#		foreach $l (@langs)
 #               {
#			if (-e "$originaldir/export/eprints/system/phrases/archive-$l-1")
#			{
#				print "Transferring $l phrases...\n";
#				system("cp $originaldir/export/eprints/system/phrases/archive-$l-1 eprints/defaultcfg/phrases-$l.xml");
#			}
#			if (-e "$originaldir/export/eprints/system/phrases/system-$l-1")
#			{
#				print "Transferring $l system phrases...\n";
#				system("cp $originaldir/export/eprints/system/phrases/system-$l-1 eprints/cfg/system-phrases-$l.xml");
#			}
#		}
#	}

# Do phrases
my @langs = ("en" );

foreach my $l ( @langs )
{
	if( -e "$originaldir/export/eprints/system/phrases/system-$l-current" )
	{
		system("cp $originaldir/export/eprints/system/phrases/system-$l-current eprints/cfg/system-phrases-$l.xml");
	}
	if( -e "$originaldir/export/eprints/system/phrases/archive-$l-current" )
	{
		system("cp $originaldir/export/eprints/system/phrases/archive-$l-current eprints/defaultcfg/phrases-$l.xml");
	}
}

print "Inserting license information...\n";
system("cp $originaldir/licenses/gpl.txt eprints/COPYING");
system("rm eprints/perl_lib/EPrints/SystemSettings.pm");
system("chmod -R g-w eprints")==0 or die("Couldn't change permissions on eprints dir.\n");

system("mv eprints $package_file")==0 or die("Couldn't move eprints dir to $package_file.\n");
my $tarfile = "../".$package_file.".tar.gz";
if( -e $tarfile ) { system( "rm $tarfile" ); }
system("tar czf $tarfile $package_file")==0 or die("Couldn't tar up $package_file");
chdir $originaldir;

	

print "Removing temporary directories...\n";

erase_dir( "package" );
erase_dir( "export" );

print "Done.\n";

exit;




#####################

sub insert_data
{
	my( $key, $value, $source, $multiline) = @_;

	open IN, $source or die "Unable to open source file.\n";
	my $perms = (stat IN)[2];

	open OUT, ">$source.out" or die "Unable to open output file.\n";

	while ( <IN> )
	{
		if( $multiline )
		{
			if( /$key/ )
			{
				my $line;
				foreach $line ( split( "\n", $value ) )
				{
					my $l2 = $_;
					$l2=~s/$key/$line/;
					print OUT $l2;
				}
			}
			else
			{
				print OUT $_;
			}
		}
		else
		{
			s/$key/$value/g;
			print OUT $_;
		}
	}

	close OUT;
	close IN;
	system( "mv", "$source.out", "$source" );
	chmod $perms, $source or die "Unable to chmod: $!";

	return 0;
}

sub erase_dir
{
	my( $dirname ) = @_;

	if (-d $dirname )
	{
		system( "/bin/rm -rf ".$dirname ) == 0 or 
			die "Couldn't remove ".$dirname." dir.\n";
	}
}
	
