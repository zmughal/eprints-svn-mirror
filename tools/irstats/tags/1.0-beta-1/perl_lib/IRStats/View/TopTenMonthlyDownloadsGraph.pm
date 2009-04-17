package IRStats::View::TopTenMonthlyDownloadsGraph;

use strict;
use warnings;

use IRStats::DatabaseInterface;
use IRStats::Cache;
use IRStats::Visualisation::Graph::Line;
use IRStats::View;
use Data::Dumper;


our @ISA = qw/ IRStats::View /;

sub initialise
{
	my ($self) = @_;
	$self->{'sql_params'} = {
		columns => [ 'eprint', 'COUNT' ],
		group => 'eprint',
		order => {column => 'COUNT', direction => 'DESC'},
		limit => 10
	};

	$self->{'visualisation'} = IRStats::Visualisation::Graph::Line->new(
	{
			filename => $self->{'params'}->get('id') . ".png",
			title => "Monthly Download Counts of Top Papers",
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
	my $data_series = [];
	
	my $eprints_counts_periods = {}; 
	my $top_ten = [];

	my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'},
		);
	while (my @row = $query->fetchrow_array())
	{
		push @{$top_ten}, $row[0];
	}


	my $labels_done_flag = 0;
	foreach my $eprint_id (@{$top_ten})
	{
		$self->{params}->mask({eprints => "eprint_$eprint_id"});

		my $start_period = IRStats::Date->new(
				{
				year => $self->{'params'}->{'start_date'}->part('year'),
				month => $self->{'params'}->{'start_date'}->part('month'), 
				day => 1
				}
				);
		while ( $start_period->less_than( $self->{'params'}->{'end_date'} ) )
		{
			my $end_period = $start_period->clone();
			$end_period->increment('month');
			$end_period->decrement('day');
			$self->{'params'}->mask({start_date => $start_period, end_date => $end_period});

			$query = $self->{'database'}->get_stats(
					$self->{'params'},
					$self->{'sql_params'},
					);
			$self->{'params'}->unmask();

			my $row = $query->fetchrow_arrayref();
			push @{$eprints_counts_periods->{$eprint_id}}, 0;
			$eprints_counts_periods->{$eprint_id}->[$#{$eprints_counts_periods->{$eprint_id}}] += $row->[1]; #insert onto end of array

			push @{$x_labels}, $start_period->month_name() if (not $labels_done_flag);;
			$query->finish();

			$start_period->increment('month');
		}
		$labels_done_flag = 1;
		$self->{params}->unmask()

	}

	foreach my $eprint_id (@{$top_ten})
	{
		push @{$data_series}, {
			citation => $self->{'database'}->get_citation($eprint_id, 'eprint', 'short'),
			data => $eprints_counts_periods->{$eprint_id}
		};
        }

	$self->{'visualisation'}->set('x_labels', $x_labels);
	$self->{'visualisation'}->set('data_series', $data_series);


	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
