#!/usr/bin/perl -w

use Cwd;

$EPRINTS_VERSION = "2.0.a";
$DATE = `date +%Y-%m-%d`;
chomp $DATE;
$NIGHTLY_DESC = "EPrints $EPRINTS_VERSION Alpha (Nightly Build $DATE)";
$NIGHTLY_VERSION = "$EPRINTS_VERSION-$DATE";
$MILESTONE_DESC_A = "EPrints $EPRINTS_VERSION (";
$MILESTONE_DESC_B = ") [Born on $DATE]";
$MILESTONE_VERSION = $EPRINTS_VERSION;
%codenames = (
	"eprints2-alpha-1" => "anchovy"
);

sub do_license
{
	my( $license_file, $version_info, $source) = @_;
	my @license_text;
	open LICENSE, $license_file or die "Unable to open license file: $!";
	while( <LICENSE> )
	{
		chomp;
		s/__VERSION__/$version_info/g;
		push @license_text, "# $_";
	}
	close LICENSE;

	open IN, $source or die "Unable to open source file.\n";
	my $perms = (stat IN)[2];

	open OUT, ">$source.out" or die "Unable to open output file.\n";

	while ( <IN> )
	{
		chomp();
		if( /__LICENSE__/ )
		{
			# Replace with license text
			foreach (@license_text)
			{
				print OUT "$_\n";
			}
		}
		else
		{
			print OUT "$_\n";
		}
	}

	close OUT;
	close IN;
	system( "mv", "$source.out", "$source" );
	chmod $perms, $source or die "Unable to chmod: $!";

	return 0;
}

