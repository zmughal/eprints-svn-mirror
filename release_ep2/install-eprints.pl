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
use Digest::MD5;
my $forced = 0;
if (defined($ARGV[0]))
{
	$forced = ($ARGV[0] eq "--force");
}

print <<INTRO;

======================================================================
EPrints 2 Installer

This installer creates the necessary directories and files for 
you to begin configuring EPrints 2.
======================================================================

INTRO

my $non_root_warning = <<WARNING;
**********************************************************************
* WARNING 

Running as non-root will cause some stages to be skipped:
- No user/group creation will be attempted
- The file owner flags will not be specifically set

WARNING

if ($forced)
{
	print $non_root_warning;
}
print "Checking user ... ";
if ($<!=0 && !$forced)
{
	print <<END;
Failed!  This installer must be run as root.

You may use the --force to run as a user other than root.

END
	print $non_root_warning;
	exit 1;
}
else { print "OK.\n\n"; }

# Grab version id number from VERSION file.
open(VERSIONIN, "VERSION") or die "No VERSION file - invalid distribution?";
my $version_id = <VERSIONIN>;
if (!defined($version_id)) { die "Undefined version number."; }
chomp($version_id);
my $version = <VERSIONIN>;
if (!defined($version)) { die "Undefined version description."; }
chomp($version);
close(VERSIONIN);


my @paths = ("/bin/", "/usr/bin/", "/usr/local/bin/", "/usr/sbin/");
my @signatures = (); # MD5 signature store
my %exesettings = ();
my %systemsettings = ();

# Set up some default settings.
my %invocsettings = (
	zip     => '$(zip) 1>/dev/null 2>&1 -qq -o -d $(DIR) $(ARC)',
	targz   => '$(gunzip) -c < $(ARC) 2>/dev/null | $(tar) xf - -C $(DIR) >/dev/null 2>&1',
	wget    => '$(wget)  -r -L -q -m -nH -np --execute="robots=off" --cut-dirs=$(CUTDIRS) $(URL)',
	sendmail => '$(sendmail) -oi -t -odb --',
	latex => '$(latex) \'$(SOURCE)\'',
	dvips => '$(dvips) \'$(SOURCE)\' -o \'$(TARGET)\'',
	convert_crop_white => '$(convert) -crop 0x0 -bordercolor white -border 4x4 \'$(SOURCE)\' \'$(TARGET)\'' 
);

my %archiveexts = (
	"zip"    =>  ".zip",
	"targz"  =>  ".tar.gz"
);

print "Detecting required binaries:\n";
$exesettings{"unzip"} 	= detect("unzip", 1, @paths);
$exesettings{"wget"} 	= detect("wget", 1, @paths);
$exesettings{"sendmail"} = detect("sendmail", 1, @paths);
$exesettings{"gunzip"} 	= detect("gunzip", 1, @paths);
$exesettings{"tar"} 	= detect("tar", 1, @paths);
my $useradd = detect("useradd", 1, @paths);
my $groupadd = detect("groupadd", 1, @paths);
print "\nDetecting optional binaries:\n";
$exesettings{"latex"}	= detect("latex", 0, @paths);
$exesettings{"dvips"}	= detect("dvips", 0, @paths);
$exesettings{"convert"}	= detect("convert", 0, @paths);
my $h2ph = detect("h2ph", 0, @paths);

$systemsettings{"invocation"} = \%invocsettings;
$systemsettings{"archive_extensions"} = \%archiveexts;
$systemsettings{"executables"} = \%exesettings;
$systemsettings{"archive_formats"} = ["zip", "targz"];

$systemsettings{"version_id"} = $version_id;
$systemsettings{"version"} = $version;
print <<DIR;

EPrints 2 installs by default to the /opt/eprints2 directory. If you
would like to install to a different directory, please specify it
here.

DIR

