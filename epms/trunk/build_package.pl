#!/bin/perl

use strict;
use File::Path;
use File::Temp qw/ tempfile tempdir /;
use Cwd;

our $config = {};
our $debug = 1;

$config->{package} = $ARGV[0];
$config->{version} = $ARGV[1];

my $svn_root = "https://svn.eprints.org/eprints/epms/";

if (!defined $config->{package} or !defined $config->{version})
{
	print "\n\n";
	print "Usage build_package.pl package_name version\n";
	print "    package_name: Unique key to package\n";
	print "    version: x.x.x style version\n\n";
	print "Example: perl build_package.pl ORE_Tools 1.0.0\n\n";
	exit(1);
}

print "Package Requested: " . $config->{package} . "\n\n" if $debug;

my $spec_file = get_spec_file($config->{package});

if (!defined $spec_file) 
{
	print "[CRITICAL] Count not find manifest/spec file for package: " . $config->{package} . "\n";
	exit(1);
}

my $version = $config->{version};

if (!($config->{version} =~ s! ^(\d+).(\d+).(\d+)$ !!x)) 
{
	print "[CRITICAL] Supplied version number not supported, needs to be decimal numbers only, e.g. 1.2.3: " . $config->{version} . " supplied\n";
	exit(1);
}

$config->{version} = $version;

print "GOT SPEC FILE @ " . $spec_file . "\n" if ($debug);

my $svn_tag_path = $svn_root . "tags/" . $config->{package} . "/" . $config->{version};

if (tag_exists($svn_tag_path)) 
{
	print "[WARNING] Tagged version " . $config->{package} . "-" . $config->{version} . " already exists, building this version\n";
	build_tag($svn_tag_path);
	exit(1);
}

print "NO TAG for " . $config->{package} . "-" . $config->{version} . "\n" if ($debug);

unless(make_tag($spec_file)) 
{
	print "[CRITICAL] Failed to tag " . $config->{package} . "-" . $config->{version} . "\n";
}

print "[MESSAGE] Tag built and commited successfully\n" if ($debug);

unless(build_tag($svn_tag_path))
{
	print "[CRITICAL] Filed to build package for  " . $config->{package} . "-" . $config->{version} . " from tag @ $svn_tag_path \n";
}

print "[MESSAGE] Operation Complete\n" if ($debug);

sub build_tag 
{
	my $svn_tag_path = shift;

	my $dir = tempdir(CLEANUP => 0);

	system("svn export $svn_tag_path $dir/ --force");

	my $current_path = cwd;
	my $epm_path = $current_path . '/' . $config->{package} . '-' . $config->{version} . ".epm";

	chdir $dir;

	system("zip -r $epm_path *");
	
	if ($? == -1 or $? & 127) {
		print "[FAILED]";
		return 0;
	}

	chdir $current_path;

	print "\n[SUCCESS] EPM built @ $epm_path\n\n";

	unlink $dir;

	return 1;
}

sub make_tag
{
	my $spec_file = shift;

	my @args = ("svn","mkdir",$svn_root . "tags/" . $config->{package},"-m Tagging " . $config->{package});
	system(@args);
	
	@args = ("svn","mkdir",$svn_root . "tags/" . $config->{package} . "/" . $config->{version},"-m Tagging " . $config->{package} . "-" . $version);
	system(@args);

	my $dir = tempdir(CLEANUP => 1);

	@args = ("svn","co",$svn_root . "tags/" . $config->{package} . "/" . $config->{version},$dir);
	system(@args);

	process_spec_file($spec_file,$dir);
	copy_files($spec_file,$dir);

	system("svn add $dir/*");
	
	@args = ("svn","commit",$dir."/*","-m Tagging and committing " . $config->{package} . "-" . $config->{version});
	system("svn commit $dir/* -m 'Tagging and committing " . $config->{package} . "-" . $config->{version} . "'");
	
	unlink $dir;

	return 1;
}

sub copy_files
{
	use File::Copy;

	my $in_spec_file = shift;
	my $svn_dir = shift;
	
	open(INFILE,$in_spec_file);
	
	while(<INFILE>) 
	{
		chomp;
		my @parts = split(/:/,$_,2);
		if (lc(@parts[0]) eq "icon")
		{
			copy("icons/" . trim(@parts[1]),$svn_dir);
		}
		next if (scalar @parts > 1);
		next if (@parts[0] eq "=FILES=");
		my $path = $svn_dir . "/" . substr(@parts[0],0,rindex(@parts[0],"/"));
		mkpath($path);
		copy(@parts[0],$path);	
	}
	
	close(INFILE);

	return 1;
}

sub process_spec_file
{
	my $in_spec_file = shift;
	my $svn_dir = shift;

	my $out_spec_file = $svn_dir . "/" . $config->{package} . ".spec";

	open(INFILE,$in_spec_file);
	open(OUTFILE, '>' . $out_spec_file);
	print OUTFILE "package: " . $config->{package} . "\n";
	print OUTFILE "version: " . $config->{version} . "\n";

	while(<INFILE>) 
	{
		chomp;
		my @parts = split(/:/,$_,2);
		next if (scalar @parts < 2);
		unless (lc(@parts[0]) eq "version" or lc(@parts[0] eq "package")) 
		{
			print OUTFILE "$_\n";
		}
	}

	close(OUTFILE);
	close(INFILE);

	return 1;
}


sub tag_exists
{
	my $svn_tag_path = shift;

	print "CHECKING $svn_tag_path\n" if ($debug);
	
	system("svn info $svn_tag_path");
	if ($?) {
		return 0;
	} elsif ($? & 127) {
		return 0;
	} else {
		return 1;
	}
		
	return undef;
}


sub get_spec_file 
{
	my $filepath = "manifests/" . $config->{package} . ".spec";
	
	if (-e $filepath) {
		return $filepath;
	}

	return undef;
}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

1;