sub do_package
{
	my($version_tag, $package_version, $package_desc, $license_file, $package_file, $type_num) = @_;
	if (-d "package")
	{
		system("/bin/rm -r package")==0 or die "Couldn't remove package dir.\n";
	}
	
	if (-d "export")
	{
		system("/bin/rm -r export")==0 or die "Couldn't remove export dir.\n";
	}
	
	print "Making directories...\n";
	mkdir("package") or die "Couldn't create package directory\n";
	mkdir("export") or die "Couldn't create export directory\n";

	print "Exporting from CVS...\n";
	$originaldir = getcwd();
	chdir "export";
	system("cvs export -r $version_tag eprints/system >/dev/null")==0 or die "Could not export system.\n";
	system("cvs export -r $version_tag eprints/ep2_docs >/dev/null")==0 or die "Could not export docs.\n";

	print "Removing .cvsignore files...\n";
	system("/bin/rm `find . -name '.cvsignore'`")==0 or die "Couldn't remove.";
	print "Copying installer...\n";
	system("cp $originaldir/install-eprints.pl eprints/system/install-eprints.pl");
	print "Inserting license information...\n";
	chdir "eprints/system";
	@files = `grep -l -d skip "__LICENSE__" install-eprints.pl archivecfg/* bin/* cgi/* cgi/users/* lib/*.pm`;
	foreach $file (@files)
	{
		chomp $file;
		print STDERR "WARNING: Could not insert license file into $file.\n" 
		unless do_license("$originaldir/$license_file", $package_version, $file)==0;
	}


	# Build docs - cjg Mike this needs to be smarter about what to copy (alpha/beta etc)
	chdir $originaldir."/export/eprints/ep2_docs";
	`make`;
	
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
	$cd = getcwd();
	open(FILECONF, "$originaldir/conf/files.conf");
	while(<FILECONF>)
	{
		chomp;
		s/\s*#.*$//;
		next if /^\s*$/;
		/(.*)\t(.*)/;
		print "Copying $originaldir/export/$1 to $cd/eprints/$2\n";
		system("cp $originaldir/export/$1 eprints/$2");
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

	# Do phrases
	@langs = ("en", "fr");
	@files = ();

	# Build up list from export.
	opendir(PHRSDIR, "$originaldir/export/eprints/system/phrases");
	while($item = readdir(PHRSDIR))
	{
		if (-d $item || $item =~ /^\./ ) { next; }	
		push(@files, $item);
	}
	closedir(PHRSDIR);
	if ($type_num == 0)
	{
		# Here we copy over the nightly language files
		foreach $l (@langs)
                {
			if (-e "$originaldir/export/eprints/system/phrases/archive-$l-current")
			{
				print "Transferring $l phrases...\n";
				system("cp $originaldir/export/eprints/system/phrases/archive-$l-current eprints/defaultcfg/phrases-$l.xml");
			}
			if (-e "$originaldir/export/eprints/system/phrases/system-$l-current")
			{
				print "Transferring $l system phrases...\n";
				system("cp $originaldir/export/eprints/system/phrases/system-$l-current eprints/sys/system-phrases-$l.xml");
			}
		}
#		foreach $l (@langs)
#		{
#			$currarch = 0;
#			$currsys = 0;
#			foreach(@files)
#			{
#				if (/archive-$l-([0-9]+)/)
#				{
#					if ($1>$currarch) { $currarch = $1; }
#				}
#				elsif (/system-$l-([0-9]+)/)
#				{
#					if ($1>$currsys) { $currsys = $1; }
#				}
#			}
#			if ($l eq "en")
#			{
#				$enarch = $currarch;
#				$ensys	= $currsys;
#			}
#			print "For language $l:\n";
#			print "Newest arch: archive-$l-$currarch\n";
#			print "Newest sys: system-$l-$currsys\n";
#			if ($currsys>0)
#			{	
#				system("cp $originaldir/export/eprints/system/phrases/system-$l-$currsys eprints/sys/system-phrases-$l.xml");
#			}	
#			else
#			{
#				system("cp $originaldir/export/eprints/system/phrases/system-en-$ensys eprints/sys/system-phrases-$l.xml");
#			}
#	
#			if ($currarch>0)
#			{
#				system("cp $originaldir/export/eprints/system/phrases/archive-$l-$currarch eprints/defaultcfg/phrases-$l.xml");
#			}
#			else
#			{
#				system("cp $originaldir/export/eprints/system/phrases/archive-en-$enarch eprints/defaultcfg/phrases-$l.xml");
#			}
#		}
	}
	elsif($type_num == 1)
	{
		# Here we copy over the Alpha language files
		foreach $l (@langs)
                {
			if (-e "$originaldir/export/eprints/system/phrases/archive-$l-1")
			{
				print "Transferring $l phrases...\n";
				system("cp $originaldir/export/eprints/system/phrases/archive-$l-1 eprints/defaultcfg/phrases-$l.xml");
			}
			if (-e "$originaldir/export/eprints/system/phrases/system-$l-1")
			{
				print "Transferring $l system phrases...\n";
				system("cp $originaldir/export/eprints/system/phrases/system-$l-1 eprints/sys/system-phrases-$l.xml");
			}
		}
	}
	# system("cp $originaldir/export/eprints/system/cgi/users/.htaccess eprints/cgi/users/.htaccess");
	system("cp $originaldir/licenses/gpl.txt eprints/COPYING");
	system("chmod -R g-w eprints")==0 or die("Couldn't change permissions on eprints dir.\n");
	system("mv eprints $package_file")==0 or die("Couldn't move eprints dir to $package_file.\n");
	system("tar czf ../$package_file.tar.gz $package_file")==0 or die("Couldn't tar up $package_file");
	chdir $originaldir;

	

	print "Removing temporary directories...\n";
	system("/bin/rm -r package")==0 or die("Couldn't remove package dir.\n");
	system("/bin/rm -r export")==0 or die("Couldn't remove export dir.\n");

	print "Done.\n";

}
$whoami = `whoami`;
chomp $whoami;
$ENV{"CVSROOT"} = ":pserver:$whoami\@cvs.iam.ecs.soton.ac.uk:/home/iamcvs/CVS";
# Get all the vars we need.
($type) = @ARGV;
$ntype = -1;
if (!defined($type) || $type eq "nightly")
{
	$version_tag = "HEAD";
	$package_version = $NIGHTLY_VERSION;
	$package_desc = $NIGHTLY_DESC;	
	$package_file = "eprints2-nightly-$DATE";
	$ntype = 0;
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
	$package_version = $MILESTONE_VERSION;
	$package_desc = $MILESTONE_DESC_A.$codenames{$type}.$MILESTONE_DESC_B;
	$package_file = $type;
	$ntype = 1;
}

do_package($version_tag, $package_version, $package_desc, "licenses/gplin.txt", $package_file, $ntype);
