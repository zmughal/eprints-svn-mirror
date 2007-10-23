package IRStats::Visualisation::Graph::Line;

use strict;
use warnings;

use IRStats::Visualisation::Graph::GraphLegend;
use Data::Dumper;
use perlchartdir;
use IRStats::Visualisation::Graph;
#use IRStats::Visualisation;

# A graph object expects the following in the data hash:
#
#	type -> e.g line, bar, pie
#	title -> the title of the graph
#	x_title -> the x axis title
#	y_title -> the y axis title
#	x_labels -> the labels for the x axis
#	data_series -> the data, an array a hash for each series:
#		citation -> the title of the series (plain text or html) for the legend
#		data -> an array containing the data
#	filename -> the filename (should be the params id)
#
#
#


our @ISA = qw/ IRStats::Visualisation::Graph /;

sub new
{
	my ($class, $data) = @_;
	my $self = $class->SUPER::new($data);

	return $self;
}


sub render
{
	my ($self) = @_;

	my $c = new XYChart(600, 300, 0xeeeeff, 0x000000, 1);
	$c->setRoundedFrame();
	$c->setPlotArea(55, 58, 520, 195, 0xffffff, -1, -1, 0xcccccc, 0xcccccc);
	$c->addTitle($self->{'title'}, "timesbi.ttf", 15)->setBackground(0xccccff, 0x000000, perlchartdir::glassEffect());

	$c->yAxis()->setTitle($self->{'y_title'});
	$c->xAxis()->setTitle($self->{'x_title'});
	$c->xAxis()->setLabels($self->{'x_labels'});

	{
		use integer;
		$c->xAxis()->setLabelStep((($#{$self->{x_labels}}+1)/13)+1);
	}

	my $layer = $c->addLineLayer2($perlchartdir::Stack);
	foreach my $i (0 .. $#{$self->{'data_series'}})
	{
		$layer->addDataSet($self->{'data_series'}->[$i]->{'data'}, $self->{'colours'}->[$i]);
	}
	$layer->setLineWidth(2);
	$c->makeChart($self->{'path'} . $self->{'filename'});

	my $legend = IRStats::Visualisation::Graph::GraphLegend->new($self->{'data_series'}, $self->{'colours'});
	return "<div id=\"line_graph\">
		<table><tr>
		<td>
		<img class=\"chart\" src = \"$self->{'url_relative'}\" />
		</td>
		<td>" .
		$legend->render() .
		"</td>
		</tr></table>
		</div>";

}

1;

