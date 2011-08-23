#!/usr/bin/perl -w

# nb.
#
# cvs tag eprints2-2-99-0 system docs_ep2
#
# ./makepackage.pl  eprints2-2-99-0
#
# scp eprints-2.2.99.0-alpha.tar.gz webmaster@www:/home/www.eprints/software/files/eprints2/

=head1 NAME

B<makepackage.pl> - Make an EPrints tarball

=head1 SYNOPSIS

B<makepackage.pl> <version OR latest OR nightly>

=head1 ARGUMENTS

=over 4

=item I<version>

EPrints version to build or 'nightly' to build nightly version (current trunk HEAD).

=back

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exit.

=item B<--branch>

Export from the branch version rather than tag (branches are major-version only).

=item B<--bzip>

Use Tar-Bzip as the packager (produces a tar.bz2 file).

=item B<--force>

Force a package build, even if it doesn't exist in versions.txt.

=item B<--license>

Filename to read license from (defaults to licenses/gpl.txt) 
(NOTE this is currently not used!)

=item B<--license-summary>

Filename to read license summary from (defaults to licenses/gplin.txt) - gets embedded wherever _B<>_LICENSE__ pragma occurs.
(NOTE this is currently not used!)

=item B<--list>

List all available versions.

=item B<--man>

Print the full manual page and then exit.

=item B<--deb>

Build a .deb package that can be installed on Debian-based systems.

=item B<--win32>

Build a .msi package that can be installed on Win32 systems.

=item B<--rpm>

Build a .rpm package that can be installed on Redhat-based systems.

=item B<--revision>

Append a revision to the end of the output name.

=item B<--release> PATH

Path to an internal release bundle (developers only).

=item B<--changelog>

Create a changelog (default).

=item B<--zip>

Use Zip as the packager (produces a .zip file).

=item B<--upload=username:password>

Post the packaged file to files.eprints.org with the given username/password.

=item --prefix

Set the path to install to. (RPM only)

=item --user

Set the user to install as. (RPM only)

=item --group

Set the group to install as. (RPM only)

=back

=cut

use Cwd;
use Getopt::Long;
use Pod::Usage;
use File::Path;
use File::Copy qw( cp move );
use LWP::UserAgent;
use Recursive; # File::Copy::Recursive

use strict;

my( $opt_revision, $opt_license, $opt_license_summary, $opt_list, $opt_zip, $opt_bzip, $opt_help, $opt_man, $opt_branch, $opt_force, $opt_win32, $opt_rpm, $opt_deb, $opt_changelog, $opt_upload, $opt_release );

my $opt_svn = "https://svn.eprints.org/eprints";
$opt_changelog = 1;
my $opt_cleanup = 1;
my $opt_prefix = "/usr/share/eprints";
my $opt_user = "eprints";
my $opt_group = "eprints";

my @raw_args = @ARGV;

GetOptions(
	'help' => \$opt_help,
	'man' => \$opt_man,
	'revision' => \$opt_revision,
	'branch' => \$opt_branch,
	'license=s' => \$opt_license,
	'license-summary=s' => \$opt_license_summary,
	'list' => \$opt_list,
	'zip' => \$opt_zip,
	'bzip' => \$opt_bzip,
	'force' => \$opt_force,
	'svn' => \$opt_svn,
	'win32' => \$opt_win32,
	'deb' => \$opt_deb,
	'rpm' => \$opt_rpm,
	'changelog!' => \$opt_changelog,
	'upload=s' => \$opt_upload,
	'release=s' => \$opt_release,
	'cleanup!' => \$opt_cleanup,
	'prefix=s' => \$opt_prefix,
	'user=s' => \$opt_user,
	'group=s' => \$opt_group,
) || pod2usage( 2 );

pod2usage( 1 ) if $opt_help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $opt_man;

my %mime_types = (
	deb => "application/x-deb",
	rpm => "application/x-rpm",
	msi => "application/x-msi",
);

my $upload_url = "http://files.eprints.org/cgi/post_release";
my $ua = LWP::UserAgent->new();

