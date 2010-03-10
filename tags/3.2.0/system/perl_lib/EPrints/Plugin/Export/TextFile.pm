package EPrints::Plugin::Export::TextFile;

# This virtual super-class supports Unicode output

our @ISA = qw( EPrints::Plugin::Export );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{mimetype} = "text/plain; charset=utf-8";
	$self->{suffix} = ".txt";

	return $self;
}

sub initialise_fh
{
	my( $plugin, $fh ) = @_;

	binmode($fh, ":utf8");
}

# Windows Notepad and other text editors will use a BOM to determine the
# character encoding
sub byte_order_mark
{
	return chr(0xfeff);
}

1;
