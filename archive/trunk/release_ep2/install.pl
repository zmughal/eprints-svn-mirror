#!/usr/bin/perl

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

my %c;
$c{"dist_path"}="/home/cjg/Projects/eprints/release_ep2";
$c{"perl"}="/usr/bin/perl";
$c{"prefix"}="/opt/eprints2";
$c{"user"}="eprints";
$c{"group"}="eprints";
$c{"disable_df"}=0;
$c{"virtualhost"}="";

$c{"unzip"}="/usr/bin/unzip";
$c{"tar"}="/bin/tar";
$c{"gunzip"}="/bin/gunzip";
$c{"wget"}="/home/cjg/bin/wget";
$c{"sendmail"}="/usr/sbin/sendmail";
$c{"latex"}="/usr/bin/latex";
$c{"dvips"}="/usr/bin/dvips";
$c{"convert"}="/usr/bin/X11/convert";

$c{"enable_gdome"}="0";

######################################################################

use strict;
use Cwd;
use Digest::MD5;
use Data::Dumper;

#
# Grab version id number from VERSION file.
#

unless( open(VERSIONIN, $c{"dist_path"}."/VERSION") )
{
	print "No VERSION file in distribution - invalid distribution?";
	exit 1;
}
my $version_id = <VERSIONIN>;
unless( defined($version_id) ) 
{
	print "Undefined version number.";
	exit 1;
}
chomp($version_id);
my $version = <VERSIONIN>;
unless( defined($version) ) 
{
	print "Undefined version description."; 
	exit 1;
}
chomp($version);
close(VERSIONIN);

### Trim perfix if needed 

