package EPrints::Plugin::Convert::Thumbnail;

=pod

=head1 NAME

EPrints::Plugin::Convert::Thumbnail 

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our $ABSTRACT = 0;

our (%FORMATS, @ORDERED, %FORMATS_PREF);
@ORDERED = %FORMATS = qw(
bmp image/bmp
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
);
# formats pref maps mime type to file suffix. Last suffix
# in the list is used.
for(my $i = 0; $i < @ORDERED; $i+=2)
{
	$FORMATS_PREF{$ORDERED[$i+1]} = $ORDERED[$i];
}
our $EXTENSIONS_RE = join '|', keys %FORMATS;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Thumbnail";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	my $convert = $plugin->get_repository->get_conf( 'executables', 'convert' ) or return ();

	my %types;

	# Get the main file name
	my $fn = $doc->get_main();
	if( $fn =~ /\.($EXTENSIONS_RE)$/o ) 
	{
		$types{"thumbnail"} = { plugin => $plugin, };
	}

	return %types;
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	my $convert = $plugin->get_repository->get_conf( 'executables', 'convert' ) or return ();

	my $src = $doc->local_path . '/' . $doc->get_main;
	
	my $fn1 = $doc->get_id.".png";
	my $fn2 = $doc->get_id."_200.png";
	my $fn3 = $doc->get_id."_400.png";

	system($convert, "-thumbnail","66x50>", $src.'[66x50]', $dir . '/' . $fn1);
	system($convert, "-thumbnail","200x150>",$src.'[200x150]', $dir . '/' . $fn2);
	system($convert, "-thumbnail","400x300>", $src.'[400x300]', $dir . '/' . $fn3);

	unless( -e "$dir/$fn1" ) {
		return ();
	}
	
	return ($fn1);
}

1;
