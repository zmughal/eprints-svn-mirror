#!/usr/bin/perl -w

use Getopt::Long;
use Cwd;

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

sub module_installed
{
	return eval("require $_[0]"); 
}

sub get_module_version
{
	my($mod) = @_;
	if (module_installed($mod))
	{
		$var = $mod."::VERSION";
		return convert_version($$var);
	}
	return 0;
}

sub make_version
{
	my($a, $b, $c) = @_;
	if (!defined $a || $a eq "") { $a = 0; }
	if (!defined $b || $b eq "") { $b = 0; }
	if (!defined $c || $c eq "") { $c = 0; }
	return (1000000000000*$a)+(1000000*$b)+$c;
}

sub convert_version
{
	# 1.2.3 to 100000020000003000000
	my($verstring) = @_;
	if ($verstring =~ /([0-9]+)\.([0-9]+)\.?([0-9]*)/)
	{
		return make_version($1, $2, $3);
	}
	return 0;
}

sub compare_version
{
	my( $a, $b ) = @_;

	$a = "0" if( !defined $a || $a eq "" );
	$b = "0" if( !defined $b || $b eq "" );
		
	my( @a ) = split '\.' $a;
	my( @b ) = split '\.' $b;

	for(;;)
	{
		return 0 if( scalar @a == 0 && scalar @b == 0 );
		$ahead = splice( @a, 0, 1);
		$ahead = 0 if( !defined $ahead );
		$bhead = splice( @b, 0, 1);
		$bhead = 0 if( !defined $bhead );
		return 1 if ($ahead > $bhead);
		return -1 if ($ahead < $bhead);
	}
}		

	

