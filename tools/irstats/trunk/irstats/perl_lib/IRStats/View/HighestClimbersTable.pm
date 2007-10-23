package IRStats::View::HighestClimbersTable;

use strict;
use warnings;

use IRStats::DatabaseInterface;
use IRStats::Cache;
use IRStats::Visualisation::Table::HTML;
use IRStats::View;
use Data::Dumper;


our @ISA = qw/ IRStats::View /;

sub initialise
{
        my ($self) = @_;
	$self->{'sql_params'} = {
		columns => [ 'eprint', 'COUNT' ],
		group => "eprint",
		order => {column => "COUNT", direction => "DESC"},
	};
        $self->{'visualisation'} = IRStats::Visualisation::Table::HTML->new(
	{
			columns => [ 'Eprint', 'ERR', 'ERR', 'Difference'], #fill in dates in column headings later
                        rows => [],
	}
        );
	$self->{max_rows} = 10;
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

	my $periods = {current => {}, previous => {}};
	my $rows = [];

	my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'}
			);

	while ( my @row = $query->fetchrow_array() )
	{
		$periods->{current}->{$row[0]} = $row[1];
	}
	$query->finish(); 
	$self->{visualisation}->{columns}->[2] = $self->{params}->{start_date}->render('short') . ' to ' . $self->{params}->{end_date}->render('short');

	my $date_difference = $self->{params}->{start_date}->difference( $self->{params}->{end_date} ); 
	my $prev_end =  $self->{params}->{start_date}->clone();
	$prev_end->decrement('day');
	my $prev_start = $prev_end->clone();
	foreach (1..$date_difference)
	{
		$prev_start->decrement('day');
	}

	$self->{params}->mask({start_date => $prev_start, end_date => $prev_end});
	$query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'}
			);

	while ( my @row = $query->fetchrow_array() )
	{
		$periods->{previous}->{$row[0]} = $row[1];
	}
	$query->finish();
	$self->{visualisation}->{columns}->[1] = $self->{params}->{start_date}->render('short') . ' to ' . $self->{params}->{end_date}->render('short');
	$self->{params}->unmask();

	my $differences = {};
	foreach my $eprintID (keys %{$periods->{current}})
	{
		my $last_period_count = 0;
		if (defined $periods->{previous}->{$eprintID})
		{
			$last_period_count = $periods->{previous}->{$eprintID};
		}
		$differences->{$eprintID} = $periods->{current}->{$eprintID} - $last_period_count;
	}


	my $i = 0;
	foreach my $eprintID (reverse sort { $differences->{$a} <=> $differences->{$b} } keys %{$differences})
	{
		last if ($differences->{$eprintID} < 0);
		push @{$rows}, [$self->{'database'}->get_citation($eprintID, 'eprint', 'short'), 
				$periods->{previous}->{$eprintID} ? $periods->{previous}->{$eprintID} : 0,
				$periods->{current}->{$eprintID},
				$differences->{$eprintID}
			];
		$i++;
		last if ($i > $self->{max_rows});
	}

	$self->{'visualisation'}->set('rows',$rows);
	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
