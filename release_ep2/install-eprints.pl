#!/usr/bin/perl -w

######################################################################
#
# EPrints 2 installer : Handles upgrading, simple command detection,
# and the creation of the SystemSettings.pm file. This doesn't do the
# mySQL install, etc. - you'll need the SuperInstaller for that.
#
######################################################################
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
######################################################################

use strict;
use Cwd;

my $forced = 0;
if (defined($ARGV[0]))
{
	$forced = ($ARGV[0] eq "--force");
}

print <<INTRO;

EPrints 2 Installer
-------------------

This installer creates the necessary directories and files for 
you to begin configuring EPrints 2.

INTRO

if ($forced)
{
	print <<WARNING;
*** WARNING ***

Running as non-root will skip the following:
- No user/group creation will be attempted
- No chowning will be attempted

WARNING
}
print "Checking user ... ";
if ($<!=0 && !$forced)
{
	print <<END;
Failed!  This installer must be run as root.

You may use the --force to run as a user other than root.

Running as non-root will skip the following:
- No user/group creation will be attempted
- No chowning will be attempted

END
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
	zip     => '$(zip) 1>/dev/null 2>&1 -qq -o -d $(DIR) $(ARC)',
	targz   => '$(wget) -c < $(ARC) 2>/dev/null | $(tar) xf - -C $(DIR) >/dev/null 2>&1',
	wget    => '$(wget)  -r -L -q -m -nH -np --execute="robots=off" --cut-dirs=$(CUTDIRS) $(URL)',
	sendmail => '$(sendmail) -oi -t -odb --'
);

my %archiveexts = (
	"zip"    =>  ".zip",
	"targz"  =>  ".tar.gz"
);


$systemsettings{"invocation"} = \%invocsettings;
$systemsettings{"archive_extensions"} = \%archiveexts;
$systemsettings{"archive_formats"} = ["zip", "targz"];
$systemsettings{"version"} = "2.0.a.2001-09-04";
$systemsettings{"version_desc"} = "EPrints 2.0 Alpha (Nightly Build 2001-09-04)";
$exesettings{"unzip"} 	= detect("unzip", @paths);
$exesettings{"wget"} 	= detect("wget", @paths);
$exesettings{"sendmail"} = detect("sendmail", @paths);
$exesettings{"gunzip"} 	= detect("gunzip", @paths);
$exesettings{"tar"} 	= detect("tar", @paths);
my $useradd = detect("useradd", @paths);
my $groupadd = detect("groupadd", @paths);

$systemsettings{"executables"} = \%exesettings;
$systemsettings{"version"} = $version;
$systemsettings{"version_desc"} = $version_desc;
print <<DIR;

EPrints installs by default to the /opt/eprints directory. If you
would like to install to a different directory, please specify it
here.

DIR

