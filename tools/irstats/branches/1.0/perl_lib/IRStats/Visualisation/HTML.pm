package IRStats::Visualisation::HTML;

use strict;
use warnings;

use IRStats::Visualisation;

#html data is a hash containing:
#
# html => an HTML string

our @ISA = qw/ IRStats::Visualisation /;

sub new
{
	my ($class, $data) = @_;
	my $self = $class->SUPER::new($data);
	return $self;
}

sub render
{
	my ($self) = @_;
	return $self->{'html'};
}

1;
