package EPrints::Plugin::Convert::ImageMagick::ThumbnailDocuments;

=pod

=head1 NAME

EPrints::Plugin::Convert::ImageMagick::ThumbnailDocuments 

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our (%FORMATS, @ORDERED, %FORMATS_PREF);
@ORDERED = %FORMATS = qw(
pdf application/pdf
ps application/postscript
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

	$self->{name} = "Thumbnail Documents";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	my $convert = $plugin->get_repository->get_conf( 'executables', 'convert' ) or return ();

	my %types;

	# Get the main file name
	my $fn = $doc->get_main() or return ();

	if( $fn =~ /\.($EXTENSIONS_RE)$/oi ) 
	{
		$types{"thumbnail_preview"} = { plugin => $plugin, };
	}

	return %types;
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	my $convert = $plugin->get_repository->get_conf( 'executables', 'convert' ) or return ();

	my $src = $doc->local_path . '/' . $doc->get_main;
	
	my $fn = "preview.png";

	system($convert, "-thumbnail","400x300>", '-bordercolor', 'rgb(128,128,128)', '-border', '1', $src.'[0]', $dir . '/' . $fn);

	unless( -e "$dir/$fn" ) {
		return ();
	}

	EPrints::Utils::chown_for_eprints( "$dir/$fn" );
	
	return ($fn);
}

1;