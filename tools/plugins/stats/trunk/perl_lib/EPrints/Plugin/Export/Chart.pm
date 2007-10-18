package EPrints::Plugin::Export::Chart;

use CGI::Carp qw(fatalsToBrowser);

use Unicode::String qw( utf8 );
use Chart::Lines;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Chart: Records over Time";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = "png";
	$self->{mimetype} = "image/png";

	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $list = $opts{list};

	my $session = $plugin->{session};
	my $database = $session->{database};
	my $dataset = $list->{dataset};

	my $chart = Chart::Lines->new( 400, 300 );

	$chart->set( legend => 'none' );

	my @DATA = $plugin->get_data( $list );

	if( defined $opts{fh} )
	{
		$chart->png( $opts{fh}, \@DATA );
	}
	else
	{
		print $chart->png( \*STDOUT, \@DATA );
	}
}

sub get_data
{
	my( $plugin, $list ) = @_;

	my $session = $plugin->{session};
	my $database = $session->{database};
	my $dataset = $list->{dataset};

	my @DATA = ([],[]);
	
	# Write the cache table by hand, because it doesn't have keep_cache on
	my $cache_id = $database->cache( 
		$list->{encoded}, 
		$dataset,
		"LIST",	
		undef,
		$list->get_ids );

	my $cache_table = $database->cache_table( $cache_id );

	my $date_column = 'status_changed';

	my $sth = $database->prepare( "SELECT CONCAT(`${date_column}_year`,`${date_column}_month`),COUNT(*) FROM `eprint` INNER JOIN `$cache_table` USING(`eprintid`) GROUP BY `${date_column}_year`,`${date_column}_month`" );
	$database->execute( $sth, $sth->{Statement} );

	my $sum = 0;

	while(my( $yearmonth, $count ) = $sth->fetchrow_array)
	{
		push @{$DATA[0]}, $yearmonth;
		push @{$DATA[1]}, $sum += $count;
	}

	return $plugin->fill_date_gaps( @DATA );
}

sub fill_date_gaps
{
	my( $plugin, @DATA ) = @_;

	my $ym = $DATA[0]->[0];
	$ym--;
	if( $ym % 100 == 0 )
	{
		$ym -= 100;
		$ym += 1;
	}
	unshift @{$DATA[0]}, $ym;
	for(1..$#DATA)
	{
		unshift @{$DATA[$_]}, defined $DATA[$_]->[0] ? 0 : undef;
	}

	for(my $i = 0, my $ym = $DATA[0]->[0]; $i < $#{$DATA[0]}; $i++)
	{
		while( $DATA[0]->[$i+1] < $ym )
		{
			$ym++;
			if( $ym % 100 > 12 )
			{
				$ym += 100; # Add a year
				$ym -= 12; # Take off 12 months
			}
			splice(@{$DATA[0]}, $i+1, 0, $ym);
			for(1..$#DATA)
			{
				splice(@{$DATA[$_]}, $i+1, 0, $DATA[$_]->[$i]);
			}
		}
	}

	for(@{$DATA[0]})
	{
		s/(..)$/-$1/;
	}

	return @DATA;
}

1;
