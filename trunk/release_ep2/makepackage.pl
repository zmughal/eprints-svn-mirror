#!/usr/bin/perl -w

use Cwd;

%codenames = (
	"eprints2-alpha-1" => "anchovy",
	"eprints2-alpha-2" => "pepperoni",
	"eprints2-pre-1"   => "fishfinger",
	"eprints2-pre-2"   => "ovenchip",
	"eprints2-pre-3"   => "toast",
	"eprints2-pre-4"   => "noodle",
	"eprints2-pre-5"   => "bovex",
	"eprints2-pre-6"   => "baconbits",
	"eprints2-pre-7"   => "limepickle",
	"eprints2-2-0"   => "olive",
	"eprints-2-0-1pre1"   => "mangogoo",
	"eprints2-0-1"   => "tuna"
);
%ids = (
	"latest"           => "2.0.1",
	"eprints2-pre-6"   => "2.0.pre-6",
	"eprints2-2-0"     => "2.0",
	"eprints-2-0-1pre1"     => "2.0.1.pre-1",
	"eprints2-0-1"     => "2.0.1"
);

($type) = @ARGV;

$EPRINTS_VERSION = "2.0.1";
if( defined $type && $ids{$type} )
{
	$EPRINTS_VERSION = $ids{$type};
}
$DATE = `date +%Y-%m-%d`;
chomp $DATE;

$whoami = `whoami`;
chomp $whoami;
$ENV{"CVSROOT"} = ":pserver:$whoami\@cvs.iam.ecs.soton.ac.uk:/home/iamcvs/CVS";
# Get all the vars we need.
$ntype = -1;
if (!defined($type) || $type eq "nightly")
{
	$version_tag = "HEAD";
	$package_version = $ids{latest}."-".$DATE;
	$package_desc = "EPrints Nightly Build - $package_version";
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
	$package_version = $EPRINTS_VERSION;
	$package_desc = "EPrints $EPRINTS_VERSION (".$codenames{$type}.") [Born on $DATE]";
	$package_file = "eprints-".$ids{$type};
	$ntype = 1;
}

do_package($version_tag, $package_version, $package_desc, "licenses/gplin.txt", $package_file, $ntype);

########################################

