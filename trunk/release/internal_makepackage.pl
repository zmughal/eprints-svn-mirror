#!/usr/bin/perl -w

use Cwd;
use strict;

# nb.
#
# cvs tag eprints2-2-99-0 system docs_ep2
#
# ./makepackage.pl  eprints2-2-99-0
#
# scp eprints-2.2.99.0-alpha.tar.gz webmaster@www:/home/www.eprints/software/files/eprints2/

my %codenames= ();
my %ids = ();
open( VERSIONS, "versions.txt" ) || die "can't open versions.txt: $!";
while(<VERSIONS>)
{
	chomp;
	$_ =~ s/\s*#.*$//;
	next if( $_ eq "" );
	$_ =~ m/^\s*([^\s]*)\s*([^\s]*)\s*(.*)\s*$/;
	$ids{$1} = $2;
	$codenames{$1} = $3;
}
close VERSIONS;

my( $type, $install_from, $to ) = @ARGV;

if( !defined $type || $type eq "" ) 
{ 
	print "NO TYPE!\n"; 
	exit 1; 
}

my $package_version;
my $package_desc;
my $package_file;

my $date = `date +%Y-%m-%d`;
chomp $date;

if( $type eq "nightly" ) 
{ 
	$package_version = "eprints-3-build-".$date;
	$package_desc = "EPrints Nightly Build - $package_version";
	$package_file = "eprints-3-build-$date";
}
else
{
	if( !defined $codenames{$type} )
	{
		print "Unknown codename\n";
		print "Available:\n".join("\n",sort keys %codenames)."\n\n";
		exit;
	}
	$package_version = $ids{$type};
	$package_desc = "EPrints ".$ids{$type}." (".$codenames{$type}.") [Born on $date]";
	$package_file = "eprints-".$ids{$type};
	print "YAY - $ids{$type}\n";
}

#my $whoami = `whoami`;
#chomp $whoami;
#$ENV{"CVSROOT"} = ":pserver:$whoami\@cvs.iam.ecs.soton.ac.uk:/home/iamcvs/CVS";





erase_dir( $to ) if -d $to;

print "Making directories...\n";
mkdir($to) or die "Couldn't create package directory\n";
mkdir($to."/eprints") or die "Couldn't eprints directory\n";

print "Building configure files\n";
cmd("cd $install_from/release; ./autogen.sh" );

my $LICENSE_FILE = "$install_from/release/licenses/gpl.txt";
my $LICENSE_INLINE_FILE = "$install_from/release/licenses/gplin.txt";


print "Inserting license...\n";
cmd("cp $LICENSE_FILE $to/eprints/COPYING");

my %r = (
	"__VERSION__"=>$package_version,
	"__LICENSE__"=>readfile( $LICENSE_INLINE_FILE ),
	"__GENERICPOD__"=>readfile( "$install_from/system/pod/generic.pod" ),
	"__TARBALL__"=>$package_file,
);

print "Inserting configure and install scripts...\n";
cmd("cp $install_from/release/configure $to/eprints/configure");
cmd("cp $install_from/release/install.pl.in $to/eprints/install.pl.in");
cmd("cp $install_from/release/df-check.pl $to/eprints/df-check.pl");
cmd("cp $install_from/release/cgi-check.pl $to/eprints/cgi-check.pl");
cmd("cp $install_from/release/perlmodules.pl $to/eprints/perlmodules.pl");
cmd("cp $install_from/release/Makefile $to/eprints/Makefile");
copyfile("$install_from/release/eprints3.spec","$to/eprints/eprints3.spec", \%r);
cmd("cp $install_from/release/rpmpatch.sh $to/eprints/rpmpatch.sh");

print "Inserting top level text files...\n";
cmd("cp $install_from/system/CHANGELOG $to/eprints/CHANGELOG");
cmd("cp $install_from/system/README $to/eprints/README");
cmd("cp $install_from/system/AUTHORS $to/eprints/AUTHORS");
cmd("cp $install_from/system/NEWS $to/eprints/NEWS");

copydir( "$install_from/system/bin", "$to/eprints/bin", \%r );
copydir( "$install_from/system/cfg", "$to/eprints/cfg", \%r );
copydir( "$install_from/system/lib", "$to/eprints/lib", \%r );
copydir( "$install_from/system/cgi", "$to/eprints/cgi", \%r );
copydir( "$install_from/system/lib", "$to/eprints/lib", \%r );
copydir( "$install_from/system/var", "$to/eprints/var", \%r );
copydir( "$install_from/system/defaultcfg", "$to/eprints/defaultcfg", \%r );
copydir( "$install_from/system/perl_lib", "$to/eprints/perl_lib", \%r );
copydir( "$install_from/system/testdata", "$to/eprints/testdata", \%r );