sub get_library_paths
{
	my($searchstring) = @_;
	my %is_checked = ();
	my @out = ();
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
	@userfields = split(/:+/, $ENVIRONMENT{library_paths});
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
	
	do
	{
		print "Please specify the path of a valid ".$info->{long_name}." package, or leave blank to exit install.\n";
		$path = get_string("Path?" , "");
		if ($path eq "") 
		{
			exit_nicely();
		}
		else
		{
			if (-e $path && $path =~ $_->{search_string})
			{
				$this_version = make_version($1, $2, $3);
				if ($this_version < convert_version($_->{min_version}))
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
		$old = $~;
		$~ = 'DESC';
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
		$installed = &{$funcname}($_);
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
		
	foreach (@PACKAGES)
	{
		if ( defined $ENVIRONMENT{$_->{name}."_installed"} && $ENVIRONMENT{$_->{name}."_installed"} > 0 ) { $ENVIRONMENT{$_->{name}."_skip"} = 1; next; }
		$funcname = $_->{name}."_check";
		$version = &{$funcname};
		$ENVIRONMENT{$_->{name}."_installed"} = $version;
	}

	@targz = <*>;
	# Search in current directory
	foreach $file (@targz)
	{
		foreach $package (@PACKAGES)
		{
			if (defined $ENVIRONMENT{$package->{name}."_skip"}) { next; }
			if ($file =~ /$package->{search_string}/)
			{
				$thisversion = make_version($1, $2, $3);
				if (!defined $package->{version}) { $package->{version} = 0; }
				$curr_version = $package->{version};
				if ($thisversion>$curr_version && $curr_version>0)
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
	
	foreach $package (@PACKAGES)
	{
		if (defined $ENVIRONMENT{$package->{name}."_skip"}) { next; }
		$curr_installed = $ENVIRONMENT{$package->{name}."_installed"};
			
		$ok = 0;
		$installed_ok = 0;
		
		# First see if the currently installed version is okay...
		if ($curr_installed >= convert_version($package->{min_version}))
		{
			print "You already have ".$package->{long_name}." installed, ";
			if ($curr_installed >= convert_version($package->{min_version}))
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
		elsif ($package->{archive} ne "")
		{
			print "Found a package for ".$package->{long_name}." ";
			if ($package->{version} >= convert_version($package->{min_version}))
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
			$usepkg = get_yesno("Use this package:", "y");
			
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
	foreach $k (keys %ENVIRONMENT)
	{
		print RESFILE "$k	=> \"".$ENVIRONMENT{$k}."\",\n";
	}
	print RESFILE ");\n\n";
	print RESFILE "\@PACKAGES = \n(";
	foreach $package (@PACKAGES)
	{
		print RESFILE "{\n";
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

sub exit_help
{

	print <<EOH;

ePrints Installer
============

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
        print "Untarring	...";
        $out = `tar xfvz $archive 2>&1 1>/dev/null`;
        if ($out ne "") { exit_nicely(" Failed!\nError: $out\n"); }
        print "	Done.\n";
}

sub untar
{
        my($archive) = @_;
        print "Untarring	...";
        $out = `tar xfv $archive 2>&1 1>/dev/null`;
        if ($out ne "") { exit_nicely(" Failed!\nError: $out\n"); }
        print "	Done.\n";
}


# ePrints-specific

sub gzip_check
{
	my($gzip) = "";	
	$gzip = 'gzip' || return 0;
	
	if (qx[$gzip -V 2>&1] =~ /(\d+)\.(\d+)\.?(\d*)/)
	{
		return make_version($1, $2, $3);
	}
	return 0;
}

sub wget_check
{
	my($wget) = "";
	$wget = 'wget' || return 0;
	if (qx[$wget -V 2>&1] =~ /(\d+)\.(\d+)\.?(\d*)/)
	{
		return make_version($1, $2, $3);
	}
	return 0;
}

sub xercesc_check
{
	$curr_highversion = 0;	
	@libs = get_library_paths("xerces-c");

	foreach(@libs)
	{
		s/.*\///;		# Get short name
		if (/libxerces-c([0-9]+)_([0-9]+).so/)
		{
			$version = make_version($1, $2, $3);
			if ($version>$curr_highversion) { $curr_highversion = $version; }
		}		
	}
	return $curr_highversion;
}

sub xercesp_check
{
	return module_installed("XML::Xerces");	
}

sub eprints_check
{
	return 0;
}

sub apache_check
{
	my($httpd) = "";

	$httpd = `/usr/local/apache/bin/httpd -v 2>&1`;
	if ($httpd =~ /(\d+)\.(\d+)\.?(\d*)/)
	{
		return make_version($1, $2, $3);
	}
	return 0;
}

sub modperl_check
{
	return get_module_version("mod_perl");
}

sub mysql_check
{
	my($mysql) = "";
	my($version) = "";
	$mysql = 'mysql' || return 0;
	$version = `$mysql -V 2>&1`;
	if ($version =~ /(\d+)\.(\d+)\.?(\d*)/)
	{
		return make_version($1, $2, $3);
	}
	return 0;
}

sub cgi_check
{
	return get_module_version("CGI");
}

sub data_dumper_check
{
	return get_module_version("Data::Dumper");
}

sub dbi_check
{
	return get_module_version("DBI");
}

sub msql_check
{
	return get_module_version("Mysql");
}

sub diskspace_check
{
	return get_module_version("Filesys::DiskSpace");
}

sub mimebase_check
{
	return get_module_version("MIME::Base64");
}

# Helper functions

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

sub perl_module_install
{
	my($package) = @_;

	$currdir = getcwd();
	chdir decompress($package->{archive});
	print "Configuring	...";
	`perl Makefile.PL 2>&1 1>/dev/null`;
	print "	Done.\n";
	print "Making		...";
	`make 2>&1 1>/dev/null`;
	print "	Done.\n";
	chdir $currdir;

	return 1;
}

sub standard_install
{
	# ./configure
	# make
	# make install

	my($package) = @_;
	$currdir = getcwd();
	chdir decompress($package->{archive});;
	print "Configuring	...";
	`./configure`;
	print "	Done.\n";
	print "Making		...";
	`make`;
	print "	Done.\n";
	print "Installing	...";
#	`make install`;
	print "	Done.\n";
	chdir $currdir;
	return 1;
}

sub xercesc_install
{
	my($package) = @_;
	$currdir = getcwd();
	chdir decompress($package->{archive});
	$longname = getcwd();
	$ENV{XERCESCROOT} = $longname;
	chdir "src";
	print "Configuring	...";
	`autoconf`;
	`./configure`;
	print "	Done.\n";
#	print "Making		...";
#	`make 2>&1 1>/dev/null`;
	print "	Done.\n";
	chdir $currdir;
	return 1;
}

sub xercesp_install
{
	my($package) = @_;
	$currdir = getcwd();
	chdir decompress($package->{archive});
	print "Configuring	...";
	`perl Makefile.PL`;
	print "	Done.\n";
#	print "Making		...";
#	`make 2>&1 1>/dev/null`;
#	print "	Done.\n";
#	print "Testing		...";
#	`make test`;
	print "	Done.\n";
	chdir $currdir;
	return 1;
}

sub apache_install
{
	return 1;
}

sub modperl_install
{
	return 1;
}

sub mysql_install
{
	return 1;
}

sub eprints_install
{
	return 1;
}

# Grab command-line options.

$show_help 	= 0;
$resuming 	= 0;
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
) || exit_help();

if ($show_help) { exit_help() };

my $config = "installer-".($resuming?"resume":"config").".pl";
require $config;

#if ($ENVIRONMENT{resuming})
#{
#	open(RESFILE, $ENVIRONMENT{resume_file}) || die "Unable to open resume file";
#	$res = "";
#	while(<RESFILE>)
#	{
#		/(.*)[ ]+(.*)/;
#		$ENVIRONMENT{$1} = $2;
#	}
#	close(RESFILE);
#	eval $res;
#}

# Show a bit of version gubbins.
$title = "ePrints Installer v".$ENVIRONMENT{"installer_version"};
print "\n$title\n";
print "=" x length($title)."\n";

# Set up package details.
print "\nPackage configuration.\n\nNote that nothing will be installed during this section, so feel free to exit at any time.\n\n"; 
get_packs();
# Install packages.
print "\nPackage installation.\n\nWe strongly recommend that you do not exit during this section, as files are being installed.\n\n";
do_install();
