package IRStats::Visualisation::Table::HTML;

use strict;
use warnings;

#table data is a hash containing:
#
#	title => The title of the table
#	columns => The text/html to put into the column heading
#	rows => an array of arrays containing row data
#	totals => a row of data for totals (optional)


use IRStats::Visualisation::Table;

our @ISA = qw(IRStats::Visualisation::Table);


sub new
{
        my ($class, $data) = @_;
        my $self = $class->SUPER::new($data);

        return $self;
}

sub render
{
	my ($self) = @_;

	if (scalar @{$self->{'rows'}} < 1)
	{
		return '<div class="irstats_table">None</div>';
	}

	my $html = '<div class="irstats_table">';
	$html .= "<table>\n";
	$html .= "<tr class=\"headings\"><td>";
	
	$html .= join ("</td><td>",@{$self->{'columns'}});
	$html .= "</td></tr>\n";
	foreach (@{$self->{'rows'}})
	{
		$html .= "<tr><td>";
		$html .= join("</td><td>", @{$_});
		$html .= "</td></tr>\n";
	}

	if (defined @{$self->{'totals'}})
	{
		$html .= '<tr class = "totals"><td>';
		$html .= join ("</td><td>",@{$self->{'totals'}});
		$html .= "</td></tr>\n";
	}

	$html .= "</table>\n";
	$html .= "</div>\n";
	return $html;
}

1;