sub insert_data
{
	my( $key, $value, $source, $multiline) = @_;

	open IN, $source or die "Unable to open source file.\n";
	my $perms = (stat IN)[2];

	open OUT, ">$source.out" or die "Unable to open output file.\n";

	while ( <IN> )
	{
		if( $multiline )
		{
			if( /$key/ )
			{
				my $line;
				foreach $line ( split( "\n", $value ) )
				{
					my $l2 = $_;
					$l2=~s/$key/$line/;
					print OUT $l2;
				}
			}
			else
			{
				print OUT $_;
			}
		}
		else
		{
			s/$key/$value/g;
			print OUT $_;
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
		system("/bin/rm -rf package")==0 or die "Couldn't remove package dir.\n";
	}
	
	if (-d "export")
	{
		system("/bin/rm -rf export")==0 or die "Couldn't remove export dir.\n";
	}
	
	print "Making directories...\n";
	mkdir("package") or die "Couldn't create package directory\n";
	mkdir("export") or die "Couldn't create export directory\n";

	print "Exporting from CVS...\n";
	$originaldir = getcwd();
	chdir "export";
	system("cvs export -r $version_tag eprints/system >/dev/null")==0 or die "Could not export system.\n";
	system("cvs export -r $version_tag eprints/docs_ep2 >/dev/null")==0 or die "Could not export docs.\n";
	print "Removing .cvsignore files...\n";
	system("/bin/rm `find . -name '.cvsignore'`")==0 or die "Couldn't remove.";
	print "Copying installer...\n";
	system("cp $originaldir/install-eprints.pl eprints/system/install-eprints.pl");
	print "Copying bundled perl modules...\n";
	system("cp -r $originaldir/perl_mods/* eprints/system/lib/");
	print "Inserting license information...\n";
	chdir "eprints/system";

	@files = 'install-eprints.pl';
	my $dir;
	foreach $dir ( "archivecfg", "bin", "cgi", "cgi/users", "lib" )
	{
		opendir( DIR, $dir );
		my $file;
		while( $file = readdir( DIR ) )
		{
			next if $file=~m/^\./; # not if it starts with .
			next unless( -f "$dir/$file" );
			push @files, "$dir/$file";
		}
		closedir( DIR );
	}
	my $license = "";
	open( FILE, "$originaldir/$license_file" );
	while( <FILE> ) { $license .= $_; }
	close FILE;
	my $genericpod = "";
	open( FILE, "pod/generic.pod" );
	while( <FILE> ) { $genericpod .= $_; }
	close FILE;
	foreach $file (@files)
	{
		insert_data( "__GENERICPOD__", $genericpod, $file, 1 );
		insert_data( "__LICENSE__", $license, $file, 1 );
		insert_data( "__VERSION__", $package_version, $file );
	}


	# Build docs - cjg Mike this needs to be smarter about what to copy (alpha/beta etc)
	print "Build Docs...\n"	;
	chdir $originaldir."/export/eprints/docs_ep2";
	`./mkdocs.pl`;
	
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
	open(FILECONF, "$originaldir/conf/files.conf");
	while(<FILECONF>)
	{
		chomp;
		next if /^#/;
		s/\s*#.*$//;
		next if /^\s*$/;
		($from, $to, $recurse) = split /\t/;
		$recstr = "";
		$recstr = "-r" if (defined $recurse);
		system("cp $recstr $originaldir/export/$from eprints/$to");
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
	@langs = ("en" );
	@files = ();

	# Build up list from export.
	opendir(PHRSDIR, "$originaldir/export/eprints/system/phrases");
	while($item = readdir(PHRSDIR))
	{
		if (-d $item || $item =~ /^\./ ) { next; }	
		push(@files, $item);
	}
	closedir(PHRSDIR);

	# Nasty...
#	foreach $l (@langs)
#	{
#		$currarch = 0;
#		$currsys = 0;
#		foreach(@files)
#		{
#			if (/archive-$l-([0-9]+)/)
#			{
#				if ($1>$currarch) { $currarch = $1; }
#			}
#			elsif (/system-$l-([0-9]+)/)
#			{
#				if ($1>$currsys) { $currsys = $1; }
#			}
#		}
#		if ($l eq "en")
#		{
#			$enarch = $currarch;
#			$ensys	= $currsys;
#		}
#		next if ($l eq "en");
#
#		print "For language $l:\n";
#		print "Newest arch: archive-$l-$currarch\n";
#		print "Newest sys: system-$l-$currsys\n";
#		if ($currsys>0)
#		{
#			print "Copying $l language file.\n";	
#			system("cp $originaldir/export/eprints/system/phrases/system-$l-$currsys eprints/cfg/system-phrases-$l.xml");
#		}	
#		else
#		{
#			print "Copying English language file as placeholder\n";
#			system("cp $originaldir/export/eprints/system/phrases/system-en-$ensys eprints/cfg/system-phrases-$l.xml");
#		}
#
#		if ($currarch>0)
#		{
#			print "Copying $l language file.\n";
#			system("cp $originaldir/export/eprints/system/phrases/archive-$l-$currarch eprints/defaultcfg/phrases-$l.xml");
#		}
#		else
#		{
#			print "Copying English language file as placeholder\n";
#			system("cp $originaldir/export/eprints/system/phrases/archive-en-$enarch eprints/defaultcfg/phrases-$l.xml");
#		}
#	}
#	# ...Nasty
#
#	if ($type_num == 0)
#	{
#		# Here we copy over the nightly language files
#		foreach $l (@langs)
 #               {
#			if (-e "$originaldir/export/eprints/system/phrases/archive-$l-current")
#			{
#				print "Transferring $l phrases...\n";
#				system("cp $originaldir/export/eprints/system/phrases/archive-$l-current eprints/defaultcfg/phrases-$l.xml");
#			}
#			if (-e "$originaldir/export/eprints/system/phrases/system-$l-current")
#			{
#				print "Transferring $l system phrases...\n";
#				system("cp $originaldir/export/eprints/system/phrases/system-$l-current eprints/cfg/system-phrases-$l.xml");
#			}
#		}
#	}
#	elsif($type_num == 1)
#	{
#		# Here we copy over the Alpha language files
#		foreach $l (@langs)
 #               {
#			if (-e "$originaldir/export/eprints/system/phrases/archive-$l-1")
#			{
#				print "Transferring $l phrases...\n";
#				system("cp $originaldir/export/eprints/system/phrases/archive-$l-1 eprints/defaultcfg/phrases-$l.xml");
#			}
#			if (-e "$originaldir/export/eprints/system/phrases/system-$l-1")
#			{
#				print "Transferring $l system phrases...\n";
#				system("cp $originaldir/export/eprints/system/phrases/system-$l-1 eprints/cfg/system-phrases-$l.xml");
#			}
#		}
#	}
	foreach $l (@langs)
	{
		if (-e "$originaldir/export/eprints/system/phrases/system-$l-current")
		{
			system("cp $originaldir/export/eprints/system/phrases/system-$l-current eprints/cfg/system-phrases-$l.xml");
		}
		if (-e "$originaldir/export/eprints/system/phrases/archive-$l-current")
		{
			system("cp $originaldir/export/eprints/system/phrases/archive-$l-current eprints/defaultcfg/phrases-$l.xml");
		}
	}

	# system("cp $originaldir/export/eprints/system/cgi/users/.htaccess eprints/cgi/users/.htaccess");
	system("cp $originaldir/licenses/gpl.txt eprints/COPYING");
	system("chmod -R g-w eprints")==0 or die("Couldn't change permissions on eprints dir.\n");
	system("mv eprints $package_file")==0 or die("Couldn't move eprints dir to $package_file.\n");
	system("tar czf ../$package_file.tar.gz $package_file")==0 or die("Couldn't tar up $package_file");
	chdir $originaldir;

	

	print "Removing temporary directories...\n";
	#system("/bin/rm -rf package")==0 or die("Couldn't remove package dir.\n");
	#system("/bin/rm -rf export")==0 or die("Couldn't remove export dir.\n");

	print "Done.\n";

}






