package IRStats::Visualisation::Graph::Line;

use strict;

use IRStats::Visualisation::Graph::GraphLegend;
use IRStats::Visualisation::Graph;

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

sub quote_javascript
{
	my( $value ) = @_;
	$value =~ s/'/\\'/g;
	return "'$value'";
}


sub chartdirector_render
{
	my ($self) = @_;

	my $c = new XYChart(500, 300, 0xeeeeff, 0x000000, 1);
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

sub plotkit_render
{
	my ($self) = @_;

	my $base_url = $self->{params}->get('conf')->static_url;

	my $width = 490;

	# Quick hack to get a unique id
	my $canvas_id = $self->{filename};
	$canvas_id =~ s/\.png$//;

	my @x_labels = @{$self->{x_labels}};
	my @data = @{$self->{data_series}->[0]->{data}};
	my $label = quote_javascript($self->{data_series}->[0]->{citation} || '(null)');

	my @series;
	my @labels;

	my $tick_every = int(scalar(@x_labels)/10);

	for(my $i = 0; $i < @x_labels; $i++)
	{
		push @series, "[".$i.",".$data[$i]."]";
		push @labels, "{v:".$i.", label:".quote_javascript($x_labels[$i])."}" if ($i % $tick_every) == 0;
	}

	my $data_array = join(',', @series);
	my $labels_array = join(',', @labels);

	my $html = <<EOH;
<script type="text/javascript" src="$base_url/mochikit/MochiKit.js"></script>
<script type="text/javascript" src="$base_url/plotkit/Base.js"></script>
<script type="text/javascript" src="$base_url/plotkit/Layout.js"></script>
<script type="text/javascript" src="$base_url/plotkit/Canvas.js"></script>
<script type="text/javascript" src="$base_url/plotkit/SweetCanvas.js"></script>
<div class='bar_graph'>
<div><canvas id='$canvas_id' width='$width' height='290'></canvas></div><br />
</div>
<script type="text/javascript">
var options = {
	'yTickPrecision': 0,
	'xTicks': [$labels_array],
	'xNumberOfTicks': 10,
	'shouldStroke': true,
//	'strokeWidth': 0.1,
	'axisLabelColor': Color.blackColor(),
	'shouldFill': false
};
var layout = new PlotKit.Layout('line',options);
	layout.addDataset($label,[$data_array]);
	layout.evaluate();
var canvas = MochiKit.DOM.getElement('$canvas_id');
var plotter = new PlotKit.CanvasRenderer(canvas,layout,options);

plotter.render();
</script>
EOH

	return $html;
}

1;
