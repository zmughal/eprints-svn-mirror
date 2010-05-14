#!/usr/bin/perl -w

use strict;

=head1 NAME

internal_makemsi.pl - build a Win32 MSI package

=head1 SYNOPSIS

internal_makemsi.pl source_path to package_version package_desc package_file package_ext

=head1 DESCRIPTION

Building:


=cut

use Cwd;
use XML::LibXML;
use Getopt::Long;
use APR::UUID;
use Digest::MD5;
use Data::Dumper;
use File::Path;
use File::Copy qw( cp );
use Pod::Usage;

pod2usage( 2 ) if @ARGV < 6;

my( $source_path, $to, $package_version, $package_desc, $package_file, $package_ext ) = @ARGV;

my $build_path = "$to/$package_file";
File::Path::mkpath( $build_path );

my $build_root = $build_path;
$build_root =~ s/^.*\///;

our $VERSION = '1';
our $PRODUCT_TITLE = "EPrints";
our $PRODUCT_VERSION = $package_version;
our $PRODUCT_NAME = "$PRODUCT_TITLE $PRODUCT_VERSION Win32";
# The UUID for EPrints
our $PRODUCT_ID = 'a1818622-91d2-4b2d-bbee-df3c1910ae26';
# The UUID for all EPrints versions that can be upgraded by this package
our $PRODUCT_UPGRADE_CODE = '279218c7-39cd-4570-a10d-30c4baea0f6c';
our $PRODUCT_MANUFACTURER = "University of Southampton";
our $CYEAR = (gmtime())[5] + 1900;
our $MEDIA_CAB = "eprints.cab";
our $BASE_PATH = "C:/eprints";

if( $PRODUCT_VERSION =~ /\-r(\d+)/ )
{
	$PRODUCT_VERSION = "1.0.$1";
}

# Construct the EPrints installation tree

my $LICENSE_FILE = "$source_path/release/licenses/gpl.txt";
my $LICENSE_INLINE_FILE = "$source_path/release/licenses/gplin.txt";
my $COPYRIGHT_INLINE_FILE = "$source_path/release/licenses/copyright.txt";
my $GENERIC_POD = "$source_path/system/pod/generic.pod";

my %r = (
	"__VERSION__" => $PRODUCT_VERSION,
	"__COPYRIGHT__" => readfile( $COPYRIGHT_INLINE_FILE ),
	"__LICENSE__" => readfile( $LICENSE_INLINE_FILE ),
	"__GENERICPOD__" => readfile( $GENERIC_POD ),
);

for(qw( archives cfg lib cgi var tests perl_lib testdata ))
{
	installdir( $build_path, "$source_path/system/$_", %r );
}
for(qw( bin ))
{
	installdir( $build_path, "$source_path/system/$_",
		perl_lib => "$BASE_PATH/perl_lib",
		%r
	);
}

{
my $SystemSettings = {
	base_path => $BASE_PATH,
	version => $PRODUCT_NAME,
};

open(my $fh, ">", "$build_path/perl_lib/EPrints/SystemSettings.pm")
	or die "Error writing to $build_path/perl_lib/EPrints/SystemSettings.pm: $!";
print $fh Data::Dumper->Dump( [$SystemSettings], [qw( $EPrints::SystemSettings::conf )] );
close($fh);
}

our $LICENSE_FILE_RTF = $LICENSE_FILE;
$LICENSE_FILE_RTF =~ s/\.txt$/.rtf/;
cp($LICENSE_FILE_RTF, "$build_path/license.rtf");
for(qw( AUTHORS ))
{
	installfile("$source_path/system/$_", "$build_path/$_.txt");
}
installfile($LICENSE_FILE, "$build_path/COPYING.txt");

my $doc = XML::LibXML::Document->new( '1.0', 'utf-8' );

my $Wix = $doc->createElementNS( 'http://schemas.microsoft.com/wix/2006/wi', 'Wix' );
$doc->setDocumentElement( $Wix );

my $Product = $doc->createElement( 'Product' );
$Wix->appendChild( $Product );
$Product->setAttribute( Name => $PRODUCT_NAME );
$Product->setAttribute( Id => $PRODUCT_ID );
$Product->setAttribute( UpgradeCode => $PRODUCT_UPGRADE_CODE );
$Product->setAttribute( Language => 1033 );
$Product->setAttribute( Codepage => 1252 );
$Product->setAttribute( Version => $PRODUCT_VERSION );
$Product->setAttribute( Manufacturer => $PRODUCT_MANUFACTURER );

