#!/usr/bin/perl -w
use Cwd;

if (scalar @ARGV != 4)
{
	print "Usage: makepackage.pl <cvs-version-tag> <package-version> <license-file> <package-filename>\n";
	exit 1;
}

# Get all the vars we need.
($version_tag, $package_version, $license_file, $package_file) = @ARGV;


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
	unless system("$originaldir/insert_license.pl $originaldir/$license_file \"$package_version\" $file")==0; 
}

print "Making tarfile...\n";
chdir $originaldir."/export";
system("mv eprints/system $originaldir/package/eprints")==0 or die("Couldn't move system dir.\n");
chdir $originaldir."/package";

# Add documents dir
mkdir("eprints/html/documents");

# Move library directories.
mkdir("eprints/perl_lib");
system("mv eprints/lib eprints/perl_lib/EPrints")==0 or die("Couldn't make perl_lib dir.\n");

system("chmod -R g-w eprints")==0 or die("Couldn't change permissions on eprints dir.\n");
system("mv eprints $package_file")==0 or die("Couldn't move eprints dir to $package_file.\n");
system("tar czf ../$package_file.tar.gz $package_file")==0 or die("Couldn't tar up $package_file");
chdir $originaldir;

print "Removing temporary directories...\n";
system("/bin/rm -r package")==0 or die("Couldn't remove package dir.\n");
system("/bin/rm -r export")==0 or die("Couldn't remove export dir.\n");

print "Done.\n";
