package IRStats::View::TopTenNonSearchReferrers;

use strict;
use warnings;

use IRStats::DatabaseInterface;
use IRStats::Cache;
use IRStats::Visualisation::Table::HTML;
use IRStats::View;
use Data::Dumper;
use URI;


our @ISA = qw/ IRStats::View /;

sub initialise
{
        my ($self) = @_;
	$self->{'sql_params'} = {
		columns => [ 'referring_entity_id', 'COUNT', 'referrer_scope' ],
		group => "referring_entity_id", 
		where => [ {column => 'referrer_scope', operator => '!=', value => "Search" },
			{column => 'referrer_scope', operator => '!=', value => "None" }],
		order => {column => "COUNT", direction =>"DESC"},
		limit => 10
		};
        $self->{'visualisation'} = IRStats::Visualisation::Table::HTML->new(
	{
			columns => [ 'Referrer', 'Count'],
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
		if( !$row[0] )
		{
		}
		elsif( $row[0] =~ /^https?:/ )
		{
			push @{$rows}, ['<a href="'.$row[0].'">'.abbr_url($row[0]).'</a>' , $row[1]];
		}
		else
		{
			push @{$rows}, [@row[0..1]];
		}
	}
	$query->finish(); 

	$self->{'visualisation'}->set('rows',$rows);

	##write to cache
	$cache->write($self->{'visualisation'});
}


sub abbr_url
{
	my( $url ) = @_;
	$url = URI->new($url, 'http');
	my $path_query = $url->path_query;
	$path_query =~ s/^(.{10}).+(.{10})$/$1...$2/;
	$url->path_query($path_query);
	return "$url";
}

1;
