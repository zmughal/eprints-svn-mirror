package IRStats::View::SearchEngineGraph;

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
		columns => [ 'search_engine', 'COUNT' ],
		group => 'search_engine',
		order => {column => 'COUNT', direction => 'DESC'}
	};
        $self->{'visualisation'} = IRStats::Visualisation::Graph::Pie->new(
	{
                        filename => $self->{'params'}->get('id') . ".png",
                        title => "Search Engines",
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

        my $threshold = 95; # cut-off point for 'others'

        my @labels;
        my @data;

	my $data_series = [];

        my $query = $self->{'database'}->get_stats(
                        $self->{'params'},
                        $self->{'sql_params'},
                        );


        while ( my @row = $query->fetchrow_array() )
        {
                push @labels, $row[0];
                push @data, $row[1];
        }
        $query->finish();

	@labels = tidy_labels( @labels );

        my $total = 0;
        foreach (@data){
                $total += $_;
        }

	if ($total == 0)
	{
		push @{$data_series}, {
			citation => 'None',
			data => 100
		};
	}
	else
	{
		my $others = 0;
		my $flag = 0;  #indicates when we have crossed the threshold
			for (my $i = 0; $i <= $#data; $i ++)
			{
				if ($flag == 0) {
					if (($data[$i] * $threshold) < $total)
					{
						$flag = 1;
					}
					push @{$data_series}, {
						citation => $labels[$i],
						 data => $data[$i]
					};
				}
				else
				{
					$others += $data[$i];
				}
			}
		push @{$data_series}, {
			citation => 'Others',
				 data => $others
		};
	}

	$self->{'visualisation'}->set('data_series',$data_series);

##write to cache
	$cache->write($self->{'visualisation'});
}

sub tidy_labels
{
	my( @labels ) = @_;

	for(@labels)
	{
		$_ = "Not-applicable" unless defined $_;
		s/<[^>]+>//g;
	}

	@labels;
}

1;