my $dirokay = 0;
my $dir = "";
my $upgrade = 0;
my $newv;
my $oldv;
while (!$dirokay)
{
	$dir = get_string('[\/a-zA-Z0-9_]+', "Directory", "/opt/eprints2");
	
	if (-e $dir)
	{
		if (-e "$dir/perl_lib/EPrints/SystemSettings.pm")
		{
			require "$dir/perl_lib/EPrints/SystemSettings.pm" or die("Unable to detect SystemSettings module: Corrupt prevous install?");
			#my $old_version_id = $EPrints::SystemSettings::conf{"version_id"};
			# Current values take precedence.
			foreach(keys %$EPrints::SystemSettings::conf)
			{
				if (defined $systemsettings{$_})
				{
					$systemsettings{$_} = merge_fields($systemsettings{$_}, $EPrints::SystemSettings::conf->{$_});
				}
				else
				{
					$systemsettings{$_} = $EPrints::SystemSettings::conf->{$_};
				}
			}
			$systemsettings{"user"} = $EPrints::SystemSettings::conf->{"user"};
			$systemsettings{"group"} = $EPrints::SystemSettings::conf->{"group"};
			# Check to see if user exists.
			my $exists = 1;
			my $group = "";
			my(undef, undef, $ruid, $rgid) = getpwnam($systemsettings{"user"}) or $exists = 0;

			if ($exists)
			{
				($group, undef) = getgrnam($systemsettings{"user"});
			}

			if (!$forced && (!$exists || !defined($group)))
			{
				print <<GROUP;
User $systemsettings{"user"} does not currently exist, so a group will be required
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
					$systemsettings{"group"} = $group;
				}
	
				print "Creating user ... ";
				if (system("$useradd -s /bin/bash -d $dir -g $group ".$systemsettings{"user"})==0)
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
			
			$oldv = $EPrints::SystemSettings::conf->{"version_id"};
			$newv = $systemsettings{"version_id"};
			# 
			# Mild cheat to make sure 2.0.a is before 2.0, etc.
			$oldv =~ s/^2\.0\.a/0\.0\.0/;
			$newv =~ s/^2\.0\.a/0\.0\.0/;
			# Gently warn the user if Bad Things could happen.
			if ($oldv =~ /-[0-9]{4}-[0-9]{2}-[0-9]{2}$/)
			{
				# Upgrading CVS->CVS
				if ($newv =~ /-[0-9]{4}-[0-9]{2}-[0-9]{2}$/)
				{
					print <<WARNING_N2N;
*** Warning ***
You are upgrading from a nightly release to another nightly release. This
may cause weird things to happen!
*** Warning ***
				
WARNING_N2N
				}
				# Upgrading CVS->Stable
				else
				{
					print <<WARNING_N2S;
*** Warning ***
You are upgrading from a nightly release to a stable release. This
may cause weird things to happen!
*** Warning ***

WARNING_N2S
				}
			}
			# Upgrading Stable->CVS
			elsif ($newv =~ /-[0-9]{4}-[0-9]{2}-[0-9]{2}$/)
			{
				print <<WARNING_S2N;
*** Warning ***
You are upgrading from a stable release to a nightly release. This
may cause weird things to happen!
*** Warning *** 

WARNING_S2N
			}

			if (defined $oldv && $oldv gt $newv) 
			{
				print <<DOWNGRADE;
You already have a version of EPrints installed in this directory and it
appears to be newer than the one that you are trying to install.

Please obtain the latest version of EPrints and try again.
DOWNGRADE
				exit 1;
			}
			elsif (defined $oldv && $oldv eq $newv)
			{
				print <<RECOVER;
You already have this version installed here. Would you like to recover the
installation (replace core binaries, documentation, etc)?

RECOVER
				if (get_yesno("Recover?", "n") eq "y")
				{
					$dirokay = 1;
					$upgrade = 1;
				}
				else { $dirokay = 0; }
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
my @foo = ();
if (defined @{$EPrints::SystemSettings::conf->{"version_history"}})
{
	@foo =  @{$EPrints::SystemSettings::conf->{"version_history"}};
}
push @foo, $newv;
$systemsettings{"version_history"} = \@foo;

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

sub merge_fields
{
	my($hash1, $hash2) = @_;
	my %outhash;
	my $type = ref $hash1;
	if($type eq "HASH")
	{
		# $hash1 takes precedence
		foreach(keys %$hash1)
		{
			$outhash{$_} = $hash1->{$_};
		}
		foreach(keys %$hash2)
		{
			$outhash{$_} = $hash2->{$_} unless defined $outhash{$_};
		}
		return \%outhash;
	}
	elsif($type eq "ARRAY")
	{
		if (defined $hash1)
		{
			foreach(@$hash1)
			{
				$outhash{$_} = 1 if defined $_;
			}
		}
		if (defined $hash2)
		{
			foreach(@$hash2)
			{
				$outhash{$_} = 1 if defined $_;
			}
		}
		return [keys %outhash];
	}
	else
	{
		return $hash1;
	}
	
}

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
	my @normal_dirs = ("archives", "defaultcfg", "cfg", "docs", "perl_lib");

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
	
	post_install($dir);

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
=     bin/configure_archive
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

sub detect_df 
{

	my $dir = "/";
	my ($fmt, $res);

	# try with statvfs..
	eval 
	{  
		{
			package main;
			require "sys/syscall.ph";
		}
		$fmt = "\0" x 512;
		$res = syscall (&main::SYS_statvfs, $dir, $fmt) ;
		$res == 0;
	}
	# try with statfs..
	|| eval 
	{ 
		{
			package main;
			require "sys/syscall.ph";
		}	
		$fmt = "\0" x 512;
		$res = syscall (&main::SYS_statfs, $dir, $fmt);
		$res == 0;
	}
}



# Post installation bits

sub post_install
{
	my($dir) = @_;
	print "All files installed.\n";
	print "Detecting df...";
	my $df_available = detect_df();
	if (!$df_available)
	{
		print " Not Found.\n";
		print <<END;

df is currently unavailable on your server. To enable it, the installer
can run 'h2ph * */*' in your /usr/include directory.
END
		my $doh2ph = get_yesno("Run h2ph", "n");
		if ($doh2ph eq "y")
		{
			my $currdir = getcwd();
			chdir("/usr/include/");
			system("$h2ph * */*");			
			chdir($currdir);
		}
		else
		{
			print "Please run this manually before running EPrints.\n";
		}
	}
	else
	{
		print " Detected.\n";  	
	}

	# Dump out signature file
	open (SIGOUT, ">$dir/SIGNATURES") or die "Unable to open SIGNATURES: $!";
	foreach(@signatures)
	{
		print SIGOUT $_;
	}
	close(SIGOUT);
}

# Calculate the MD5 digest of a file.

sub get_digest
{
	my($file) = @_;
	open(FILE, $file) or die "Can't open '$file': $!";
	my $outdigest = new Digest::MD5;
	foreach(<FILE>)
	{
		$outdigest->add($_);
	}
	close(FILE);
	return $outdigest->hexdigest;
}

# Install $file from directory $dir into $dest. The permissions
# from $perms are set, and the group and user are set from $group
# and $user. The %hash is used for MD5 comparisions - currently
# not doing anything active, but checking is enabled.

sub install_file
{
	my($file, $dir, $perms, $user, $group, $dest, %hash) = @_;
	my $currdir = getcwd();
	return unless (-e "$currdir/$dir/$file");
	my $outdigest = Digest::MD5->new;
	my @linesout = ();	
	my $currline = "";
	open(INFILE, "$currdir/$dir/$file");
	if ($dir eq "bin")
	{
		if ($file eq "startup.pl")
		{
			$currline = "use lib '".$dest."/perl_lib';\n";
			$outdigest->add($currline);
			push @linesout, $currline;
		}
		else
		{
			$currline = "#!/usr/bin/perl -w -I".$dest."/perl_lib\n";
			$outdigest->add($currline);
			push @linesout, $currline;
		}
		my $skipme = <INFILE>;	
	}
	while(my $line=<INFILE>)
	{
		chomp $line; 
		$currline = "$line\n";
		$outdigest->add($currline);
		push @linesout, $currline;
	}		
	close(INFILE);
	push @signatures, "$dir/$file ".$outdigest->hexdigest."\n";

	if ($hash{"$dir/$file"} && -e "$dest/$dir/$file")
	{
		my $repl_digest = get_digest("$dest/$dir/$file");
		if ($repl_digest ne $hash{"$dir/$file"})
		{
			rename "$dest/$dir/$file", "$dest/$dir/$file.old";		
		}
	}

	open(OUTFILE, ">$dest/$dir/$file") or die "Can't write to $dest/$dir/$file : $!";	foreach(@linesout)
	{
		print OUTFILE $_;
	}	
	close(OUTFILE);

	chmod($perms, "$dest/$dir/$file") or die "Unable to chmod $dest/$dir/$file : $!";
	if (!$forced) { chown($user, $group, "$dest/$dir/$file") or die "Unable to chown $dest/$dir/$file : $!"; }
}

sub install
{
	my($dir, $perms, $user, $group, $dest, %hash) = @_;
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
		install_file($_, $dir, $perms, $user, $group, $dest, %hash);
	}
	foreach(@dirs)
	{
		print "|";
		$|=1;
		install("$dir/".$_, $perms, $user, $group, $dest);
	}
}

sub upgrade
{
	my $user = $EPrints::SystemSettings::conf->{"user"};
	my $dir  = $EPrints::SystemSettings::conf->{"base_path"};

	my(undef,undef,$uid,$gid) = getpwnam($user);
	my $checkMD5s = 0;
	my $digest;
	my $file;
	my %MD5Hash = ();
	# If we have a digest file, read the digests into a hash
	if (-e "$dir/SIGNATURES")
	{
		print "Loading SIGNATURES...\n";
		open(MD5IN, "$dir/SIGNATURES");
		foreach(<MD5IN>)
		{
			chomp;
			($file, $digest) = split(" ", $_);
			$MD5Hash{$file} = $digest;
		}
		close(MD5IN);
	}
	
	print <<WARN;
Warning: This will overwrite phrase files, program files, and documentation.
If you've tweaked any of these, you may want to back them up before proceeding.
WARN

	exit if (get_yesno("Really upgrade?", "n") eq "n"); 

	print "Upgrading files : [";

        my @executable_dirs = ("bin", "cgi");
	my @normal_dirs = ("defaultcfg", "cfg", "docs", "perl_lib");
	my @base_files = ("VERSION", "CHANGELOG", "BUGLIST", "COPYING"); 
        foreach(@executable_dirs)
        {
                install($_, 0755, $uid, $gid, $dir, %MD5Hash);
                print "|";
		$|=1;
        }

        foreach(@normal_dirs)
        {
                install($_, 0644, $uid, $gid, $dir, %MD5Hash);
                print "|";
		$|=1;
        }

	foreach(@base_files)
	{
		install_file($_, "", 0644, $uid, $gid, $dir, %MD5Hash);
	}

        print "]\n\n";

	post_install($dir);

	print <<HOORAY;
=====
=
= Update successful. You should now re-run bin/generate_apacheconf, and restart
= your web server.
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
	my($todetect, $compulsory, @path) = @_;
	print "Detecting $todetect ... ";
	my @paths = find_file($todetect, @path);
	my $found = $paths[0];

	if (defined($found))
	{
		print "Found [".$found."]\n";
	}
	elsif($compulsory)
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
	elsif(!$compulsory)
	{
		print "Not found\n\n";
		$found = undef;
	}
	return $found;
}
