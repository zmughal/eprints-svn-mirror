package IRStats::View::TopTenTable;

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
		limit => 10
	};
        $self->{'visualisation'} = IRStats::Visualisation::Table::HTML->new(
	{
			columns => [ 'Eprint', 'Fulltext Downloads'],
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
		my $citation = $self->{'database'}->get_citation($row[0], 'eprint');
		push @{$rows}, [$citation, $row[1]] ;
	}
	$query->finish(); 

	$self->{'visualisation'}->set('rows',$rows);

	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
