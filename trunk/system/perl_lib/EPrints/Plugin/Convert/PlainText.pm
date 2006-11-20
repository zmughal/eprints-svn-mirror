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
use English;
use Unicode::String;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our $ABSTRACT = 0;

# xml = ?
our %APPS = qw(
pdf		pdftotext
doc		antiword
htm		elinks
html		elinks
xml		elinks
ps		ps2ascii
txt		_special
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

	if( $fn =~ /\.txt$/ )
	{
		return @type;
	}

	keys(%APPS);
	while( my( $ext, $app ) = each %APPS )
	{
		if( $fn =~ /\.$ext$/ and defined($plugin->get_repository->get_conf( "executables", $app )) ) {
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
		if( $main =~ /\.$ext$/ and defined($plugin->get_repository->get_conf( "executables", $app )) ) {
			$bin = $plugin->get_repository->get_conf( "executables", $app );
			last if defined($bin);
		}
	}
	return () unless defined($bin);
	
	my $invo = $plugin->get_repository->get_conf( "invocation", $app );
	$invo ||= "\$($app) \$(SOURCE) \$(TARGET)";
	
	my %files = $doc->files;
	my @txt_files;
	foreach my $fn ( keys %files )
	{
		my $tgt = $fn;
		next unless $tgt =~ s/\.$ext$/\.txt/;
		my $infile = EPrints::Utils::join_path( $doc->local_path, $fn );
		my $outfile = EPrints::Utils::join_path( $dir, $tgt );
		
		if( $ext eq 'txt' )
		{
			# PerlIO
			if( $PERL_VERSION gt v5.8.0 )
			{
				open( my $fh, "<:encoding(iso-8859-1)", $infile );
				open( my $fo, ">:utf8", $outfile );
				while(<$fh>) { print $fo $_ }
				close( $fh ); close( $fo );
			}
			# Unicode::String
			else
			{
				open( my $fh, "<", $infile );
				open( my $fo, ">", $outfile );
				while(<$fh>) { print $fo Unicode::String::latin1($_)->utf8; }
				close( $fh ); close( $fo );
			}
		}
		else
		{
			my $cmd = EPrints::Utils::prepare_cmd( $invo,
				$app => $bin,
				SOURCE_DIR => $doc->local_path,
				SOURCE => $infile,
				TARGET_DIR => $dir,
				TARGET => $outfile,
			);
			system( $cmd );
		}
		
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
