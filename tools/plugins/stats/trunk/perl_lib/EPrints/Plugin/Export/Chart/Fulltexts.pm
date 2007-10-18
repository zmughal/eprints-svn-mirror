package EPrints::Plugin::Export::Chart::Fulltexts;

use CGI::Carp qw(fatalsToBrowser);

use Unicode::String qw( utf8 );
use Chart::Mountain;

use EPrints::Plugin::Export::Chart;

@ISA = ( "EPrints::Plugin::Export::Chart" );

our @full_text_options = qw(public restricted none);

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Chart: Fulltexts over Time";
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

	my $chart = Chart::Mountain->new( 400, 300 );

	my @legend;
	foreach my $option (@full_text_options)
	{
		my $phrase = $session->html_phrase( "eprint_fieldopt_full_text_status_$option" );
		push @legend, EPrints::XML::to_string( $phrase );
	}

	$chart->set(
		legend => "bottom",
		legend_labels => \@legend,
	);

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

	my %data;

	foreach my $full_text_status (@full_text_options)
	{
		my $sth = $database->prepare( "SELECT CONCAT(`${date_column}_year`,`${date_column}_month`),COUNT(*) FROM `eprint` INNER JOIN `$cache_table` USING(`eprintid`) WHERE `full_text_status`='$full_text_status' GROUP BY `${date_column}_year`,`${date_column}_month`" );
		$database->execute( $sth, $sth->{Statement} );

		my $sum = 0;

		while(my( $yearmonth, $count ) = $sth->fetchrow_array)
		{
			$data{$yearmonth}->{$full_text_status} = $count;
		}
	}

	my %sum = map { $_ => 0 } @full_text_options;

	foreach my $yearmonth (sort keys %data)
	{
		push @{$DATA[0]}, $yearmonth;
		for(1..@full_text_options)
		{
			my $option = $full_text_options[$_ - 1];
			$sum{$option} += $data{$yearmonth}->{$option}
				if exists $data{$yearmonth}->{$option};
			push @{$DATA[$_]}, $sum{$option};
		}
	}

	return $plugin->fill_date_gaps( @DATA );
}

1;