if( $c{"prefix"} =~ s#/$## )
{
	print "Removing trailing slash from prefix.\n";
}

### Print out some key information, which is bound to
### cause problems if incorrect.

print "Installing from: ".$c{"dist_path"}."\n";
print "Installing/Upgrading to: ".$c{"prefix"}."\n";
print "as user: ".$c{"user"}."\n";
print "as group: ".$c{"group"}."\n";

my $systemsettings = {};

$systemsettings->{"version_history"} = [ $version_id ];

#
# Set up some default settings.
#
$systemsettings->{"invocation"} = {
	zip     => '$(unzip) 1>/dev/null 2>&1 -qq -o -d $(DIR) $(ARC)',
	targz   => '$(gunzip) -c < $(ARC) 2>/dev/null | $(tar) xf - -C $(DIR) >/dev/null 2>&1',
	wget    => '$(wget)  -r -L -q -m -nH -np --execute="robots=off" --cut-dirs=$(CUTDIRS) $(URL)',
	sendmail => '$(sendmail) -oi -t -odb --',
	latex => '$(latex) \'$(SOURCE)\'',
	dvips => '$(dvips) \'$(SOURCE)\' -o \'$(TARGET)\'',
	convert_crop_white => '$(convert) -crop 0x0 -bordercolor white -border 4x4 \'$(SOURCE)\' \'$(TARGET)\'' 
};

$systemsettings->{"archive_extensions"} = {};
$systemsettings->{"archive_formats"} = [];
if( $c{"unzip"} ne "" )
{
	$systemsettings->{"archive_extensions"}->{"zip"} = ".zip" ;
	push @{$systemsettings->{"archive_formats"}},"zip";
}
if( $c{"tar"} ne "" && $c{"gunzip"} ne "" )
{
	$systemsettings->{"archive_extensions"}->{"targz"} = ".tar.gz" ;
	push @{$systemsettings->{"archive_formats"}},"targz";
}

$systemsettings->{"executables"} = {};
foreach( 
	"unzip", "tar", "gunzip", "wget", 
	"sendmail", "latex", "dvips", "convert" )
{
	next unless( defined $c{$_} );
	$systemsettings->{"executables"}->{$_} = $c{$_};
}

$systemsettings->{"disable_df"} = $c{"disable_df"};
$systemsettings->{"virtualhost"} = $c{"virtualhost"};

my $upgrade = 0;

my $syssettings = $c{prefix}."/perl_lib/EPrints/SystemSettings.pm";

if( -e $syssettings )
{
	print "Previous install detected at prefix. Upgrading.\n";
	unless( require $syssettings )
	{
		print <<END;
Failed to read previous values from system settings file:
$syssettings - Aborting.
END
		exit 1;
	}

	print "Previous version of eprints is: ";
	print $EPrints::SystemSettings::conf->{"version_id"}."\n";

	# create a minimal version history if there was not one already
	if( !defined $EPrints::SystemSettings::conf->{"version_history"} )
	{
		$EPrints::SystemSettings::conf->{"version_history"} =
			[ $EPrints::SystemSettings::conf->{"version_id"} ];
	}

	# Current values take precedence.
	foreach( keys %$EPrints::SystemSettings::conf )
	{
		if( defined $systemsettings->{$_} )
		{
			$systemsettings->{$_} = merge_fields(
				$EPrints::SystemSettings::conf->{$_}, 
				$systemsettings->{$_} );
		}
		else
		{
			$systemsettings->{$_} = 
				$EPrints::SystemSettings::conf->{$_};
		}
	}
	$systemsettings->{"user"} = $EPrints::SystemSettings::conf->{"user"};
	$systemsettings->{"group"} = $EPrints::SystemSettings::conf->{"group"};

	$upgrade = 1;
}
else
{	
	$systemsettings->{"user"} = $c{"user"};
	$systemsettings->{"group"} = $c{"group"};
	$systemsettings->{"base_path"} = $c{"prefix"};
}

$systemsettings->{"version_id"} = $version_id;
$systemsettings->{"version"} = $version;

if( defined $c{"enable_gdome"} && $c{"enable_gdome"} )
{
	$systemsettings->{"enable_gdome"} = 1;
}

if( !defined $systemsettings->{"enable_gdome"} )
{
	$systemsettings->{"enable_gdome"} = 0;
}

unless( getpwnam($systemsettings->{"user"}) )
{
	print "User ".$c{"user"}." does not exist. Aborting.\n";
	print "Consult your operating system documentation for how to create a new user.\n";
	print "Under Linux /usr/sbin/useradd is possibly what you need.\n";
	exit 1;
}

unless( getgrnam($systemsettings->{"group"}) )
{
	print "Group ".$c{"group"}." does not exist. Aborting.\n";
	print "Consult your operating system documentation for how to create a new group.\n";
	print "Under Linux /usr/sbin/groupadd is possibly what you need.\n";
	exit 1;
}

if( $upgrade )
{
	&upgrade( 
		$systemsettings->{base_path}, 
		$c{dist_path},
		$systemsettings->{user}, 
		$systemsettings->{group} );
}
else
{
	&full_install( 
		$systemsettings->{base_path}, 
		$c{dist_path},
		$systemsettings->{user}, 
		$systemsettings->{group} );
}

save_settings( $syssettings, $systemsettings );

exit;






sub save_settings
{
	my( $sysfile, $syshash ) = @_;

	my $dumper = Data::Dumper->new( 
		[ $syshash ] , 
		[ 'EPrints::SystemSettings::conf' ] );

	print "Writing $sysfile\n";
	unless( open(FILEOUT, ">".$sysfile) )
	{
		print "Failed to write $sysfile\n";
		exit 1;
	}
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
}

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



#######################################

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

sub write_sigs
{
	my( $dir, $sigs ) = @_;

	# Dump out signature file
	unless( open (SIGOUT, ">".$dir."/SIGNATURES") )
	{
		print "Unable to write SIGNATURES: $!\n";
		exit 1;
	}
		
	foreach(@{$sigs})
	{
		print SIGOUT $_;
	}
	close(SIGOUT);
}

# Calculate the MD5 digest of a file.

sub get_digest
{
	my($file) = @_;
	unless( open(FILE, $file) )
	{
		print "Can't open '$file': $!\n";
		exit 1;
	}
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
	my($distdir, $file, $dir, $perms, $user, $group, $dest, $sighash, $newsigs ) = @_;

	return unless (-e $distdir."/$dir/$file");
	my $outdigest = Digest::MD5->new;
	my @linesout = ();	
	my $currline = "";
	open(INFILE, $distdir."/$dir/$file");
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
			$currline = "#!".$c{perl}." -w -I".$dest."/perl_lib\n";
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
	push @{$newsigs}, "$dir/$file ".$outdigest->hexdigest."\n";

	if ($sighash->{"$dir/$file"} && -e "$dest/$dir/$file")
	{
		my $repl_digest = get_digest("$dest/$dir/$file");
		if ($repl_digest ne $sighash->{"$dir/$file"})
		{
			rename "$dest/$dir/$file", "$dest/$dir/$file.old";
			print "\n$dir/$file has been modified.\nSaving old version as $dir/$file.old\n";
		}
	}

	unless( open(OUTFILE, ">$dest/$dir/$file") )
	{
		print "\nCan't write to $dest/$dir/$file : $!\n";
		exit 1;
	}
	foreach(@linesout)
	{
		print OUTFILE $_;
	}	
	close(OUTFILE);

	unless( chmod($perms, "$dest/$dir/$file") )
	{
		print "\nUnable to chmod $dest/$dir/$file : $!\n";
		exit 1;
	}
	unless( chown($user, $group, "$dest/$dir/$file") )
	{
		print "\nUnable to chown $dest/$dir/$file : $!\n";
		exit 1;
	}
}

sub install_dir
{
	my( $distdir, $dir, $perms, $user, $group, $dest, $sighash, $newsigs ) = @_;
	unless( opendir(INDIR, $dir) )
	{
		print "Unable to install directory: $dir. $!\n";
		exit 1;
	}
	my @dirs = ();
	my @files = ();
	mkdir("$dest/$dir", 0755);
	unless( chown($user, $group, "$dest/$dir") )
	{
		print "\nUnable to chown $dest/$dir : $!\n"; 
		exit 1;
	}

	while(my $item = readdir(INDIR))
	{
		next if( $item eq "." || $item eq ".." );
		if( -d $distdir."/$dir/$item" ) 
		{ 
			push(@dirs, $item); 
		}
		else 
		{ 
			push(@files, $item); 
		}
	}
	closedir(INDIR);
	foreach(@files)
	{
		install_file($distdir, $_, $dir, $perms, $user, $group, $dest, $sighash, $newsigs );
	}
	foreach(@dirs)
	{
		print "|";
		$|=1;
		install_dir($distdir, "$dir/".$_, $perms, $user, $group, $dest, $sighash, $newsigs );
	}
}

##############################################################

sub upgrade
{
	my( $base_path, $dist_path, $user, $group ) = @_;

	my(undef,undef,$uid,$gid) = getpwnam($user);
	my $checkMD5s = 0;
	my $digest;
	my $file;
	my %MD5Hash = ();
	# If we have a digest file, read the digests into a hash
	if (-e "$base_path/SIGNATURES")
	{
		print "Loading SIGNATURES...\n";
		open(MD5IN, "$base_path/SIGNATURES");
		foreach(<MD5IN>)
		{
			chomp;
			($file, $digest) = split(" ", $_);
			$MD5Hash{$file} = $digest;
		}
		close(MD5IN);
	}
	
	print "Upgrading files : [";

	my $newsigs = [];

        my @executable_dirs = ("bin", "cgi");
	my @normal_dirs = ("defaultcfg", "cfg", "docs", "perl_lib");
	my @base_files = ("VERSION", "CHANGELOG", "BUGLIST", "COPYING", "NEWS", "AUTHORS", "TODO", "README" ); 
        foreach(@executable_dirs)
        {
                install_dir($dist_path, $_, 0755, $uid, $gid, $base_path, \%MD5Hash, $newsigs);
                print "|";
		$|=1;
        }

        foreach(@normal_dirs)
        {
                install_dir($dist_path, $_, 0644, $uid, $gid, $base_path, \%MD5Hash, $newsigs);
                print "|";
		$|=1;
        }

	foreach(@base_files)
	{
		install_file($dist_path, $_, "", 0644, $uid, $gid, $base_path, \%MD5Hash, $newsigs );
	}

        print "]\n\n";

	write_sigs( $base_path, $newsigs );

	print <<HOORAY;
======================================================================

 Upgrade successful. You should now:

 - su to $user
 - make any changes described by the "updating" chapter of
   the documentation.
 - re-run bin/generate_apacheconf (the just-installed version, 
   not the version that came in the tar.gz.
 - restart your web server

======================================================================

HOORAY
}


sub full_install
{
	my( $base_path, $dist_path, $user, $group ) = @_;

	my(undef,undef,$uid,$gid) = getpwnam($user);

	print "\nMaking directory ... ";
	if( !-d $base_path && !mkdir($base_path, 0755) )
	{
		print "Unable to make installation directory.\n";
		print "Aborting!\n";
		exit 1;
	}
	unless( chown($uid, $gid, $base_path) )
	{
		print "Unable to chown ".$base_path." : $!\n"; 
		print "Aborting!\n";
		exit 1;
	}

	print "Installing files : [";

	my @executable_dirs = ("bin", "cgi");
	my @normal_dirs = ("archives", "defaultcfg", "cfg", "docs", "perl_lib");

	my $sigs = ();

	foreach(@executable_dirs)
	{
		install_dir($dist_path, $_, 0755, $uid, $gid, $base_path, {}, $sigs );	
		print "|";
	}
	
	foreach(@normal_dirs)
	{
		install_dir($dist_path, $_, 0644, $uid, $gid, $base_path, {}, $sigs );
		print "|";
	}
	
	print "]\n\n";
	
	write_sigs( $base_path, $sigs );

	print <<HOORAY;

======================================================================
Hooray! Your EPrints2 installation was successful!
======================================================================

 What Now?

 - su to root
 - Open your apache.conf file, and make the
   following alterations:
   o Add the line
       Include $base_path/cfg/apache.conf
   o Replace the 'User <username>' line with
       User $user
   o Replace the 'Group <groupname>' line with
       Group $group
 - su to $user
 - Move into $base_path and run:
     bin/generate_apacheconf
     bin/configure_archive

 Please note:
 You will also require a working sendmail configuration.
 This should just involve inserting the line

 DH<yourmailserver>

 in your sendmail.cf, where <yourmailserver> is your SMTP
 mail server address.
   
 Good Luck!

======================================================================
HOORAY
}
