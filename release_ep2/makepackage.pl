#!/usr/bin/perl -w
use Cwd;

sub do_license
{
	my( $license_file, $version_info, $source) = @_;
	my @license_text;
	print $license_file."\n";
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
	my($version_tag, $package_version, $license_file, $package_file) = @_;
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
	system("cvs export -r $version_tag eprints/system >/dev/null")==0 or die "Could not export.\n";

	print "Removing .cvsignore files...\n";
	system("/bin/rm `find . -name '.cvsignore'`")==0 or die "Couldn't remove.";

	print "Inserting license information...\n";
	chdir "eprints/system";
	@files = `grep -l -d skip "__LICENSE__" bin/* cgi/* cgi/users/* lib/*.pm`;
	foreach $file (@files)
	{
		chomp $file;
		print STDERR "WARNING: Could not insert license file into $file.\n" 
		unless do_license("$originaldir/$license_file", $package_version, $file)==0;
	}

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
		/(.*)\t(.*)/;
		print "Copying $originaldir/export/$1 to $cd/eprints/$2\n";
		system("cp $originaldir/export/$1 eprints/$2");
	}
	close(FILECONF);

	chdir $originaldir."/package";

	# Add documents dir
	mkdir("eprints/html/documents");

	system("chmod -R g-w eprints")==0 or die("Couldn't change permissions on eprints dir.\n");
	system("mv eprints $package_file")==0 or die("Couldn't move eprints dir to $package_file.\n");
	system("tar czf ../$package_file.tar.gz $package_file")==0 or die("Couldn't tar up $package_file");
	chdir $originaldir;

	print "Removing temporary directories...\n";
	system("/bin/rm -r package")==0 or die("Couldn't remove package dir.\n");
	system("/bin/rm -r export")==0 or die("Couldn't remove export dir.\n");

	print "Done.\n";

}


if (scalar @ARGV != 4)
{
	print "Usage: makepackage.pl <cvs-version-tag> <package-version> <license-file> <package-filename>\n";
	exit 1;
}

# Get all the vars we need.
($version_tag, $package_version, $license_file, $package_file) = @ARGV;

do_package($version_tag, $package_version, $license_file, $package_file);
