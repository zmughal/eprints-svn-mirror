package IRStats::View::RawDataTableHTML;

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
		columns => [ 'accessid','datestamp','eprint','requester_organisation','requester_host','requester_country','referrer_scope','search_engine','search_terms','referring_entity_id' ],
		order => {column => 'accessid', direction => 'ASC'},
	};


        $self->{'visualisation'} = IRStats::Visualisation::Table::HTML->new(
	{
			columns => [ "Access ID", "Datestamp", "Eprint ID","Requester Organisation", "Requester Host","Requester Country","Referrer Scope","Search Engine","Search Terms", "Referring URL"],
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
