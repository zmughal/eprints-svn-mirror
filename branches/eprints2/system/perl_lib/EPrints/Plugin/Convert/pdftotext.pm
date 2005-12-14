package EPrints::Plugin::Convert::pdftotext;

=pod

=head1 NAME

EPrints::Plugin::Convert::pdftotext - Convert Adobe PDFs to plain-text using xpdf

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our $pdftotext = $EPrints::SystemSettings::conf->{executables}->{pdftotext};
carp "Path to pdftotext not set in EPrints::SystemSettings" unless $pdftotext;

our $ABSTRACT = 0;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();
	$d{id} = "convert/pdftotext";
	$d{name} = "Foolabs xpdf";
	$d{visible} = "all";
	return %d;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	return () unless $pdftotext;

	# Get the main file name
	my $fn = $doc->get_main();
	if( $fn =~ /\.pdf$/ ) {
		return ('text/plain');
	} else {
		return ();
	}
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	# What to call the temporary file
	my $fn = $doc->get_main;
	$fn =~ s/\.\w+$/\.txt/;
	
	# Call pdftotext to do the conversion
	system($pdftotext,
		"-enc","UTF-8",
		"-layout",
		$doc->local_path . '/' . $doc->get_main,
		$dir . '/' . $fn
	);

	unless( -e "$dir/$fn" ) {
		return undef;
	}
	
	return ($fn);
}

1;
