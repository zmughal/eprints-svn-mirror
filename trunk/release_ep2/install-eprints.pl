#!/usr/bin/perl -w

use strict;
use Cwd;
print <<INTRO;
EPrints 2 Installer
-------------------

This installer creates the necessary directories and files for 
you to begin configuring EPrints 2.

INTRO

print "Checking user...";
if (0) #($<!=0) -- removed while testing.
{
	print "Failed!\n";
	print "Sorry, his installer must be run as root.\n";
	exit 1;
}
else { print "OK.\n\n"; }

print <<DIR;
EPrints installs by default to the /opt/eprints directory. If you
would like to install to a different directory, please specify it
here.

DIR

my $dir = get_string("Directory", "/opt/eprints");
print <<USER;
EPrints must be run as a non-root user (typically 'eprints').
Please specify the user that you wish to use, or press enter to use
the default.

USER

my $user = get_string("User", "eprints");

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
	$group = get_string("Group", "eprints");
	my $gexists = 1;
	getgrnam($group) or $gexists = 0;

	if (!$gexists)
	{
		print "Creating group...";
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

	print "Creating user...";
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

print "\nMaking directory...";
if (!mkdir($dir))
{
	print "Failed!\n";
	print "Unable to make installation directory.\n";
	exit 1;
}
else
{ print "OK.\n\n"; }

print "Installing files...\n";

my(undef,undef,$uid,$gid) = getpwnam($user);
my @executable_dirs = ("bin", "cgi");
my @normal_dirs = ("defaultcfg", "cfg", "perl_lib", "phrases");

foreach(@executable_dirs)
{
	install($_, 0755, $uid, $gid, $dir);	
}

foreach(@normal_dirs)
{
	install($_, 0644, $uid, $gid, $dir);
}


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
		if ($item =~ /^\./) { next; }
		if (-d "$currdir/$dir/$item") { push(@dirs, $item); }
		else { push(@files, $item); }
	}
	closedir(INDIR);
	foreach(@files)
	{
		print "Install $_\n";
		open(INFILE, "$currdir/$dir/$_");
		open(OUTFILE, ">$dest/$dir/$_") or die "Can't write to $dest/$dir/$_";
		while(my $line=<INFILE>)
		{
			print OUTFILE $line;
		}		
		close(OUTFILE);
		close(INFILE);
		chmod($perms, "$dest/$dir/$_");
		chown($user, $group, "$dest/$dir/$_");
		# Copy and stuff.
	}
	foreach(@dirs)
	{
		print "Go into $_\n";
		
		install("$dir/".$_, $perms, $user, $group, $dest);
	}
}

sub get_string
{
	my($question, $default) = @_;
	my($response) = "";
	
	print "$question [$default] :";
	# Get response and set to default if necessary.
	$response = <STDIN>;
	chomp($response);
	if ($response eq "") { $response = $default; }
	return $response;
}