my %codenames= ();
my %ids = ();
my @versions;
open( VERSIONS, "versions.txt" ) || die "can't open versions.txt: $!";
while(<VERSIONS>)
{
	chomp;
	$_ =~ s/\s*#.*$//;
	next if( $_ eq "" );
	$_ =~ m/^\s*([^\s]*)\s*([^\s]*)\s*(.*)\s*$/;
	$ids{$1} = $2;
	$codenames{$1} = $3;
	push @versions, $1;
}
close VERSIONS;

my( $type ) = @ARGV;

if( defined $type && $type eq "latest" )
{
	@versions = grep { !/[a-z]/i } @versions;
	$type = $versions[$#versions];
	@versions = ($type);
}

if( $opt_list )
{
	print "I can build the following versions:\n".join("\n",@versions)."\n";
	print "To add a version edit 'versions.txt'\n";
	exit;
}

my $version_path;
my $package_version;
my $package_desc;
my $rpm_version;
my $mime_type;
my $package_ext = '.tar.gz';
$package_ext = '.zip' if $opt_zip;
$package_ext = '.tar.bz2' if $opt_bzip;

$package_ext = '.tar.gz' if $opt_deb || $opt_rpm;
$package_ext = '.zip' if $opt_win32;

pod2usage( 2 ) if( scalar @ARGV != 1 );

my @date = gmtime();
my $date = sprintf( "%04d-%02d-%02d",
	$date[5] + 1900,
	$date[4] + 1,
	$date[3] );

if( $type eq "nightly" ) 
{ 
	$version_path = "/trunk";
	$package_version = "eprints-build-$date";
	$package_desc = "EPrints Nightly Build - $package_version";
	$opt_revision = 1;
	$rpm_version = "0.0.0";
}
elsif( $opt_branch )
{
	$version_path = "/branches/".$type;
	$package_version = "eprints-branch-$type-$date";
	$package_desc = "EPrints Branch Build - $package_version";
	$opt_revision = 1;
	my $result = `svn info $opt_svn$version_path/system/`;
	push @raw_args, "--force";
	if( !length( $result ) )
	{
		print "Could not find branch '$type'\n\n";
		print "Available branches:\n";
		print `svn ls $opt_svn/branches/`;
		print "\n";
		exit 1;
	}	
	$rpm_version = "0.0.0";
}
else
{
	if( $opt_force and !defined $codenames{$type} )
	{
		$codenames{$type} = $ids{$type} = $type;
	}
	if( !defined $codenames{$type} )
	{
		print "Unknown codename\n";
		print "Available:\n".join("\n",sort keys %codenames)."\n\n";
		exit 1;
	}
	$version_path = "/tags/".$type;
	$package_version = "eprints-".$ids{$type};
	$package_desc = "EPrints ".$ids{$type}." (".$codenames{$type}.") [Born on $date]";
	$rpm_version = $ids{$type};
	$rpm_version =~ s/-.*//; # Exclude beta/alpha/RC versioning
	$rpm_version ||= "0.0.0"; # Hmm, b0rked
}

if( $opt_win32 )
{
	if( $^O ne "MSWin32" )
	{
		die "Can't build Win32 MSI on platform: $^O";
	}
	if( $type =~ /^3\.2\b/ && !-e "srvany.exe" )
	{
		die "Can't bulid Win32 3.2.X MSI without srvany.exe";
	}
}

if( $opt_upload )
{
	$ua->credentials( "files.eprints.org:80", "EPrints.org", split(/:/, $opt_upload, 2) );

	my $source = "$package_version.tar.gz";
	if( $opt_deb )
	{
		$mime_type = $mime_types{deb};
	}
	elsif( $opt_rpm )
	{
		$mime_type = $mime_types{rpm};
	}
	elsif( $opt_win32 )
	{
		$mime_type = $mime_types{msi};
	}
	else
	{
		die "--upload argument requires a package argument to upload\n";
	}

	my %existing = retrieve_versions( $source );
	if( !scalar keys %existing )
	{
		print "files.eprints.org reports no $source\n";
		exit;
	}
	elsif( exists $existing{$mime_type} )
	{
		print "$existing{$mime_type}\n";
		exit;
	}
}

erase_dir( "export" );

print "Exporting from SVN...\n";
my $originaldir = getcwd();

mkdir( "export" );

open( SVNINFO, "svn info $opt_svn$version_path/system/|" ) || die "Could not run svn info";
my $revision;
while( <SVNINFO> )
{
	next unless( m/^Revision:\s*(\d+)/ );
	$revision = $1;
}
close SVNINFO;
if( !defined $revision ) 
{
	die 'Could not see revision number in svn info output';
}
if( $opt_release )
{
	print "$opt_release => export/release/ due to --release option\n";
	File::Copy::Recursive::dircopy( $opt_release, "export/release/" ) or die "No files found in $opt_release";
}
else
{
	cmd( "svn -q export $opt_svn$version_path/release/ export/release/")==0 or die "Could not export system.\n";
}
cmd( "svn -q export $opt_svn$version_path/system/ export/system/")==0 or die "Could not export system.\n";

# check that the $EPrints::VERSION is correct for the requested version
if( $type ne "nightly" && !$opt_branch )
{
	my $version;
	if( open(EPRINTS, "<", "export/system/perl_lib/EPrints.pm") )
	{
		while(<EPRINTS>)
		{
			if( /VERSION = v([0-9\.]+)/ )
			{
				$version = $1;
				last;
			}
		}
		close(EPRINTS);
		if( $version && $version ne $type )
		{
			die "EPrints::VERSION is '$version' but you asked for '$type' (perhaps the tag doesn't have the correct version)?\n";
		}
	}
}

if( !$opt_changelog )
{
	open(CHANGELOG, ">", "export/system/CHANGELOG");
	print CHANGELOG "--nochangelog option given\n";
	close(CHANGELOG);
}
elsif( !-e "export/system/CHANGELOG" )
{
	# Still keep CHANGELOG when building pre-3.2 packages
	#
	if( $type eq "nightly" || $opt_branch )
	{
		cmd( "perl build_version_log.pl $opt_svn$version_path > export/system/CHANGELOG" )==0 or die "Could not build CHANGELOG.\n";
	}
	else
	{
		cmd( "perl build_version_log.pl --version $type > export/system/CHANGELOG" )==0 or die "Could not build CHANGELOG.\n";
	}
}

if( $opt_revision )
{
	$package_version .= "-r$revision";
}

my @args;
push @args, 'export'; # The source
push @args, 'package'; # The target
push @args, $package_version;
push @args, $package_desc;
push @args, $package_version;
push @args, $package_ext;
push @args, $rpm_version;
push @args, "--nocleanup" if !$opt_cleanup;

if( $opt_win32 )
{
	cmd( "perl", "export/release/internal_makemsi.pl", @args );
}
else
{
	cmd( "perl", "export/release/internal_makepackage.pl", @args );
}

# stuff

print "Removing temporary directories...\n";
erase_dir( "export" );

my $filename = $package_version.$package_ext;
if( -e $filename )
{
	print "Moving package file into packages/ directory.\n";
	rename($filename, "packages/$filename");
}

my $install_package;

my $cwd = getcwd();
chdir("packages");
if( $opt_deb )
{
	print "Building DEB package\n";
	$install_package = build_deb();
}
elsif( $opt_rpm )
{
	print "Building RPM package\n";
	$install_package = build_rpm();
}
elsif( $opt_win32 )
{
	print "Building MSI package\n";
	$install_package = build_msi();
}
chdir($cwd);

print "$package_version$package_ext\n";

if( $opt_upload )
{
	if( !$install_package )
	{
		die "Can't upload without a package file";
	}
	my( $username, $password ) = split /:/, $opt_upload;

	my $source = "$package_version.tar.gz";

	if( open(my $fh, "<", "packages/$install_package") )
	{
		my $content;
		sysread($fh, $content, -s $fh);
		my $r = $ua->post( $upload_url, {
			source => $source,
			filename => $install_package,
			content => $content,
			content_type => $mime_type,
		});
		close($fh);
		if( $r->is_success )
		{
			print $r->content . "\n";
		}
		else
		{
			die $r->status_line . "\n";
		}
	}
	else
	{
		die "Can not open packages/$install_package: $!";
	}
}

exit;


sub erase_dir
{
	my( $dirname ) = @_;

	if (-d $dirname )
	{
		rmtree($dirname) or
			die "Couldn't remove ".$dirname." dir.\n";
	}
}


sub cmd
{
	print join(' ', @_)."\n";

	return system( @_ );
}

sub build_deb
{
}

sub build_rpm
{
	$revision = 1 if !defined $revision; # RPM always has a revision

	my $specfile;

	my $builddir = "BUILD";
	my $tmppath = "TEMP";
	mkdir($builddir);
	mkdir($tmppath);
	for(qw( eprints.spec eprints3.spec ))
	{
		$specfile = $_;
		cmd("tar",
				"--strip-components=1",
				"-xzf",
				"$package_version$package_ext",
				"$package_version/$specfile"
			);
		last if -f $specfile;
	}
	open(SPEC,"<",$specfile) or die "Error reading $specfile: $!";
	my $spec = "";

	# strip old-style %defines
	while(<SPEC>)
	{
		$spec .= $_, last if $_ !~ /^\%define/;
	}
	# make Release distribution-specific (if set)
	while(<SPEC>)
	{
		if( $_ =~ /^Release:/ )
		{
			$spec .= "Release: \%{_eprelease}\%{?dist}\n";
		}
		else
		{
			$spec .= $_;
		}
	}
	close(SPEC);

	my %defines = (
		# package options
		_epname => "eprints",
		_epuser => $opt_user,
		_epgroup => $opt_group,
		_epversion => $rpm_version,
		_eprelease => $revision,
		_eppackage => $package_version,
		_epbase_path => $opt_prefix,
		# compatibility with 3.2
		user => $opt_user,
		user_group => $opt_group,
	);
	open(SPEC,">",$specfile) or die "Error writing to $specfile: $!";
	# new-style define-conditionals
	print SPEC "# Default values for packaging this version\n";
	for(sort keys %defines)
	{
		print SPEC '%{!?'.$_.': %define '.$_." $defines{$_}}\n";
	}
	print SPEC "\n";
	print SPEC $spec;
	close(SPEC);
	%defines = (
		%defines,

		# rpm build options
		_topdir => "$cwd/packages",
		_sourcedir => "\%{_topdir}",
		_rpmdir => "\%{_topdir}",
		_srcrpmdir => "\%{_topdir}",
		_builddir => "\%{_topdir}/$builddir",
		_tmppath => "\%{_topdir}/$tmppath",
	);
	my @defines = map { ('--define' => "$_ $defines{$_}") } keys(%defines);

	cmd("rpmbuild",
			"--quiet",
			"-ba",
			"--clean",
			@defines,
			$specfile
		)==0 or die "Error in rpmbuild\n";
	unlink($specfile);
	erase_dir($builddir);
	erase_dir($tmppath);

	my $rpm = "eprints-$rpm_version-$revision.noarch.rpm";

	move("noarch/$rpm", $rpm);
	rmdir("noarch");

	print "$rpm\n";
	print "eprints-$rpm_version-$revision.src.rpm\n";

	return $rpm;
}

sub build_msi
{
	cmd("unzip","-oq","$package_version$package_ext");
	if( $type =~ /^3\.2\b/ )
	{
		cp("../srvany.exe", "$package_version") or die "Missing srvany.exe";
	}
	chdir($package_version);
	cmd("candle","eprints.wsx");
	cmd("light","-ext","WixUIExtension","eprints.wixobj");
	move("eprints.msi","../$package_version.msi");
	chdir("$cwd/packages");
	erase_dir($package_version);
	print "$package_version.msi\n";

	return "$package_version.msi";
}

sub retrieve_versions
{
	my( $source ) = @_;

	my $r = $ua->post( $upload_url, {
		source => $source,
	});
	if( !$r->is_success )
	{
		die $r->request->uri . ": " . $r->status_line . "\n";
	}

	my %existing;
	for( split /\n/, $r->content )
	{
		my( $v, $mt, $url ) = split /\t/, $_;
		$existing{$mt} = $url;
	}

	return %existing;
}
