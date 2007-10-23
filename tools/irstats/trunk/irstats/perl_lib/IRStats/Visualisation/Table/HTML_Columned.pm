package IRStats::Visualisation::Table::HTML_Columned;

use strict;
use warnings;

#table data is a hash containing:
#
#	title => The title of the table
#	columns => The text/html to put into the column heading
#	rows => an array of arrays containing row data
#	totals => a row of data for totals (optional)

#HTML_columned also takes a number of rows.  



use IRStats::Visualisation::Table;

our @ISA = qw(IRStats::Visualisation::Table);
my $default_number_of_rows = 15;

sub new
{
        my ($class, $data, $number_of_rows) = @_;
        my $self = $class->SUPER::new($data);
	$self->{'number_of_rows'} = ($number_of_rows ? $number_of_rows : $default_number_of_rows);
        return $self;
}

sub render
{
	my ($self) = @_;

	if (scalar @{$self->{'rows'}} < 1)
	{
		return '<div class="irstats_table">None</div>';
	}

	my $rows = [];
	foreach (@{$self->{'rows'}})
	{
		push @{$rows}, "<tr><td>" . join("</td><td>", @{$_}) . "</td></tr>";
	}
	if (defined @{$self->{'totals'}})
	{
		 push @{$rows},  '<tr class = "totals"><td>' . join ("</td><td>",@{$self->{'totals'}}) . "</td></tr>\n";
	}

	my $html = '<div class="irstats_column_table">';
	$html .= "<table class = \"columns\">";
	$html .= "<tr><td>";

	$html .= "<table>\n";
	$html .= "<tr class=\"headings\"><td>";
	$html .= join ("</td><td>",@{$self->{'columns'}});
	$html .= "</td></tr>\n";

	# adjust number of rows to minimise empty space in last column
	$self->{number_of_rows} = $self->calculate_number_of_rows( $self->{number_of_rows}, scalar @{$self->{'rows'}});
	my $i = 1;
	foreach my $row (@{$rows})
	{
		if ($i > $self->{number_of_rows})
		{
			$i = 1;
			$html .= "</table></td><td>";
			$html .= "<table>\n";
			$html .= "<tr class=\"headings\"><td>";
			$html .= join ("</td><td>",@{$self->{'columns'}});
			$html .= "</td></tr>\n";
		}
		$html .= $row;
		$i++;
	}

	foreach ($i ..  $self->{number_of_rows}) #pad the last table
	{
		$html .= "<tr><td>&nbsp;";
		foreach (0 .. $#{$self->{columns}})
		{
			$html .= "</td><td>&nbsp;";
		}
		$html .= "</td></tr>";
	}

	$html .= "</table>";
	$html .= "</td></tr>";
	$html .= "</table>\n";
	$html .= "</div>\n";
	return $html;
}

sub calculate_number_of_rows
#recursively finds the largest remainder
{
	my ($self, $column_size, $data_size) = @_;
	return $column_size if ( ($data_size % ($column_size + 1)) > ($data_size % $column_size ) );
	return $self->calculate_number_of_rows(($column_size - 1), $data_size);
}


1;
