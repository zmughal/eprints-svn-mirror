package IRStats::Visualisation::Graph::Pie;

use strict;

use Chart::Pie;

use IRStats::Visualisation::Graph;

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

sub chart_render
{
	my ($self) = @_;

	my $c = Chart::Pie->new( 500, 300 );

	my $data = [];
	my $labels = [];
	foreach (@{$self->{'data_series'}})
	{
		push @{$data}, $_->{'data'};
		push @{$labels}, $_->{'citation'};
	}
	$c->png( $self->{'path'} . $self->{'filename'}, [$labels, $data] );

	return "<div class=\"pie_graph\">
		<img class=\"chart\" src = \"$self->{'url_relative'}\">
		</div>";

}

sub chartdirector_render
{
	my ($self) = @_;

	my $c = new PieChart(500, 300, 0xeeeeff, 0x000000, 1);
	$c->setPieSize(250, 150, 100);
	$c->set3D();

	my $data = [];
	my $labels = [];
	foreach (@{$self->{'data_series'}})
	{
		push @{$data}, $_->{'data'};
		push @{$labels}, $_->{'citation'};
	}
	$c->setData($data, $labels);
	$c->setLabelLayout($perlchartdir::SideLayout);
	$c->setStartAngle(90,1);
	$c->setRoundedFrame();
	#$c->addTitle($self->{'title'}, "timesbi.ttf", 15)->setBackground(0xccccff, 0x000000, perlchartdir::glassEffect());
	$c->makeChart($self->{'path'} . $self->{'filename'});

	return "<div class=\"pie_graph\">
		<img class=\"chart\" src = \"$self->{'url_relative'}\">
		</div>";

}

sub plotkit_render
{
	my ($self) = @_;

	my $base_url = $self->{params}->get('conf')->static_url;

	# Quick hack to get a unique id
	my $canvas_id = $self->{filename};
	$canvas_id =~ s/\.png$//;

	my @series = ();
	my @labels = ();
	my $i = 0;
	foreach (@{$self->{'data_series'}})
	{
		push @series,'['.$i.', '.$_->{data}.']';
		my $c = $_->{citation} || '(null)';
		push @labels, '{v:'.$i.', label:'.quote_javascript($c).'}';
		++$i;
	}

	my $series_array = join(',', @series);
	my $labels_array = join(',', @labels);

	my $html = <<EOH;
<div class='pie_graph'>
<div><canvas id='$canvas_id' height="290" width="490"></canvas></div><br />
</div>
<script type="text/javascript" src="$base_url/mochikit/MochiKit.js"></script>
<script type="text/javascript" src="$base_url/plotkit/Base.js"></script>
<script type="text/javascript" src="$base_url/plotkit/Layout.js"></script>
<script type="text/javascript" src="$base_url/plotkit/Canvas.js"></script>
<script type="text/javascript" src="$base_url/plotkit/SweetCanvas.js"></script>
<script type="text/javascript">
var options = {
	'xTicks': [$labels_array],
	'axisLabelColor': Color.blackColor(),
	'axisLabelWidth': 100,
	'axisLabelFontSize': 14,
};
var layout = new PlotKit.Layout("pie", options);
	layout.addDataset("data", [$series_array]);
	layout.evaluate();
var canvas = MochiKit.DOM.getElement('$canvas_id');
var plotter = new PlotKit.SweetCanvasRenderer(canvas, layout, options);

plotter.render();
</script>
EOH
	return $html;
}

1;

