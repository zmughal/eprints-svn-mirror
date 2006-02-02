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

our $ABSTRACT = 0;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Foolabs xpdf";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	my $pdftotext = $plugin->archive->get_conf( 'executable', 'pdftotext' ) or return ();

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

	my $pdftotext = $plugin->archive->get_conf( 'executable', 'pdftotext' ) or return ();

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
		return ();
	}
	
	return ($fn);
}

1;
