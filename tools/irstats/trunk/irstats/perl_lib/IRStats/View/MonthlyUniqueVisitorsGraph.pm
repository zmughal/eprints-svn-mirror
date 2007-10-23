package IRStats::View::MonthlyUniqueVisitorsGraph;

use strict;
use warnings;

use IRStats::DatabaseInterface;
use IRStats::Visualisation::Graph::Bar;
use IRStats::View;
use Data::Dumper;

our @ISA = qw(IRStats::View);

sub initialise
{
        my ($self) = @_;
	$self->{sql_params} = {
		columns => [ 'requester_host' ],
		group => 'requester_host'
		};
        $self->{'visualisation'} = IRStats::Visualisation::Graph::Bar->new(
	{
                        filename => $self->{'params'}->get('id') . ".png",
                        title => "Unique Visitors",
                        x_title => 'Month',
                        y_title => "Number of Downloads",
                        data_series => [],
                        x_labels => [],
			params => $self->{params}
	}
        );
}

sub new
{
        my( $class, $params, $database ) = @_;
        my $self = $class->SUPER::new($params, $database);;
        $self->initialise();
        return $self;
}

sub populate
{
	my ($self) = @_;

##Check Cache
	my $cache = IRStats::Cache->new($self->{'params'});
	if ($cache->exists)
	{
		$self->{'visualisation'} = $cache->read();
		return;
	}

	my $start_period = IRStats::Date->new(
	{
		year => $self->{'params'}->{'start_date'}->part('year'),
		month => $self->{'params'}->{'start_date'}->part('month'), 
		day => 1
	}
	);

	my $x_labels = [];
	my $data_series = [  {citation => 'Visitors', data => [] }  ];	
	
	while ( $start_period->less_than( $self->{'params'}->{'end_date'} ) )
	{
		my $end_period = $start_period->clone();
		$end_period->increment('month');
		$end_period->decrement('day');
		$self->{'params'}->mask({start_date => $start_period, end_date => $end_period});
	     
		my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'}
		);
		$self->{'params'}->unmask();

		push @{$data_series->[0]->{'data'}}, $query->rows();
		push @{$x_labels}, $start_period->month_name();

		$query->finish();
		$start_period->increment('month');
	}
	$self->{'visualisation'}->set('x_labels',$x_labels);
	$self->{'visualisation'}->set('data_series',$data_series);
	
##write to cache
	$cache->write($self->{'visualisation'});
}

1;
