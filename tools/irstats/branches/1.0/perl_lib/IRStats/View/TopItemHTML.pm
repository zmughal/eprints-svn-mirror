package IRStats::View::TopItemHTML;

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
		limit => 1
	};
        $self->{'visualisation'} = IRStats::Visualisation::HTML->new(
	{
		html => '<span>No Data</span>'
	}
        );
	$self->{max_tries} = 20;
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

#if we don't find one the first time, move backwards and try again.
	for (my $i=0; $i < $self->{max_tries}; $i++)
	{
		my $query = $self->{'database'}->get_stats(
				$self->{'params'},
				$self->{'sql_params'}
				);

		my @row;
		if (@row = $query->fetchrow_array())
		{
			$self->{'visualisation'}->set('html',$self->{'database'}->get_citation($row[0], 'eprint'));
			last;
		}
		$query->finish();
		my $new_start_date = $self->{params}->get('start_date')->clone();
		for (-1 .. $i) #subtract more days each time.
		{
			$new_start_date->decrement('day');
		}
		$self->{params}->mask({start_date => $new_start_date});
	}

	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
