package IRStats::Visualisation::Graph::GraphLegend;

use strict;

sub new
{
	my ($class, $data_series, $colours) = @_;

	return bless { data_series => $data_series, colours => $colours }, $class;

}


sub render
{
	my ($self) = @_;

	my $html = "<div class=\"legend_div\">\n";
	$html .= "<table>\n";
	foreach my $i (0 .. $#{$self->{'data_series'}})
	{
		$html .= "<tr>";
		$html .= "<td style=\"width: 10px; background-color: #". sprintf("%06x",$self->{'colours'}->[$i]) ."\">&nbsp;</td>";
		$html .= "<td>$self->{'data_series'}->[$i]->{'citation'}</td>";
		$html .= "</tr>\n";
	}
	$html .= "</table>";
	$html .= "</div>";
	return $html;
}

1;