my $Package = $doc->createElement( 'Package' );
$Product->appendChild( $Package );
$Package->setAttribute( Id => '*' );
$Package->setAttribute( Keywords => 'Installer' );
$Package->setAttribute( Description => "$PRODUCT_NAME Installer" );
$Package->setAttribute( Comments => "Copyright $CYEAR $PRODUCT_MANUFACTURER" );
$Package->setAttribute( Manufacturer => $PRODUCT_MANUFACTURER );
$Package->setAttribute( InstallerVersion => 301 );
$Package->setAttribute( Languages => 1033 );
$Package->setAttribute( Compressed => 'yes' );
$Package->setAttribute( SummaryCodepage => 1252 );

{
my $Condition = $doc->createElement( 'Condition' );
$Product->appendChild( $Condition );
$Condition->setAttribute( Message => 'Requires Windows 2000 or later' );
$Condition->appendChild( $doc->createTextNode( 'VersionNT >= 500' ) );
}
{
my $Condition = $doc->createElement( 'Condition' );
$Product->appendChild( $Condition );
$Condition->setAttribute( Message => 'Requires administrator user' );
$Condition->appendChild( $doc->createTextNode( 'Privileged' ) );
}

my $Media = $doc->createElement( 'Media' );
$Product->appendChild( $Media );
$Media->setAttribute( Id => 1 );
$Media->setAttribute( Cabinet => $MEDIA_CAB );
$Media->setAttribute( EmbedCab => 'yes' );
$Media->setAttribute( DiskPrompt => 'CD-ROM #1' );

{
my $Property = $doc->createElement( 'Property' );
$Product->appendChild( $Property );
$Property->setAttribute( Id => 'DiskPrompt' );
$Property->setAttribute( Value => "$PRODUCT_NAME Installer [1]" );
}

my $TARGETDIR = $doc->createElement( 'Directory' );
$Product->appendChild( $TARGETDIR );
$TARGETDIR->setAttribute( Id => 'TARGETDIR' );
$TARGETDIR->setAttribute( Name => 'SourceDir' );

my $INSTALLDIR = $doc->createElement( 'Directory' );
$TARGETDIR->appendChild( $INSTALLDIR );
$INSTALLDIR->setAttribute( Id => 'INSTALLDIR' );
$INSTALLDIR->setAttribute( Name => 'eprints' );

my $Feature = $doc->createElement( 'Feature' );
$Product->appendChild( $Feature );
$Feature->setAttribute( Id => 'Complete' );
$Feature->setAttribute( Level => 1 );
$Feature->setAttribute( Title => $PRODUCT_TITLE );
$Feature->setAttribute( Description => $PRODUCT_NAME );
$Feature->setAttribute( Display => 'expand' );

{
my $UIRef = $doc->createElement( 'UIRef' );
$Product->appendChild( $UIRef );
$UIRef->setAttribute( Id => 'WixUI_Minimal' );
}

{
my $UIRef = $doc->createElement( 'UIRef' );
$Product->appendChild( $UIRef );
$UIRef->setAttribute( Id => 'WixUI_ErrorProgressText' );
}

{
my $WixVariable = $doc->createElement( 'WixVariable' );
$Product->appendChild( $WixVariable );
$WixVariable->setAttribute( Id => 'WixUILicenseRtf' );
$WixVariable->setAttribute( Value => ".\\license.rtf" );
}

{
my $Component = $doc->createElement( 'Component' );
$INSTALLDIR->appendChild( $Component );
$Component->setAttribute( Id => 'PerlLibComponent' );
$Component->setAttribute( Guid => &uuid );
$Component->setAttribute( SharedDllRefCount => 'no' );
$Component->setAttribute( KeyPath => 'yes' );
my $ComponentRef = $doc->createElement( 'ComponentRef' );
$Feature->appendChild( $ComponentRef );
$ComponentRef->setAttribute( Id => 'PerlLibComponent' );
my $Environment = $doc->createElement( 'Environment' );
$Component->appendChild( $Environment );
$Environment->setAttribute( Id => 'PerlLibPath' );
$Environment->setAttribute( Name => 'PERL5LIB' );
$Environment->setAttribute( Action => 'set' );
$Environment->setAttribute( System => 'yes' );
$Environment->setAttribute( Part => 'last' );
$Environment->setAttribute( Separator => ':' );
$Environment->setAttribute( Value => '[INSTALLDIR]\\perl_lib' );
}

