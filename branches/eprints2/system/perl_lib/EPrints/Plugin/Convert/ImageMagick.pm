package EPrints::Plugin::Convert::ImageMagick;

=pod

=head1 NAME

EPrints::Plugin::Convert::ImageMagick - Example conversion plugin

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our $CONVERT = $EPrints::SystemSettings::conf->{executables}->{convert};
carp "Path to convert not set in EPrints::SystemSettings" unless $CONVERT;

our $ABSTRACT = 0;

our (%FORMATS, @ORDERED, %FORMATS_PREF);
@ORDERED = %FORMATS = qw(
bmp mage/bmp
gif image/gif
ief image/ief
jpeg image/jpeg
jpe image/jpeg
jpg image/jpeg
png image/png
tiff image/tiff
tif image/tiff
pnm image/x-portable-anymap
pbm image/x-portable-bitmap
pgm image/x-portable-graymap
ppm image/x-portable-pixmap
pdf application/pdf
);
for(my $i = 0; $i < @ORDERED; $i+=2)
{
	$FORMATS_PREF{$ORDERED[$i+1]} = $ORDERED[$i];
}
our $EXTENSIONS_RE = join '|', keys %FORMATS;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();
	$d{id} = "convert/imagemagick";
	$d{name} = "ImageMagick-based conversions";
	$d{visible} = "all";
	return %d;
}

sub type
{
	return "convert";
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	return () unless $CONVERT;

	# Get the main file name
	my $fn = $doc->get_main();
	if( $fn =~ /\.($EXTENSIONS_RE)$/o ) {
		return values %FORMATS;
	} else {
		return ();
	}
}

sub convert
{
	my ( $plugin, $eprint, $doc, $type ) = @_;

	return undef unless $CONVERT;

	my $session = $plugin->{session};

	# Location to store the temporary file
	my $dir = SUPER::_getconvertdir();
	
	# What to call the temporary file
	my $ext = $FORMATS_PREF{$type};
	my $fn = $doc->get_main;
	$fn =~ s/\.\w+$/\.$ext/;
	
	# Call imagemagick to do the conversion
	system($CONVERT,
		$doc->local_path . '/' . $doc->get_main,
		$dir . '/' . $fn
	);

	if( !-e ($dir . '/' . $fn) ) {
		return undef;
	}
	
	my $new_doc = EPrints::Document->create( $session, $eprint );
	
	$new_doc->set_format( $type );
	$new_doc->set_desc( 'ImageMagick conversion from ' . $doc->get_type . ' to ' . $type );
	$new_doc->add_file( $fn );
	$new_doc->commit;

	return $new_doc;
}

1;
