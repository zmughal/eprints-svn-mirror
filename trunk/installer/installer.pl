#!/usr/bin/perl -w

use Getopt::Long;
use Cwd;

require "installer-config.pl";

sub get_yesno
{
	my($question, $default) = @_;
	my($response) = "";	

	# Sanity check
	unless ($default =~ /[yn]/i) { $default = "n"; }
	print "$question [$default] ";
	if (!$ENVIRONMENT{automate_install})
	{
		# Get response and set to default if necessary.
		$response = <STDIN>;
		chomp($response);
	}
	else
	{
		print $default."\n";
	}
	if ($response !~ /[yn]/i) { $response = $default; }

	return $response;
}

sub get_string
{
	my($question, $default) = @_;
	my($response) = "";

	print "$question [$default] :";
	if (!$ENVIRONMENT{automate_install})
	{	
		# Get response and set to default if necessary.
		$response = <STDIN>;
		chomp($response);
	}
	else
	{
		print $default."\n";
	}
	if ($response eq "") { $response = $default; }
	return $response;
}

sub get_module_version
{
	my($mod) = @_;
	my $var;
	if (module_installed($mod))
	{
		$var = $mod."::VERSION";
		return $$var;
	}
	return 0;
}

sub module_installed
{
	 
	return eval("require $_[0]"); 
}

#sub compare_version
#{
#	my( $a, $b ) = @_;
#	my $ahead;
#	my $bhead;
#	$a = "0" if( !defined $a || $a eq "" );
#	$b = "0" if( !defined $b || $b eq "" );
#		
#	my( @a ) = split '\.', $a;
#	my( @b ) = split '\.', $b;
#
#	for(;;)
#	{
#		return 0 if( scalar @a == 0 && scalar @b == 0 );
#		$ahead = splice( @a, 0, 1);
#		$ahead = 0 if( !defined $ahead );
#		$bhead = splice( @b, 0, 1);
#		$bhead = 0 if( !defined $bhead );
#		return 1 if ($ahead > $bhead);
#		return -1 if ($ahead < $bhead);
#	}
#}		