{
my $Component = $doc->createElement( 'Component' );
$INSTALLDIR->appendChild( $Component );
$Component->setAttribute( Id => 'IndexerComponent' );
$Component->setAttribute( Guid => &uuid );
$Component->setAttribute( SharedDllRefCount => 'no' );
$Component->setAttribute( KeyPath => 'no' );
$Component->setAttribute( NeverOverwrite => 'no' );
$Component->setAttribute( Permanent => 'no' );
$Component->setAttribute( Transitive => 'no' );
$Component->setAttribute( Win64 => 'no' );
$Component->setAttribute( Location => 'either' );
my $ComponentRef = $doc->createElement( 'ComponentRef' );
$Feature->appendChild( $ComponentRef );
$ComponentRef->setAttribute( Id => 'IndexerComponent' );
my $File = $doc->createElement( 'File' );
$Component->appendChild( $File );
$File->setAttribute( Id => 'SrvAnyExe' );
$File->setAttribute( Name => 'srvany.exe' );
$File->setAttribute( Source => 'srvany.exe' );
$File->setAttribute( KeyPath => 'yes' );
my $ServiceInstall = $doc->createElement( 'ServiceInstall' );
$Component->appendChild( $ServiceInstall );
$ServiceInstall->setAttribute( Id => 'IndexerInstall' );
$ServiceInstall->setAttribute( DisplayName => "$PRODUCT_TITLE Indexer" );
$ServiceInstall->setAttribute( Description => "Background processes including indexing and thumbnail generation." );
$ServiceInstall->setAttribute( ErrorControl => 'normal' );
$ServiceInstall->setAttribute( Interactive => 'no' );
$ServiceInstall->setAttribute( Name => 'EPrintsIndexer' );
$ServiceInstall->setAttribute( Start => 'auto' );
$ServiceInstall->setAttribute( Type => 'ownProcess' );
$ServiceInstall->setAttribute( Vital => 'yes' );
my $ServiceControl = $doc->createElement( 'ServiceControl' );
$Component->appendChild( $ServiceControl );
$ServiceControl->setAttribute( Id => 'IndexerControl' );
$ServiceControl->setAttribute( Name => 'EPrintsIndexer' );
#$ServiceControl->setAttribute( Start => 'install' );
$ServiceControl->setAttribute( Stop => 'uninstall' );
$ServiceControl->setAttribute( Remove => 'uninstall' );
my $RegistryKey = $doc->createElement( 'RegistryKey' );
$Component->appendChild( $RegistryKey );
$RegistryKey->setAttribute( Action => 'createAndRemoveOnUninstall' );
$RegistryKey->setAttribute( Root => 'HKLM' );
$RegistryKey->setAttribute( Key => 'SYSTEM\CurrentControlSet\services\EPrintsIndexer\Parameters' );
{
my $RegistryValue = $doc->createElement( 'RegistryValue' );
$RegistryKey->appendChild( $RegistryValue );
$RegistryValue->setAttribute( Name => 'AppDirectory' );
$RegistryValue->setAttribute( Type => 'string' );
$RegistryValue->setAttribute( Value => '[INSTALLDIR]' );
}
{
my $RegistryValue = $doc->createElement( 'RegistryValue' );
$RegistryKey->appendChild( $RegistryValue );
$RegistryValue->setAttribute( Name => 'Application' );
$RegistryValue->setAttribute( Type => 'string' );
$RegistryValue->setAttribute( Value => 'C:\Perl\bin\perl.exe' );
}
{
my $RegistryValue = $doc->createElement( 'RegistryValue' );
$RegistryKey->appendChild( $RegistryValue );
$RegistryValue->setAttribute( Name => 'AppParameters' );
$RegistryValue->setAttribute( Type => 'string' );
$RegistryValue->setAttribute( Value => '[INSTALLDIR]bin\indexer --notdaemon start' );
}
}

parse_path( $build_path, ".", $INSTALLDIR );

{
open(my $fh, ">", "$build_path/eprints.wsx") or die "Error writing to eprints.wsx: $!";
print $fh $doc->toString( 1 );
close($fh);
}

{
open(my $fh, ">", "$build_path/BUILD.txt") or die "$build_path/BUILD.txt: $!";
binmode($fh, ":crlf");
print $fh <<EOB;
Copy srvany.exe to build directory then:

> candle eprints.wsx
> light -ext WixUIExtension eprints.wixobj
EOB
close($fh);
}

{
my $cwd = getcwd();
chdir($to);

my $package = "${package_file}${package_ext}";
unlink($package);
if( $package_ext eq ".zip" )
{
	0 == system("zip", "-9", "-q", "-r", $package, $package_file)
		or die("Couldn't zip up $package");
}
elsif( $package_ext eq ".tar.bz2" )
{
	0 == system("tar", "cjf", $package, $package_file)
		or die("Couldn't tar.bzip up $package");
}
elsif( $package_ext eq ".tar.gz" )
{
	0 == system("tar", "czf", $package, $package_file)
		or die("Couldn't tar.gz up $package");
}
else
{
	die "Dunno what to do with file extension $package_ext";
}

chdir($cwd);
rename("$to/$package", $package);
}

