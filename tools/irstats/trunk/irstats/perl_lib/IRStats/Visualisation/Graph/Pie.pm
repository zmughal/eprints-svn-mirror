package IRStats::Visualisation::Graph::Pie;

use strict;
use warnings;

use perlchartdir;
use IRStats::Visualisation::Graph;


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

1;

