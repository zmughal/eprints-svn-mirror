#!/usr/bin/perl

use strict;
use warnings;
use File::Copy::Recursive qw(fcopy);

my $eprints_root = '/usr/share/eprints3/eprints_dev/twitter/system/';
my $vanilla_eprints_root = '/usr/share/eprints3/eprints_dev/pre_twitter/twitter/system/';


my $new_files_file = 'NEW_FILE_MANIFEST';
my $modified_files_file = 'MODIFIED_FILE_MANIFEST';

mkdir 'global';
mkdir 'local';

open NEWFILES, $new_files_file or die "Couldn't open $new_files_file\n";
while (<NEWFILES>)
{
	chomp;
	my $newfile = $_;

	my $target;
	my $source = $eprints_root . $newfile;
	die "could not find $source\n" unless -e $source;

	if ($newfile =~ m#^lib/defaultcfg/#)
	{
		#local file
		$target = 'local/cfg/' . $';
	}
	else
	{
		#global file
		$target = 'global/' . $newfile;
	}

	print "copying $source to $target\n";

	fcopy($source, $target) or die "Copy failed: $!";
}

open MODIFIEDFILES, $modified_files_file or die "Couldn't open $modified_files_file\n";

while (<MODIFIEDFILES>)
{
	chomp;
	my $file = $_;
	my $modified_file = $eprints_root . $file;
	my $unmodified_file = $vanilla_eprints_root . $file;

	print "comparing $modified_file with $unmodified_file\n";
	my $target;
        if ($file =~ m#^lib/defaultcfg/#)
        {
                #local file
		#copy file to local directory stucture before doing the diff
		my $modified_copy = 'local_mod/cfg/' . $';
		fcopy($modified_file, $modified_copy);
		$modified_file = $modified_copy;

                $target = 'local/twitter.patch';
        }
        else
        {
                #global file
                $target = 'global/twitter.patch';
        }

	`diff -Naur $unmodified_file $modified_file >> $target`;
}

chdir 'global';
`tar cvzf global.tar.gz *`;
chdir '../local';
`tar cvzf local.tar.gz *`;
chdir '..';

my $dir_name = 'twitter_package_' . get_datestamp();

mkdir $dir_name;
fcopy('global/global.tar.gz', "$dir_name/");
fcopy('local/local.tar.gz', "$dir_name/");
fcopy('README', "$dir_name/");

`tar cvzf $dir_name.tar.gz $dir_name `;

`rm -rf local local_mod global $dir_name`;


sub get_datestamp
{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime time;

	return sprintf("%04d%02d%02d",$year+1900,$mon+1,$mday);
} 