if( -e "$to/eprints/perl_lib/EPrints/SystemSettings.pm" )
{
	cmd("rm $to/eprints/perl_lib/EPrints/SystemSettings.pm");
}

# documentation
#cmd("cd $from/docs/; ./mkdocs.pl");
#cmd("mv $from/docs/docs $to/eprints/docs");

# VERSION file.
open(FILEOUT, ">$to/eprints/VERSION");
print FILEOUT $package_version."\n";
print FILEOUT $package_desc."\n";
close(FILEOUT);

cmd("chmod -R g-w $to/eprints")==0 or die("Couldn't change permissions on eprints dir.\n");

cmd("mv $to/eprints $to/$package_file")==0 or die("Couldn't move eprints dir to $to/$package_file.\n");
my $tarfile = $package_file.".tar.gz";
if( -e $tarfile ) { cmd( "rm $tarfile" ); }
cmd("cd $to; tar czf ../$tarfile $package_file")==0 or die("Couldn't tar up $to/$package_file");


print "Removing: $to\n";
erase_dir( $to ) if -d $to;

exit;

sub copydir
{
	my( $fromdir, $todir, $r, $mlr ) = @_;

	unless( -d $todir ) { mkdir( $todir ); }
	
	my $dh;
	opendir( $dh, $fromdir );
	while( my $file = readdir( $dh ) )
	{
		next if( $file =~ m/^\./ );

		if( -d "$fromdir/$file" )
		{
			copydir( "$fromdir/$file", "$todir/$file", $r );
		}	
		else
		{
			copyfile( "$fromdir/$file", "$todir/$file", $r );
		}
	}
	closedir( $dh );
}

copydir( "$install_from/system/bin", "$to/eprints/bin", \%r );
copydir( "$install_from/system/cfg", "$to/eprints/cfg", \%r );
copydir( "$install_from/system/lib", "$to/eprints/lib", \%r );
copydir( "$install_from/system/cgi", "$to/eprints/cgi", \%r );
copydir( "$install_from/system/lib", "$to/eprints/lib", \%r );
copydir( "$install_from/system/var", "$to/eprints/var", \%r );
copydir( "$install_from/system/defaultcfg", "$to/eprints/defaultcfg", \%r );
copydir( "$install_from/system/perl_lib", "$to/eprints/perl_lib", \%r );
copydir( "$install_from/system/testdata", "$to/eprints/testdata", \%r );

sub copyfile
{
	my( $from, $to, $r ) = @_;

	my $textfile = 0;
	my $f = substr($from, length($install_from));

	if( $f =~ m/\/system\/cgi\// ) { $textfile = 1; }	
	if( $f =~ m/\/system\/bin\// ) { $textfile = 1; }
	if( $f =~ m/\.pl$/ ) { $textfile = 1; }
	if( $f =~ m/\.pm$/ ) { $textfile = 1; }
	if( $f =~ m/\.spec$/ ) { $textfile = 1; }

	if( !$textfile )
	{
		my $cmd = "cp $from $to";
		`$cmd`;
		return;
	}	

	my $data = readfile( $from );

	insert_data( $data, "__GENERICPOD__", $r->{__GENERICPOD__}, 1 );
	insert_data( $data, "__LICENSE__", $r->{__LICENSE__}, 1 );
	insert_data( $data, "__VERSION__", $r->{__VERSION__}, 0 );
	insert_data( $data, "__TARBALL__", $r->{__TARBALL__}, 0 );

	open OUT, ">$to" or die "Unable to open output file.\n";
	print OUT join( "", @{$data} );
	close OUT;
}

sub insert_data
{
	my( $data, $key, $value, $multiline ) = @_;

	unless( $multiline )
	{
		foreach( @{$data} )
		{
			s/$key/$value/g;
		}
		return;
	}

	my @new = ();
	foreach( @{$data} )
	{
		unless( m/$key/ )
		{
			push @new, $_;
			next;
		}

		foreach my $rline ( @{$value} )
		{
			chomp $rline;
			my $l2 = $_;
			$l2=~s/$key/$rline/;
			push @new, $l2;
		}
	}

	@{$data} = @new;
}

sub readfile
{
	my( $file ) = @_;

	open( F, $file ) || die "Can't read $file";
	my @f = <F>;
	close F;

	return \@f;
}

sub erase_dir
{
	my( $dirname ) = @_;

	if (-d $dirname )
	{
		cmd( "/bin/rm -rf ".$dirname ) == 0 or 
			die "Couldn't remove ".$dirname." dir.\n";
	}
}
	

sub cmd
{
	my( $cmd ) = @_;

	print "$cmd\n";

	return system( $cmd );
}

