#!/usr/bin/perl -w

# nb.
#
# cvs tag eprints2-2-99-0 system docs_ep2
#
# ./makepackage.pl  eprints2-2-99-0
#
# scp eprints-2.2.99.0-alpha.tar.gz webmaster@www:/home/www.eprints/software/files/eprints2/

=head1 NAME

B<internal_makepackage.pl> - Make an EPrints tarball

=head1 SYNOPSIS

B<internal_makepackage.pl> <from> <to> <version> <description> <filename> <extension> <rpm_vesrion>

=head1 ARGUMENTS

=over 4

=item I<version>

EPrints version to build or 'nightly' to build nightly version (current trunk HEAD).

=item I<from>

Directory to read the EPrints source from.

=item I<to>

Directory to write the EPrints distribution to.

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

=item B<--license-summary>

Filename to read license summary from (defaults to licenses/gplin.txt) - gets embedded wherever _B<>_LICENSE__ pragma occurs.

=item B<--list>

List all available versions.

=item B<--man>

Print the full manual page and then exit.

=item B<--revision>

Append a revision to the end of the output name.

=item B<--zip>

Use Zip as the packager (produces a .zip file).

=back

=cut

use Cwd;
use Getopt::Long;
use Pod::Usage;
use strict;

my( $opt_revision, $opt_license, $opt_license_summary, $opt_list, $opt_zip, $opt_bzip, $opt_help, $opt_man, $opt_branch, $opt_force );

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
) || pod2usage( 2 );

pod2usage( 1 ) if $opt_help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $opt_man;
pod2usage( 2 ) if( scalar @ARGV != 7 );

my( $install_from, $to, $package_version, $package_desc, $package_file, $package_ext, $rpm_version ) = @ARGV;

my $revision = $opt_revision ? "-r$opt_revision" : '';

my $LICENSE_FILE = $opt_license || "$install_from/release/licenses/gpl.txt";
my $LICENSE_INLINE_FILE = $opt_license_summary || "$install_from/release/licenses/gplin.txt";

erase_dir( $to ) if -d $to;

print "Making directories...\n";
mkdir($to) or die "Couldn't create package directory\n";
mkdir($to."/eprints") or die "Couldn't eprints directory\n";

print "Building configure files\n";
cmd("cd $install_from/release; ./autogen.sh" );

print "Inserting license...\n";
cmd("cp $LICENSE_FILE $to/eprints/COPYING");

my %r = (
	"__VERSION__"=>$package_version,
	"__LICENSE__"=>readfile( $LICENSE_INLINE_FILE ),
	"__GENERICPOD__"=>readfile( "$install_from/system/pod/generic.pod" ),
	"__RPMVERSION__"=>$rpm_version,
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
my $tarfile = $package_file.$package_ext;
if( -e $tarfile ) { cmd( "rm $tarfile" ); }
if( $opt_zip )
{
	0 == cmd("cd $to; zip -q -9 -r ../$tarfile $package_file")
		or die("Couldn't zip up $to/$package_file");
}
elsif( $opt_bzip )
{
	0 == cmd("cd $to; tar cjf ../$tarfile $package_file")
		or die("Couldn't zip up $to/$package_file");
}
else
{
	0 == cmd("cd $to; tar czf ../$tarfile $package_file")
		or die("Couldn't tar up $to/$package_file");
}


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

	foreach my $name (keys %$r)
	{
		insert_data( $data, $name, $r->{$name}, ref($r->{$name}) eq 'ARRAY' );
	}

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