sub get_library_paths
{
	my($searchstring) = @_;
	my %is_checked = ();
	my @out = ();
	my $line;
	# Linux-specific: Grab the /etc/ld.so.conf file, and put the paths in the hash.
	if (open(LDSOIN, "/etc/ld.so.conf"))
	{
		while($line = <LDSOIN>)
		{
			chomp($line);
			$line =~ s/\/$//;
			$is_checked{$line} = 0;
		}
		close(LDSOIN);
	}
	
	# Get the list of user-defined libraries and add them to our list.
	my (@userfields) = split(/:+/, $ENVIRONMENT{library_paths});
	foreach (@userfields)
	{
		s/\/$//;
		$is_checked{$_} = 0;
	}
	
	if (defined $ENV{"LD_LIBRARY_PATH"})
	{
		# And the same for the LD_LIBRARY_PATHs
		@userfields = split(/:+/, $ENV{"LD_LIBRARY_PATH"});
		foreach (@userfields)
		{
			s/\/$//;
			$is_checked{$_} = 0;
		}	
	}
	
	# Done, now search through these directories for the library.
	my $libname = "";
	foreach(keys %is_checked)
	{
		while (defined($libname = <$_/*$searchstring*.so>))
		{
			if ($libname =~ /$searchstring/)
			{
				push(@out, $libname);
			}
		}
	}
	
	return @out;
}

sub get_package_name
{
	my($info) = @_;
	my $okay = 0;
		
	do
	{
		print "Please specify the path of a valid ".$info->{long_name}." package, or leave blank to exit install.\n";
		my $path = get_string("Path?" , "");
		if ($path eq "") 
		{
			exit_nicely();
		}
		else
		{
			if (-e $path && $path =~ $_->{search_string})
			{
				my $this_version = make_version($1, $2, $3);
				if ($this_version lt $_->{min_version})
				{
					print "That version is too old. Please try again.\n";
					$okay = 0;
				}		
				else
				{	
					$ENVIRONMENT{$_->{name}."_installed"} = 0;
					$_->{version} = $this_version;
					$_->{archive} = $path;
					$okay = 1;
				}
			}
			else
			{
				$okay = 0;
				print "That is not a valid path. Please try again.\n\n";
			}
		}
	}
	until($okay);
}

sub do_install
{
my $pname;
my $pdesc;
format DESC =
-------------------------------------------
Package: @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
         $pname
-------------------------------------------
~~ ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
   $pdesc
-------------------------------------------
.

format DESC_BOTTOM =
-------------------------------------------

.
	foreach (@PACKAGES)
	{
		if (defined $ENVIRONMENT{$_->{name}."_installed"}) { next; } 
		my $old = $~;
		$~ = 'DESC';
		my $funcname = "";
		if (defined $_->{install_method})
		{
			$funcname = $_->{install_method};
		}
		else
		{
			$funcname = $_->{name}."_install";
		}
		$pname = $_->{long_name};
		$pdesc = $_->{description};
		write;
		my $installed = &{$funcname}($_);
		if (!$installed)
		{
			print STDERR "Install failed.\n";
			exit_nicely();
		}
		$~ = 'DESC_BOTTOM';
		write;
		$~ = $old;
	}
}

sub get_packs
{
	# Set up any installed packages.

	print "Detecting installed packages	...";		
	my $arg;
	my $func;
	my @path = ();
	foreach (@PACKAGES)
	{
		if ( defined $ENVIRONMENT{$_->{name}."_installed"} && $ENVIRONMENT{$_->{name}."_installed"} > 0 ) { $ENVIRONMENT{$_->{name}."_skip"} = 1; next; }
		if ( defined $_->{check_method} )
		{
			my $check_string = $_->{check_method};
			if ($check_string =~ /^standardcheck\s+(\S+)\s*(\S+)?$/)
			{
				$func 	= "standardcheck";
				$arg 	= $1;
				if (defined $2)
				{
					@path = split(/:+/, $2);		
				}
			}
			elsif ($check_string =~ /^perlcheck\s+(\S+)$/)
			{
				$func 	= "perlcheck";
				$arg 	= $1;
			}
			else
			{
				print "Undefined check method for package $_->{name}.\n";
				exit_nicely();
			}
		}
		else
		{
			$func 	= $_->{name}."_check";
			$arg	 = "";
		}
		$versionout = &{$func}($arg,@path);
		if (defined $versionout && ($_->{min_version} le $versionout))
		{
			$ENVIRONMENT{$_->{name}."_installed"} = $versionout;
		}
	}

	my @targz = <*>;
	# Search in current directory
	my $file;
	my $thisversion;
	my $curr_version;
	foreach $file (@targz)
	{
		my $package;
		foreach $package (@PACKAGES)
		{
			if (defined $ENVIRONMENT{$package->{name}."_skip"}) { next; }
			if ($file =~ /$package->{search_string}/)
			{
				if (defined $1) { $thisversion = $1; } else { $thisversion = 0; }
				$thisversion .= ".$2" if (defined $2);
				$thisversion .= ".$3" if (defined $3);
				if (!defined $package->{version}) { $package->{version} = ""; }
				$curr_version = $package->{version};
				if ($thisversion gt $curr_version && $curr_version gt 0)
				{
					# Got a newer version
					$package->{version} = $thisversion;
					$package->{archive} = $file;
				}
				else
				{
					# Got our first version.
					$package->{version} = $thisversion;
					$package->{archive} = $file;
				}
			}
		}
	}
	print "	Done.\n\n";
	my $package;
	foreach $package (@PACKAGES)
	{
		if (defined $ENVIRONMENT{$package->{name}."_skip"}) { next; }
		my $curr_installed = $ENVIRONMENT{$package->{name}."_installed"};
		$curr_installed = "0" if (!defined $curr_installed);	
		my $ok = 0;
		my $installed_ok = 0;
		# First see if the currently installed version is okay...
		if ($curr_installed ge $package->{min_version})
		{
			print "You already have ".$package->{long_name}." installed, ";
			if ( $curr_installed ge $package->{min_version})
			{
				print "and it is sufficiently new.\n";
				$ok = 1;
				$installed_ok = 1;
			} 
			else
			{
				print "but it is older than the version required.\n";
				$ok = 0;
				$installed_ok = 0;
			}
		}
		# Otherwise see if a valid package has been found.
		elsif (defined $package->{archive} && $package->{archive} ne "")
		{
			print "Found a package for ".$package->{long_name}." ";
			if ($package->{version} ge $package->{min_version})
			{
				print "that is sufficiently new.\n";
				$ok = 1;
			}
			else
			{
				print "but it is older than the version required.\n";
				$ok = 0;
			}
		}
		else
		{
			print "Could not find a suitable package for ".$package->{long_name}.".\n";
			$ok = 0;
		}
		
		if (!$ok)
		{
			get_package_name(\%{$package});
			$ok = 1;
		}
		else
		{
			print "Would you like to use ";
			if ($installed_ok)
			{
				print "the installed package";
			}
			else
			{
				print $package->{archive};
			}
			print " as a valid ";
			if ($installed_ok) 
			{
				print "source";
			}
			else
			{
				print "archive";
			}
			
			print " for ".$package->{long_name}."?\n";
			my $usepkg = get_yesno("Use this package:", "y");
			
			if ($usepkg eq "n")
			{
				$installed_ok = 0;
				get_package_name(\%{$package});
				$ok = 1;
			}
		}
		
		print "\n";
	}
}

sub dump_environment
{
	open(RESFILE, ">".$ENVIRONMENT{resume_file}) || die "Unable to open resume file.\n";
	print RESFILE "%ENVIRONMENT = \n(\n";
	my $k;
	foreach $k (keys %ENVIRONMENT)
	{
		print RESFILE "$k	=> \"".$ENVIRONMENT{$k}."\",\n";
	}
	print RESFILE ");\n\n";
	print RESFILE "\@PACKAGES = \n(";
	my $package;
	foreach $package (@PACKAGES)
	{
		print RESFILE "{\n";
		my $pcginfo;
		foreach $pcginfo ($package)
		{
			foreach(keys %{$pcginfo})
			{
				print RESFILE $_." => \"".%{$pcginfo}->{$_}."\",\n";
			}
		}
		print RESFILE "},\n";
	}
	print RESFILE ");\n";
	close(RESFILE);
}
sub exit_nicely
{
	my($msg) = @_;
	if (defined $msg) { print $msg; }
	dump_environment();
	print STDERR <<WAH;
====== Bailing ======\n
Unable to complete installation. Current state is written to $ENVIRONMENT{"resume_file"}.
To resume install, use './installer.pl --resuming'.
WAH
	exit 1;
}

sub fail_nicely
{
	my ($msg) = @_;
	print "	Failed.\n";
	print $msg."\n";
	exit 1;
}


sub exit_help
{
	my $underline = "=" x length($ENVIRONMENT{"installer_title"});
	print <<EOH;

$ENVIRONMENT{"installer_title"}
$underline

usage: ./installer.pl [arguments]

Arguments:
  --arch		Set the system architecture value.
  --automate_install	Assume all defaults are okay.
  --help		Display this file.
  --libraries		Colon-delimited string of extra library directories.
  --no_root		Assume that no root access if required.
  --resume_file		Set where to read/write the resume file.
  --resuming		Whether to resume or not.
  --silent		Show no text (except prompts if not silent).
  --verbose		Show lots of text.
  --version		Display version and exit.
EOH

	exit(0);
}

sub untgz
{
	my($archive) = @_;
	my $out;
        print "Untarring	...";
        $out = `tar xfvz $archive 2>&1 1>/dev/null`;
        if ($out ne "") { exit_nicely(" Failed!\nError: $out\n"); }
        print "	Done.\n";
}

sub untar
{
        my($archive) = @_;
	my $out;
        print "Untarring	...";
        $out = `tar xfv $archive 2>&1 1>/dev/null`;
        if ($out ne "") { exit_nicely(" Failed!\nError: $out\n"); }
        print "	Done.\n";
}

# Helper functions

# Skip the installation and checking of a component.

sub skip_component
{
	my($mod) = @_;
	# Locate package
	foreach $package (@PACKAGES)
	{
		if ($package->{name} eq $mod)
		{
			$ENVIRONMENT{$mod."_installed"} = $package->{min_version};
			$ENVIRONMENT{$mod."_skip"} = 1;
			last;
		}
	}
}

# Similar to which.

sub find_file
{
	my($findme, @paths) = @_;
	my @searchpaths = split(/:+/, $ENV{"PATH"});
	push @searchpaths, @paths;
	my @found = ();
	my $curritem;
	foreach my $path (@searchpaths)
	{
		$path =~ s/(.+)\/$//;
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

sub get_dir_contents
{
	my($dir) = @_;
	opendir(DIR, $dir) or return 0;
	my @subdirs = ();
	my @files = ();
	my $curritem;
	while ($curritem = readdir(DIR))
	{
		# Skip . and ..
		next if ($curritem =~ /^\.[\.]?$/);
		if (-d "$dir/$curritem")
		{
			push @subdirs, "$dir/$curritem";
		}
		else
		{
			push @files, "$dir/$curritem";
		}
	}
	closedir(DIR);
	foreach(@subdirs)
	{
		push @files, get_dir_contents($_);
	}
	return @files;
}

sub decompress
{
	my($archive) = @_;
	if ($archive =~ /\.tar\.gz$/)
	{
		untgz($archive);
		$_ = $archive;
		s/\.tar\.gz$//;
		return $_;			
	}
	else
	{
		untar($archive);
		$_ = $archive;
		s/\.tar$//;
		return $_;			
	}
	
}

sub perlinstall
{
	my($package) = @_;

	my $currdir = getcwd();
	chdir decompress($package->{archive});
	print "Configuring	...";
	`perl Makefile.PL 2>&1 1>/dev/null`;
	print "	Done.\n";
	print "Making		...";
	`make 2>&1 1>/dev/null`;
	print "	Done.\n";
	print "Installing	...";
	`make install`;
	print "	Done.\n";
	chdir $currdir;

	return 1;
}

sub standardinstall
{
	# ./configure
	# make
	# make install

	my($package) = @_;
	my $currdir = getcwd();
	chdir decompress($package->{archive});
	print "Configuring	...";
	`./configure`;
	print "	Done.\n";
	print "Making		...";
	`make`;
	print "	Done.\n";
	print "Installing	...";
	`make install`;
	print "	Done.\n";
	chdir $currdir;
	return 1;
}

sub perlcheck
{
	my($mod) = @_;
	return get_module_version($mod);
}

sub standardcheck
{
	my($cmdi, @path) = @_;
        my($version) = "";
	@paths = find_file($cmdi,@path) or return 0;
	foreach(@paths)
	{
        	$version = `$_ -V 2>/dev/null`;
        	if ($version =~ /(\d+)\.(\d+)\.?(\d*)/)
        	{
        	        return "$1.$2.$3";
        	}
	}
        return 0;	
}

#my $config = "installer-".($resuming?"resume":"config").".pl";
#require $config;
# Grab command-line options.

my $show_help 		= 0;
my $show_version	= 0;
my $resuming 		= 0;
GetOptions(
'verbose' 		=> \$ENVIRONMENT{verbose},
'silent' 		=> \$ENVIRONMENT{silent},
'resuming!' 		=> \$resuming,
'resume_file=s' 	=> \$ENVIRONMENT{resume_file},
'automate_install' 	=> \$ENVIRONMENT{automate_install},
'arch=s'		=> \$ENVIRONMENT{system_arch},
'no_root' 		=> \$ENVIRONMENT{no_root},
'libraries=s' 		=> \$ENVIRONMENT{library_paths}, 
'help'			=> \$show_help,
'version'		=> \$show_version,
) || exit_help();

if ($show_help) { exit_help() };

# Show a bit of version gubbins.
my $title = $ENVIRONMENT{"installer_title"}." v".$ENVIRONMENT{"installer_version"};
print "\n$title\n";
exit 0 if ($show_version);
print "=" x length($title)."\n";

# Set up package details.
print "\nPackage configuration.\n\nNote that nothing will be installed during this section, so feel free to exit at any time.\n\n"; 
get_packs();
# Install packages.
print "\nPackage installation.\n\nWe strongly recommend that you do not exit during this section, as files are being installed.\n\n";
do_install();
