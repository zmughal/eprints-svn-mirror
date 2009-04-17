package IRStats::View::MonthlyDownloadsByGroupGraph;

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
		group => 'eprint'
	};

	$self->{'visualisation'} = IRStats::Visualisation::Graph::Line->new(
	{
			filename => $self->{'params'}->get('id') . ".png",
			title => "Fulltext Downloads By Group",
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
	my $data_series = [];
	
	my $eprint_counts_periods = []; 
	my $eprint_totals = {};
	while ( $start_period->less_than( $self->{'params'}->{'end_date'} ) )
	{
		my $end_period = $start_period->clone();
		$end_period->increment('month');
		$end_period->decrement('day');
		$self->{'params'}->mask({start_date => $start_period, end_date => $end_period});
	     
		my $query = $self->{'database'}->get_stats(
				$self->{'params'},
				$self->{'sql_params'},
				);
		$self->{'params'}->unmask();

		my $eprint_counts = {};
		while (my $row = $query->fetchrow_arrayref() )
		{
			$eprint_counts->{$row->[0]} += $row->[1];
			$eprint_totals->{$row->[0]} += $row->[1];
		}

		push @{$eprint_counts_periods}, $eprint_counts;
		push @{$x_labels}, $start_period->month_name();
		$query->finish();

		$start_period->increment('month');
	}

	my $group_counts_periods = {};
	my $group_totals;
	foreach my $eprint_id ( keys %{$eprint_totals} )
	{
		my $groups = $self->{'database'}->get_membership($eprint_id, 'group');
		foreach my $group (@{$groups})
		{
			foreach my $i (0 .. $#{$eprint_counts_periods})
			{
				$group_counts_periods->{$group}->[$i] += $eprint_counts_periods->[$i]->{$eprint_id};
				$group_totals->{$group} += $eprint_counts_periods->[$i]->{$eprint_id};
			}
		}
	}

	foreach my $group (reverse sort { $group_totals->{$a} <=> $group_totals->{$b} } keys %{$group_totals})
	{
		push @{$data_series}, {
			citation => $self->{'database'}->get_citation($group, 'group'),
			data => $group_counts_periods->{$group} 
		};
        }
	$self->{'visualisation'}->set('x_labels', $x_labels);
	$self->{'visualisation'}->set('data_series', $data_series);

	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
