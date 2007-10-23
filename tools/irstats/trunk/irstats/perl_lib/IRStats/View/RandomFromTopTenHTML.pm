package IRStats::View::RandomFromTopTenHTML;

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
        $self->{'visualisation'} = IRStats::Visualisation::HTML->new(
	{
		html => ''
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
##DO NOT CACHE

	my $rows = [];

	my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'}
			);

	while ( my @row = $query->fetchrow_array() )
	{
		push @{$rows}, $row[0];
	}
	$query->finish(); 

	$self->{'visualisation'}->set('html', $self->{'database'}->get_citation($rows->[int (rand(scalar @{$rows} ))], 'eprint') );

}


1;
