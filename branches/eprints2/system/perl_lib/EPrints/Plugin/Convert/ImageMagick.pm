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
	$d{name} = "ImageMagick";
	$d{visible} = "all";
	return %d;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	my $convert = $plugin->archive->get_conf( 'executables', 'convert' ) or return ();

	# Get the main file name
	my $fn = $doc->get_main();
	if( $fn =~ /\.($EXTENSIONS_RE)$/o ) {
		return values %FORMATS;
	} else {
		return ();
	}
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	my $convert = $plugin->archive->get_conf( 'executables', 'convert' ) or return ();

	# What to call the temporary file
	my $ext = $FORMATS_PREF{$type};
	my $fn = $doc->get_main;
	$fn =~ s/\.\w+$/\.$ext/;
	
	# Call imagemagick to do the conversion
	system($convert,
		$doc->local_path . '/' . $doc->get_main,
		$dir . '/' . $fn
	);

	unless( -e "$dir/$fn" ) {
		return ();
	}
	
	return ($fn);
}

1;
