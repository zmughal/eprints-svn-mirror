#!/usr/bin/perl -w

use strict;
use Cwd;
print <<INTRO;
EPrints 2 Installer
-------------------

This installer creates the necessary directories and files for 
you to begin configuring EPrints 2.

INTRO

print "Checking user ... ";
if (0) #($<!=0) -- removed while testing.
{
	print "Failed!\n";
	print "Sorry, his installer must be run as root.\n";
	exit 1;
}
else { print "OK.\n\n"; }

# Grab version number from VERSION file.
open(VERSIONIN, "VERSION") or die "No VERSION file - invalid distribution?";
my $version = <VERSIONIN>;
if (!defined($version)) { die "Undefined version number."; }
chomp($version);
my $version_desc = <VERSIONIN>;
if (!defined($version_desc)) { die "Undefined version descriptor."; }
chomp($version_desc);
close(VERSIONIN);


my @paths = ("/bin/", "/usr/bin/", "/usr/local/bin/", "/usr/sbin/");
my %exesettings = ();
my %systemsettings = ();

# Set up some default settings.
my %invocsettings = (
	ZIP     => "\$(EXE_ZIP) 1>/dev/null 2>\&1 -qq -o -d \$(DIR) \$(ARC)",
	TARGZ   => "\$(EXE_GUNZIP) -c < \$(ARC) 2>/dev/null | \$(EXE_TAR) xf - -C \$(DIR) >/dev/null 2>\&1",
	WGET    => "\$(EXE_WGET)  -r -L -q -m -nH -np --execute=\"robots=off\" --cut-dirs=\$(CUTDIRS) \$(URL)",
	SENDMAIL => "\$(EXE_SENDMAIL) -oi -t -odb --"
);

my %archiveexts = (
	"ZIP"    =>  ".zip",
	"TARGZ"  =>  ".tar.gz"
);


$systemsettings{"invocation"} = \%invocsettings;
$systemsettings{"archive_extensions"} = \%archiveexts;
$systemsettings{"archives"} = ("ZIP", "TARGZ");
$systemsettings{"version"} = "2.0.a.2001-09-04";
$systemsettings{"version_desc"} = "EPrints 2.0 Alpha (Nightly Build 2001-09-04)";
$exesettings{"unzip"} 	= detect("unzip", @paths);
$exesettings{"wget"} 	= detect("wget", @paths);
$exesettings{"sendmail"} = detect("sendmail", @paths);
$exesettings{"gunzip"} 	= detect("gunzip", @paths);
$exesettings{"tar"} 	= detect("tar", @paths);

$systemsettings{"executable"} = \%exesettings;
$systemsettings{"version"} = $version;
$systemsettings{"version_desc"} = $version_desc;
print <<DIR;
EPrints installs by default to the /opt/eprints directory. If you
would like to install to a different directory, please specify it
here.

DIR

my $dirokay = 0;
my $dir = "";
while (!$dirokay)
{
	$dir = get_string('[\/a-zA-Z0-9_]+', "Directory", "/opt/eprints");
	
	if (-e $dir)
	{
		if (-e "$dir/VERSION")
		{
			# Handle versions 
		}
		else
		{
			print <<DIRWARN;
This directory already exists, and does not appear to contain a version
of EPrints. Do you really want to install in here?

DIRWARN
		my $conf = get_yesno("Sure?", "n");
		if ($conf eq "y") { $dirokay = 1; }	
		}
	}
	else
	{
		$dirokay = 1;
	}
}
$systemsettings{"base_path"} = $dir;

print <<USER;
EPrints must be run as a non-root user (typically 'eprints').
Please specify the user that you wish to use, or press enter to use
the default.

USER

my $user = get_string('[a-zA-Z0-9_]+', "User", "eprints");

# Check to see if user exists.
my $exists = 1;
my(undef, undef, $ruid, $rgid) = getpwnam($user) or $exists = 0;
my($name, $ugid) = getgrnam($user);
my $group = "";
if (!$exists)
{
	print <<GROUP;
User $user does not currently exist, so a group will be required
before it can be created. Please specify the group you would like
to use.

GROUP
	$group = get_string('[a-zA-Z0-9_]+', "Group", "eprints");
	my $gexists = 1;
	getgrnam($group) or $gexists = 0;

	if (!$gexists)
	{
		print "Creating group ... ";
		if (system("/usr/sbin/groupadd $group")==0)
		{
			print "OK.\n\n";
		}
		else
		{
			print "Failed!\n";
			print "Unable to create EPrints group: $!\n";
			exit 1;
		}
	}

	print "Creating user ... ";
	if (system("/usr/sbin/useradd -s /bin/false -d $dir -g $group $user")==0)
	{
		print "OK.\n\n";
	} 
	else
	{
		print "Failed!\n";
		print "Unable to create EPrints user: $!\n";
		exit 1;
	}
}

