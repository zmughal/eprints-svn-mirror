package Text::Scigen;

use 5.008001;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Text::Scigen ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.02';

use Carp;
use Text::Autoformat;
use Text::Scigen::scigen;

our $DATA_PATH = $INC{'Text/Scigen.pm'};
$DATA_PATH =~ s/Scigen\.pm$//;
$DATA_PATH .= "Scigen/";

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

sub new
{
	my( $class, %self ) = @_;

	Carp::croak( "Missing filename argument" )
		if !defined $self{filename};

	$self{filename} = "$DATA_PATH/$self{filename}"
		if $self{filename} !~ /^\//;

	$self{debug} ||= 0;

	$self{pretty} = 1 if !defined $self{pretty};

	if( open(my $fh, "<", $self{filename}) ) {
		Text::Scigen::scigen::read_rules (
			$fh,
			$self{dat} = {},
			\$self{RE},
			$self{debug}
		);
	}
	else {
		Carp::croak( "Error reading from $self{filename}: $!" );
	}

	return bless \%self, $class;
}

sub generate
{
	my( $self, $start ) = @_;

	$start = [$start] if ref($start) ne "ARRAY";

	return join "\n", map { Text::Scigen::scigen::generate (
		$self->{dat},
		$_,
		$self->{RE},
		$self->{debug},
		$self->{pretty}
	) } @$start;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Text::Scigen - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Text::Scigen;
  
  my $scigen = Text::Scigen->new(
  	filename => $filepath,
  );
  print $scigen->generate( LATEX_HEADING );

=head1 DESCRIPTION


=head2 EXPORT

None by default.



=head1 SEE ALSO

L<Text::Autoformat>

http://pdos.csail.mit.edu/scigen/

=head1 MAINTAINER

Tim Brody, E<lt>tdb2@ecs.soton.ac.uk<gt>

=head1 COPYRIGHT AND LICENSE

GPL 2 - SCIGEN

=cut
