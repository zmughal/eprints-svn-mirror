package IRStats::View::TopTenAcademies;

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
		columns => [ 'requester_host', 'COUNT' ],
		group => "requester_host",
		order => {column => "COUNT", direction => "DESC"},
	};
        $self->{'visualisation'} = IRStats::Visualisation::Table::HTML->new(
	{
			columns => [ 'Domain Tail', 'Downloads'],
                        rows => [],
	}
        );
	$self->{max} = 10;
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

	my $rows = [];

	my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'}
			);
	my $domain_tails = {};

	while ( my @row = $query->fetchrow_array() )
	{
		my $hostname = lc($row[0]);
		my $download_count = $row[1];
		my $host_tail = 'none';
		if ($hostname =~ /([^.]*\.edu)$/){
			$host_tail = $1;
		}
		elsif ($hostname =~ /([^.]*\.edu.[a-z][a-z])$/){
			$host_tail = $1;
		}
		elsif ($hostname =~ /([^.]*\.ac.[a-z][a-z])$/){
			$host_tail = $1;
		}
		if ($host_tail ne 'none')
		{
			$domain_tails->{$host_tail} += $download_count;
		}
	}
	$query->finish(); 

	my $i = 0;
	foreach my $domain_tail (reverse sort { $domain_tails->{$a} <=> $domain_tails->{$b} } keys %{$domain_tails})	
	{
		push @{$rows}, [$domain_tail, $domain_tails->{$domain_tail}];
		$i ++;
		last if ($i > $self->{max})
	}

	$self->{'visualisation'}->set('rows',$rows);

	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
