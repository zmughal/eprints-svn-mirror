package IRStats::View::AllMonthlyDownloadsGraph;

use strict;
use warnings;

use IRStats::DatabaseInterface;
use IRStats::Visualisation::Graph::Bar;
use IRStats::View;
use IRStats::Periods;
use Data::Dumper;

our @ISA = qw(IRStats::View);

sub initialise
{
        my ($self) = @_;
        $self->{'sql_params'} ={
		columns => [ 'COUNT' ]
	};
        $self->{'visualisation'} = IRStats::Visualisation::Graph::Bar->new(
	{
                        filename => $self->{'params'}->get('id') . ".png",
                        title => "Total Downloads",
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

	my $x_labels = [];
	my $data_series = [{data => []}];	

	my $periods = IRStats::Periods->new($self->{'params'}->{'start_date'},$self->{'params'}->{'end_date'});
	my $downloaded_flag = 0;
	foreach my $period ( @{$periods->calandar_months()} )
	{
		$self->{'params'}->mask($period);
	     
		my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'},
		);
		$self->{'params'}->unmask();


		my $row = $query->fetchrow_arrayref();
		if ($row->[0])
		{
			$downloaded_flag = 1;
		}
		if ($downloaded_flag)
		{

			push @{$data_series->[0]->{data}}, 0;
			push @{$x_labels}, $period->{start_date}->month_name();

			if ($row->[0])
			{
				$data_series->[0]->{data}->[$#{$data_series->[0]->{data}}] = $row->[0];
			}
		}

		$query->finish();
	}
	$x_labels->[0] .= ' ' . $self->{'params'}->{'start_date'}->part('year','short');

	$self->{'visualisation'}->set('x_labels',$x_labels);
	$self->{'visualisation'}->set('data_series',$data_series);
	
##write to cache
	$cache->write($self->{'visualisation'});
}

1;
