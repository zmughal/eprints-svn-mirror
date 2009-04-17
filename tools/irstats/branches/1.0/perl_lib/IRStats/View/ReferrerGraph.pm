package IRStats::View::ReferrerGraph;

use strict;
use warnings;

use IRStats::DatabaseInterface;
use IRStats::Cache;
use IRStats::Visualisation::Graph::Pie;
use IRStats::View;
use Data::Dumper;


our @ISA = qw/ IRStats::View /;

sub initialise
{
        my ($self) = @_;
        $self->{'sql_params'} = {
		columns => [ 'referrer_scope', 'COUNT' ],
		group => 'referrer_scope'
	};

        $self->{'visualisation'} = IRStats::Visualisation::Graph::Pie->new(
	{
                        filename => $self->{'params'}->get('id') . ".png",
			title => "Referrers",
                        data_series => [],
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

	my $data_series = [];

	my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'},
			);

	while ( my @row = $query->fetchrow_array() )
	{
		push @{$data_series}, {
			citation => $row[0],
			data => $row[1]
		};
	}
	$query->finish(); 
	
	if (scalar @{$data_series} > 0) {
		$self->{'visualisation'}->set('data_series',$data_series);
	}
	else
	{
		$self->{'visualisation'}->set('data_series',[{citation => 'None', data => 100}]);
	}

	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