my $dirokay = 0;
my $dir = "";
my $upgrade = 0;
my $orig_version = "";
my $orig_version_desc = "";
while (!$dirokay)
{
	$dir = get_string('[\/a-zA-Z0-9_]+', "Directory", "/opt/eprints");
	
	if (-e $dir)
	{
		if (-e "$dir/perl_lib/EPrints/SystemSettings.pm")
		{
			require "$dir/perl_lib/EPrints/SystemSettings.pm" or die("Unable to detect SystemSettings module: Corrupt prevous install?");
			my $old_version = $EPrints::SystemSettings::conf{"version"};

			$systemsettings{"orig_version"} = $EPrints::SystemSettings::conf->{"orig_version"};
			$systemsettings{"orig_version_desc"} = $EPrints::SystemSettings::conf->{"orig_version_desc"};
			my $origv = $systemsettings{"orig_version"};
			my $newv = $systemsettings{"version"};	
			if (defined $origv && $origv gt $newv)
			{
				print <<DOWNGRADE;
You already have a version of EPrints installed in this directory and it
appears to be newer than the one that you are trying to install.

Please obtain the latest version of EPrints and try again.
DOWNGRADE
				exit 1;
			}
			elsif (defined $origv && $origv eq $newv)
			{
				print "You already have this version installed.\n";
				exit 1;
			}
			else
			{

				print <<UPGRADE;
You already have a version of EPrints installed in this directory which is
older than the one you are trying to install. Do you wish to upgrade?

UPGRADE
				if (get_yesno("Sure?", "n") eq "y") 
				{ 
					$dirokay = 1; 
					$upgrade = 1;
				}
				else { $dirokay = 0; }
			}
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

if (!$upgrade) { full_install(); }
else { upgrade(); }

use Data::Dumper;
my $dumper = Data::Dumper->new( [ \%systemsettings ] , [ 'EPrints::SystemSettings::conf' ] );
open(FILEOUT, ">$dir/perl_lib/EPrints/SystemSettings.pm") or die("Unable to output system settings.");
print FILEOUT <<SPIEL;
######################################################################
#
# These are your system settings (as autogenerated by the installer).
# We suggest that you do not alter these, as future installers will
# probably override them.
# 
######################################################################
#
# This file is part of EPrints 2.
#
# EPrints 2 is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# EPrints 2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with EPrints 2; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################

# This file should only be use'd by EPrints::Config
package EPrints::SystemSettings;

SPIEL

print FILEOUT $dumper->Dump();

print FILEOUT "\n1;";


close(FILEOUT);

sub full_install
{

	print <<USER;
EPrints must be run as a non-root user (typically 'eprints').
Please specify the user that you wish to use, or press enter to use
the default.
	
USER
	
	my $user = get_string('[a-zA-Z0-9_]+', "User", "eprints");
	
	# Check to see if user exists.
	my $exists = 1;
	my $group = "";
	my(undef, undef, $ruid, $rgid) = getpwnam($user) or $exists = 0;

	if ($exists)
	{
		($group, undef) = getgrnam($user);
	}

	if (!$forced && (!$exists || !defined($group)))
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
			if (system("$groupadd $group")==0)
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
		if (system("$useradd -s /bin/bash -d $dir -g $group $user")==0)
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
	$systemsettings{"user"} = $user;
	$systemsettings{"group"} = $group;	
	$systemsettings{"orig_version"} = $systemsettings{"version"}; # First time install
	$systemsettings{"orig_version_desc"} = $systemsettings{"version_desc"};
	my(undef,undef,$uid,$gid) = getpwnam($user);
	print "\nMaking directory ... ";
	if (!-d $dir && !mkdir($dir, 0755))
	{
		print "Failed!\n";
		print "Unable to make installation directory.\n";
		exit 1;
	}
	else
	{ print "OK.\n\n"; }
	if (!$forced) { chown($uid, $gid, "$dir") or die "Unable to chown $dir : $!"; }

	print "Installing files : [";

	my @executable_dirs = ("bin", "cgi");
	my @normal_dirs = ("archives", "sys", "defaultcfg", "cfg", "docs", "perl_lib", "phrases");

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

	print <<HOORAY;

==================================================
Hooray! Your EPrints2 installation was successful!
==================================================
=
= What Now?
=
= - su to root
= - Open your apache.conf file, and make the
=   following alterations:
=   o Add the line
=       Include $dir/cfg/apache.conf
=   o Replace the 'User <username>' line with
=       User $user
=   o Replace the 'Group <groupname>' line with
=       Group $group
= - su to $user
= - Move into $dir and run:
=     bin/generate_apacheconf
=     bin/create_new_archive
=
= Please note:
= You will also require a working sendmail configuration.
= This should just involve inserting the line
=
= DH<yourmailserver>
=
= in your sendmail.cf, where <yourmailserver> is your SMTP
= mail server address.
=   
= Good Luck!
=
==================================================
HOORAY
}

sub install
{
	my($dir, $perms, $user, $group, $dest) = @_;
	opendir(INDIR, $dir) or die("Unable to install directory: $dir. $!");
	my @dirs = ();
	my @files = ();
	my $currdir = getcwd();
	mkdir("$dest/$dir", 0755);
	if (!$forced) {chown($user, $group, "$dest/$dir") or die "Unable to chown $dest/$dir/$_ : $!"; }
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
		open(OUTFILE, ">$dest/$dir/$_") or die "Can't write to $dest/$dir/$_ : $!";
		if ($dir eq "bin")
		{
			if ($_ eq "startup.pl")
			{
				print OUTFILE "use lib '".$dest."/perl_lib';\n";
			}
			else
			{
				print OUTFILE "#!/usr/bin/perl -w -I".$dest."/perl_lib\n";
			}
			my $skipme = <INFILE>;	
		}
		while(my $line=<INFILE>)
		{
			print OUTFILE $line;
		}		
		close(OUTFILE);
		close(INFILE);
		chmod($perms, "$dest/$dir/$_") or die "Unable to chmod $dest/$dir/$_ : $!";
		if (!$forced) { chown($user, $group, "$dest/$dir/$_") or die "Unable to chown $dest/$dir/$_ : $!"; }
	}
	foreach(@dirs)
	{
		print "|";
		install("$dir/".$_, $perms, $user, $group, $dest);
	}
}

sub upgrade
{
	my $user = $EPrints::SystemSettings::conf->{"user"};
	my $dir  = $EPrints::SystemSettings::conf->{"base_path"};

	my(undef,undef,$uid,$gid) = getpwnam($user);
	
	print <<WARN;
Warning: This will overwrite phrase files, program files, and documentation.
If you've tweaked any of these, you may want to back them up before proceeding.
WARN

	exit if (get_yesno("Really upgrade?", "n") eq "n"); 

	print "Upgrading files : [";

        my @executable_dirs = ("bin", "cgi");
        my @normal_dirs = ("sys", "docs", "perl_lib", "phrases");

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
	print <<HOORAY;
=====
=
= Update successful. You should now restart your webserver and hope for the best.
=
=====

HOORAY
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

	return lc($response);
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
	return $found;
}
