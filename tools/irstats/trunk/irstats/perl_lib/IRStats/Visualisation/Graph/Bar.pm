package IRStats::Visualisation::Graph::Bar;

use strict;
use warnings;

use IRStats::Visualisation::Graph::GraphLegend;
use IRStats::Visualisation::Graph;
use perlchartdir;
use Data::Dumper;

our @ISA = qw(IRStats::Visualisation::Graph);

sub new
{
	my ($class, $data) = @_;
	my $self = $class->SUPER::new($data);
	return $self;
}

sub render
{
	my ($self) = @_;

	my $c = new XYChart(500, 300, 0xeeeeff, 0x000000, 1);
	$c->setRoundedFrame();
	$c->setPlotArea(55, 25, 420, 220, 0xffffff, -1, -1, 0xcccccc, 0xcccccc);
	#$c->addTitle($self->{'title'}, "timesbi.ttf", 15)->setBackground(0xccccff, 0x000000, perlchartdir::glassEffect());

	$c->yAxis()->setTitle($self->{'y_title'});
	$c->xAxis()->setTitle($self->{'x_title'});
	$c->xAxis()->setLabels($self->{'x_labels'});
	$c->yAxis()->setMinTickInc(1); # make y axis always show whole numbers

	{
		use integer;
		$c->xAxis()->setLabelStep((($#{$self->{'x_labels'}}+1)/13)+1);
	}
	my $slayer = $c->addSplineLayer();
	my $layer = $c->addBarLayer2($perlchartdir::Side, 3);
	foreach my $i (0 .. $#{$self->{'data_series'}})
	{
		$layer->addDataSet($self->{'data_series'}->[$i]->{'data'}, $self->{'colours'}->[$i]);
		if( $self->{'trend'} )
		{
			my $src = $self->{'data_series'}->[$i]->{'data'};
			my $mean = [];
			my $len = scalar @$src;
			my $range = 7;
			for( my $i = 0; $i < $len; ++$i )
			{
				my $c = 0;
				my $t = 0;
				for(my $j = $i-$range; $j <= $i+$range; ++$j)
				{
					next if $j < 0;
					next if $j > $len-1;
					++$c;
					$t += $src->[$j];
				}
				push @$mean, $t / $c;
			}
			$slayer->addDataSet( $mean, 0x00c0c0, "Averaged Trend Line" );
		}
	}
	$layer->setLineWidth(2);
	$slayer->setLineWidth(2);

	$c->makeChart($self->{'path'} . $self->{'filename'}) or die "Error creating graph at ".$self->{path}.$self->{filename}.": $!";

	my $r = "<div id=\"bar_graph\">
		<table><tr>
		<td>
		<img class=\"chart\" src = \"$self->{'url_relative'}\">
		</td>
		";

	if ($self->{data_series}->[0]->{citation})
	{
	my $legend = IRStats::Visualisation::Graph::GraphLegend->new($self->{'data_series'}, $self->{'colours'});
		$r .= "<td>" .
		$legend->render() .
		"</td>";
	}
	$r .= "</tr></table>
		</div>";
	return $r;
}

1;

