package IRStats::View::TopCountriesTable;

use strict;
use warnings;

use IRStats::DatabaseInterface;
use IRStats::Cache;
use IRStats::Visualisation::Table::HTML_Columned;
use IRStats::View;
use Data::Dumper;


our @ISA = qw/ IRStats::View /;

sub initialise
{
        my ($self) = @_;
	$self->{'sql_params'} = {
		columns => [ 'requester_country', 'COUNT' ],
		group => "requester_country",
		order => {column => "COUNT", direction => "DESC"},
		limit => 60
	};
	$self->{'visualisation'} = IRStats::Visualisation::Table::HTML_Columned->new(
	{
		title => "Top Countries",
		columns => [ 'Country', 'Downloads'],
		rows => [],
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

	my $rows = [];

	my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'}
			);

	while ( my @row = $query->fetchrow_array() )
	{
		push @{$rows}, \@row ;
	}
	$query->finish(); 

	$self->{'visualisation'}->set('rows',$rows);

	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
