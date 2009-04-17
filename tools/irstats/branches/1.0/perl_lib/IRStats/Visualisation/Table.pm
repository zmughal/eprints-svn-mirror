package IRStats::Visualisation::Table;

use strict;
use warnings;

use IRStats::Visualisation;

#table data is a hash containing:
#
#	title => The title of the table
#	columns => The text/html to put into the column heading
#	rows => an array of arrays containing row data
#	totals => a row of data for totals (optional)

our @ISA = qw/ IRStats::Visualisation /;

sub new
{
	my ($class, $table_data) = @_;
	my $self = $class->SUPER::new($table_data);
	return $self;
}

1;
