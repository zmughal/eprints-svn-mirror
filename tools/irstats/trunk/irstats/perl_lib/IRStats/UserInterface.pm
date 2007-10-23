package IRStats::UserInterface;

use strict;
use warnings;

sub new
{
	my ($class, %self) = @_;
	return bless \%self, $class;
}

1;