File::Path::rmtree( $to );

sub uuid
{
	return APR::UUID->new->format;
}

sub digest
{
	return Digest::MD5::md5_hex( $_[0] );
}

sub parse_path
{
	my( $path, $rel_path, $parent_dir ) = @_;

	my $cmp_id = 'cmp'.&digest( $rel_path );
	my $Component = $doc->createElement( 'Component' );
	$parent_dir->appendChild( $Component );
	$Component->setAttribute( Id => $cmp_id );
	$Component->setAttribute( Guid => &uuid );

	my $ComponentRef = $doc->createElement( 'ComponentRef' );
	$Feature->appendChild( $ComponentRef );
	$ComponentRef->setAttribute( Id => $cmp_id );

	opendir(my $dir, $path) or die "Error opening $path: $!";
	my @dirs;
	my $first = 1;
	while(defined($_ = readdir($dir)))
	{
		next if /^\./;
		next if $_ eq 'CVS';
		if( -d "$path/$_" )
		{
			push @dirs, $_;
		}
		elsif( -f _ )
		{
			my $fn = "$rel_path\\$_";
			my $File = $doc->createElement( 'File' );
			$Component->appendChild( $File );
			$File->setAttribute( Id => 'file'.&digest( $fn ) );
			$File->setAttribute( KeyPath => 'yes' ), $first=0 if $first;
			$File->setAttribute( Source => $fn );
		}
	}
	closedir($dir);

	if( $first )
	{
		my $CreateFolder = $doc->createElement( 'CreateFolder' );
		$Component->appendChild( $CreateFolder );
		$Component->setAttribute( SharedDllRefCount => 'no' );
		if( @dirs )
		{
			$Component->setAttribute( KeyPath => 'yes' );
		}
		else
		{
			$Component->setAttribute( KeyPath => 'no' );
			$Component->setAttribute( NeverOverwrite => 'no' );
			$Component->setAttribute( Permanent => 'no' );
			$Component->setAttribute( Transitive => 'no' );
			$Component->setAttribute( Win64 => 'no' );
			$Component->setAttribute( Location => 'either' );
		}
	}

	for(@dirs)
	{
		my $Directory = $doc->createElement( 'Directory' );
		$parent_dir->appendChild( $Directory );
		$Directory->setAttribute( Id => 'dir'.&digest( "$rel_path\\$_" ) );
		$Directory->setAttribute( Name => $_ );
		parse_path( "$path/$_", "$rel_path\\$_", $Directory );
	}
}

sub installfile
{
	my( $target, $source, %opts ) = @_;

	if(
		$source =~ m/\.(pl|pm|spec|js|css|xml)$/ ||
		-x $source
	  )
	{
		open(my $fh, "<", $source) or die "Error opening $source: $!";
		my @lines = <$fh>;
		close($fh);
		open($fh, ">", $target) or die "Error opening $target: $!";
		close($fh), return if !scalar @lines;
		binmode($fh, ":crlf");
		if( $opts{perl_lib} && $lines[0] =~ /^#!\S*\bperl/ )
		{
			shift @lines;
			print $fh "#!/usr/bin/perl -I$opts{perl_lib}\n";
		}
		my $in_copyright = 0;
		for(@lines)
		{
			if( /(__[A-Z]+__)/ && exists $opts{$1} )
			{
				$in_copyright=1 if $1 eq "__COPYRIGHT__";
				$in_copyright=0 if $1 eq "__LICENSE__";
				print $fh
					map { "$`$_$'" }
					ref($opts{$1}) eq "ARRAY" ?
					@{$opts{$1}} :
					$opts{$1};
			}
			elsif( !$in_copyright )
			{
				print $fh $_;
			}
		}
		close($fh);
	}
	else
	{
		cp( $source, $target );
	}
}

sub installdir
{
	my( $target, $source, %opts ) = @_;

	my( $cdir ) = $source =~ /([^\/]+)$/;
	$target = "$target/$cdir";
	mkpath( $target );

	my @dirs;
	opendir(my $dir, $source) or die "Error opening $source: $!";
	while(defined(my $fn = readdir($dir)))
	{
		next if $fn =~ /^\./;
		next if $fn eq "CVS";
		if( -d "$source/$fn" )
		{
			push @dirs, $fn;
		}
		elsif( -f _ )
		{
			installfile( "$target/$fn", "$source/$fn", %opts );
		}
	}
	closedir( $dir );

	foreach my $fn (@dirs)
	{
		installdir( $target, "$source/$fn", %opts );
	}
}

sub readfile
{
	local( *FH );
	open( FH, "<", $_[0] ) or die "Can't read $_[0]: $!";
	my @lines = <FH>;
	return \@lines;
}

