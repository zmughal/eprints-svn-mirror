package IRStats::View::DownloadCountHTML;

use strict;
use warnings;

use IRStats::DatabaseInterface;
use IRStats::Cache;
use IRStats::Visualisation::HTML;
use IRStats::View;
use Data::Dumper;

our @ISA = qw/ IRStats::View /;

sub initialise
{
        my ($self) = @_;
	$self->{'sql_params'} = {
		columns =>  [ 'COUNT' ],
	};
        $self->{'visualisation'} = IRStats::Visualisation::HTML->new();
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

        my $html;

	my $data_series = [];
	my $query = $self->{'database'}->get_stats(
			$self->{'params'},
			$self->{'sql_params'}
			);

        my @row = $query->fetchrow_array();
	$html = '<span class="irstats_view_fulltextcounthtml">' . ($row[0] ? $row[0] : '0') . "</span>";
        
	$query->finish();

	$self->{'visualisation'}->set('html',$html);

##write to cache
	$cache->write($self->{'visualisation'});
}

1;
