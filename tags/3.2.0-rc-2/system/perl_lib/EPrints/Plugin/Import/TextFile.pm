package EPrints::Plugin::Import::TextFile;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

$EPrints::Plugin::Import::DISABLE = 1;

if( $^V gt v5.8.0 )
{
	eval "use File::BOM";
}

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base text input plugin: This should have been subclassed";
	$self->{visible} = "all";

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};

	if( $^V gt v5.8.0 and seek( $fh, 0, 1 ) )
	{
		# Strip the Byte Order Mark and set the encoding appropriately
		# See http://en.wikipedia.org/wiki/Byte_Order_Mark
		File::BOM::defuse($fh);

		# Read a line from the file handle and reset the fp
		my $start = tell( $fh );
		my $line = <$fh>;
		seek( $fh, $start, 0 )
			or die "Unable to reset file handle for crlf detection.";

		# If the line ends with return add the crlf layer
		if( $line =~ /\r$/ )
		{
			binmode( $fh, ":crlf" );
		}	
	}

	return $self->input_text_fh( %opts );
}

sub input_text_fh
{
	my( $self, %opts ) = @_;

	return undef;
}

1;