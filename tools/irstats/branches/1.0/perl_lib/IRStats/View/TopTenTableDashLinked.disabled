package IRStats::View::TopTenTableDashLinked;

use strict;

use IRStats::Visualisation::Table::HTML;
use URI;

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
	$self->{'visualisation'} = IRStats::Visualisation::Table::HTML->new({
			columns => ['Eprint', 'Fulltext Downloads'],
			rows => [],
		});
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

	my $conf = $self->{database}->{session}->get_conf;

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

	my $img_url = $conf->static_url . "/view_thumbs/dash_button.png";
	my $dash_url = URI->new( $self->{database}->{session}->cgi->url );
	my %dash_query = ( page => 'dashboard' );

	while ( my @row = $query->fetchrow_array() )
	{
		my $citation = $self->{'database'}->get_citation($row[0], 'eprint');
		$dash_url->query_form(
			%dash_query,
			eprints => 'eprint_'.$row[0],
		);
		$citation .= " <a href='$dash_url' title='View detailed statistics for this eprint'><img src='$img_url' border='0' alt='Stats Dashboard' /></a>";
		push @{$rows}, [$citation, $row[1]] ;
	}
	$query->finish(); 

	$self->{'visualisation'}->set('rows',$rows);

	##write to cache
	$cache->write($self->{'visualisation'});
}


1;
