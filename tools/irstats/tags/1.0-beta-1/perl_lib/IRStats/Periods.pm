package IRStats::Periods;

use strict;
use warnings;
use IRStats::Date;

sub new
{
	my ($class, $start_date, $end_date) = @_;
	return bless {start_date => $start_date, end_date => $end_date}, $class;
}

sub calandar_months
{
	my ($self) = @_;
	my $date_ranges = [];
	my $start_period = $self->{'start_date'}->clone();
	my $end_period = $self->{'start_date'}->clone();
	$start_period->set('day','1');
	$end_period->set('day', 31);
	$end_period->validate(); #sets to last day of the month.

	while ( $start_period->less_than( $self->{'end_date'} ) )
	{
		if ($end_period->greater_than( $self->{'end_date'} ) )
		{
			$end_period = $self->{'end_date'}->clone();
		}
		push @{$date_ranges}, { start_date => $start_period->clone(), end_date => $end_period->clone() };
		$start_period = $end_period->clone();
		$start_period->increment('day');
		$end_period = $start_period->clone();
		$end_period->increment('month');
		$end_period->decrement('day');
	}
	return $date_ranges;
}

sub months
{
	my ($self) = @_;
	my $date_ranges = [];
	my $start_day = $self->{start_date}->part('day'); #remember the day in case it gets decremented when switching months
	my $start_period = $self->{'start_date'}->clone();
	my $end_period = $self->{'start_date'}->clone();
	$end_period->increment('month');
	$end_period->decrement('day');

	while ( $start_period->less_than( $self->{'end_date'} ) )
	{
		if ($end_period->greater_than( $self->{'end_date'} ) )
		{
			$end_period = $self->{'end_date'}->clone();
		}
		push @{$date_ranges}, { start_date => $start_period->clone(), end_date => $end_period->clone() };
		$start_period->increment('month');
		$start_period->set('day', $start_day);
		$start_period->validate();
		$end_period = $start_period->clone();
		$end_period->increment('month');
		$end_period->decrement('day');
	}
	return $date_ranges;
}

sub weeks
{
	my ($self) = @_;
	my $date_ranges = [];
	my $start_period = $self->{'start_date'}->clone();
	my $end_period = $self->{'start_date'}->clone();
	$end_period->increment('week');
	$end_period->decrement('day');

	while ( $start_period->less_than( $self->{'end_date'} ) )
	{
		if ($end_period->greater_than( $self->{'end_date'} ) )
		{
			$end_period = $self->{'end_date'}->clone();
		}
		push @{$date_ranges}, { start_date => $start_period->clone(), end_date => $end_period->clone() };
		$start_period->increment('week');
		$end_period = $start_period->clone();
		$end_period->increment('week');
		$end_period->decrement('day');
	}
	return $date_ranges;
}

sub days
{
	my ($self) = @_;
	my $date_ranges = [];
	my $start_period = $self->{'start_date'}->clone();

	while ( not $start_period->greater_than( $self->{'end_date'} ) )
	{
		push @{$date_ranges}, { start_date => $start_period->clone(), end_date => $start_period->clone() };
		$start_period->increment('day');
	}
	return $date_ranges;
}

1;
