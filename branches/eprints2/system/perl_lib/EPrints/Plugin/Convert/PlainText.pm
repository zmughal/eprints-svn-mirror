package EPrints::Plugin::Convert::PlainText;

=pod

=head1 NAME

EPrints::Plugin::Convert::PlainText - Convert documents to plain-text

=head1 DESCRIPTION

Uses the file extension to determine file type.

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our $ABSTRACT = 0;

our %APPS = qw(
pdf		pdftotext
doc		antiword
htm		elinks
html	elinks
ps		ps2ascii
);

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Plain text conversion";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	# Get the main file name
	my $fn = $doc->get_main();

	my @type = ('text/plain' => {
		plugin => $plugin,
		encoding => 'utf-8',
		phraseid => 'plaintext',
	});

	keys(%APPS);
	while( my( $ext, $app ) = each %APPS )
	{
		if( $fn =~ /\.$ext$/ and defined($plugin->archive->get_conf( "executables", $app )) ) {
			return @type;
		}
	}
	
	return ();
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	# What to call the temporary file
	my $main = $doc->get_main;
	
	my( $bin, $ext, $app );
	
	keys(%APPS);
	# Find the app to use
	while( ( $ext, $app ) = each %APPS )
	{
		if( $main =~ /\.$ext$/ and defined($plugin->archive->get_conf( "executables", $app )) ) {
			$bin = $plugin->archive->get_conf( "executables", $app );
			last if defined($bin);
		}
	}
	return () unless defined($bin);
	
	my $invo = $plugin->archive->get_conf( "invocation", $app );
	$invo ||= "\$($app) \$(SOURCE) \$(TARGET)";
	
	my %files = $doc->files;
	my @txt_files;
	foreach my $fn ( keys %files )
	{
		my $tgt = $fn;
		next unless $tgt =~ s/\.$ext$/\.txt/;
		
		my $cmd = EPrints::Utils::prepare_cmd( $invo,
			$app => $bin,
			SOURCE_DIR => $doc->local_path,
			SOURCE => EPrints::Utils::join_path( $doc->local_path, $fn ),
			TARGET_DIR => $dir,
			TARGET => EPrints::Utils::join_path( $dir, $tgt )
		);
		system( $cmd );
		
		if( -s EPrints::Utils::join_path( $dir, $tgt ) > 0 ) {
			if( $fn eq $doc->get_main ) {
				unshift @txt_files, $tgt;
			} else {
				push @txt_files, $tgt;
			}
		} elsif( $fn eq $doc->get_main ) {
			return ();
		}
	}

	return @txt_files;
}

1;