print "\nMaking directory ... ";
if (!-d $dir && !mkdir($dir))
{
	print "Failed!\n";
	print "Unable to make installation directory.\n";
	exit 1;
}
else
{ print "OK.\n\n"; }

print "Installing files : [";

my(undef,undef,$uid,$gid) = getpwnam($user);
my @executable_dirs = ("bin", "cgi");
my @normal_dirs = ("defaultcfg", "cfg", "perl_lib", "phrases");

foreach(@executable_dirs)
{
	install($_, 0755, $uid, $gid, $dir);	
	print "|";
}

foreach(@normal_dirs)
{
	install($_, 0644, $uid, $gid, $dir);
	print "|";
}

print "]\n\n";

use Data::Dumper;
$Data::Dumper::Indent = 3;
print Dumper(\%systemsettings);

sub install
{
	my($dir, $perms, $user, $group, $dest) = @_;
	opendir(INDIR, $dir) or die("Unable to install directory: $dir");
	my @dirs = ();
	my @files = ();
	my $currdir = getcwd();
	mkdir("$dest/$dir", 0755);
	while(my $item = readdir(INDIR))
	{
		if ($item =~ /^\./ && $item ne ".htaccess" ) { next; }
		if (-d "$currdir/$dir/$item") { push(@dirs, $item); }
		else { push(@files, $item); }
	}
	closedir(INDIR);
	foreach(@files)
	{
		open(INFILE, "$currdir/$dir/$_");
		open(OUTFILE, ">$dest/$dir/$_") or die "Can't write to $dest/$dir/$_";
		while(my $line=<INFILE>)
		{
			print OUTFILE $line;
		}		
		close(OUTFILE);
		close(INFILE);
		if ($_ ne ".htaccess")
		{
			chmod($perms, "$dest/$dir/$_");
		}
		else
		{
			chmod(0644, "$dest/$dir/$_");
		}
		chown($user, $group, "$dest/$dir/$_");
	}
	foreach(@dirs)
	{
		print "|";
		install("$dir/".$_, $perms, $user, $group, $dest);
	}
}

sub get_yesno
{
	my($question, $default) = @_;
	my($response) = "";

	# Sanity check
	unless ($default =~ /[yn]/i) { $default = "n"; }
	print "$question [$default] ";
	# Get response and set to default if necessary.
	$response = <STDIN>;
	chomp($response);
	if ($response !~ /[yn]/i) { $response = $default; }

	return $response;
}

sub get_string
{
	my($regexp, $question, $default) = @_;
	my($response) = "";
	do
	{
		print "$question [$default] :";
		# Get response and set to default if necessary.
		$response = <STDIN>;
		chomp($response);
		if ($response eq "") { $response = $default; }
	} while ($response !~ m/^$regexp$/);
	return $response;
}

sub find_file
{
	my($findme, @paths) = @_;
	my @searchpaths = split(/:+/, $ENV{"PATH"});
	push @searchpaths, @paths;
	my @found = ();
	my $curritem;
	foreach my $path (@searchpaths)
	{
		$path =~ s/(.+)\/$/$1/;
		opendir(DIR, $path) or next;
		while ($curritem = readdir(DIR))
		{
			next if ($curritem =~ /^\.[\.]?$/);
			if ($curritem eq $findme)
			{
				push @found, "$path/$curritem";
			}
		}
		closedir(DIR);
	}
	return @found;
}

sub detect
{
	my($todetect, @path) = @_;
	print "Detecting $todetect ... ";
	my @paths = find_file($todetect, @path);
	my $found = $paths[0];

	if (defined($found))
	{
		print "Found [".$found."]\n";
	}
	else
	{
		print "Not found!\n\n";
		while (!defined($found))
		{
			print "Couldn't locate $todetect. Please specify the path to this file.\n";
			my $path = get_string("[a-zA-Z0-9_\/]+", "Path", "");
			if (!-e $path) { $found = undef; }
			else { $found = $path; }
		}
	}
	return $found
}
