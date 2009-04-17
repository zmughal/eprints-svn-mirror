package IRStats::View::TopTenAuthorsTable;

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
	$self->{'visualisation'} = IRStats::Visualisation::Table::HTML->new(
			{
			columns => [ "Author", "Download Count"],
			rows => [],
			}
			);
	$self->{max_authors} = 10;
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
	my $rows = [];
	
	my $eprint_totals = {};

	my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'},
			);
	while (my $row = $query->fetchrow_arrayref() )
	{
		$eprint_totals->{$row->[0]} += $row->[1];
	}
	$query->finish();


	my $author_totals;
	foreach my $eprint_id ( keys %{$eprint_totals} )
	{
		my $authors = $self->{'database'}->get_membership($eprint_id, 'creators_name');
		foreach my $author (@{$authors})
		{
			$author_totals->{$author} += ($eprint_totals->{$eprint_id} / scalar @{$authors});
		}
	}
	my $i = 0;
	foreach my $author (reverse sort { $author_totals->{$a} <=> $author_totals->{$b} } keys %{$author_totals})
	{
		push @{$rows}, [
			$self->{'database'}->get_citation($author, 'creators_name'),
			sprintf("%.0f",$author_totals->{$author})
		];
		$i ++;
		last if ($i > $self->{max_authors});
        }
	$self->{'visualisation'}->set('rows', $rows);

	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
