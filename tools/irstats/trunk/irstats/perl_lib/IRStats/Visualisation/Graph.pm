package IRStats::Visualisation::Graph;

use IRStats::Visualisation;
use List::Util 'shuffle';
use Data::Dumper;

use vars qw( @ISA $RENDER_METHOD );

@ISA = qw/ IRStats::Visualisation /;

use strict;

BEGIN
{
	$RENDER_METHOD = "plotkit_render";
	eval "use perlchartdir";
	if( !$@ )
	{
		$RENDER_METHOD = "chartdirector_render";
	}
	eval "use Chart::Base";
	if( !$@ )
	{
		$RENDER_METHOD = "chart_render";
	}
}

# A graph object expects the following in the data hash:
#
#	title -> the title of the graph
#	x_title -> the x axis title
#	y_title -> the y axis title
#	x_labels -> the labels for the x axis
#	data_series -> the data, an array a hash for each series:
#		citation -> the title of the series (plain text or html) for the legend
#		data -> an array containing the data
#	filename -> the filename (should be the params id)
#
#
#

sub new
{
	my ($class, $data) = @_;
	my $self = $class->SUPER::new($data);
	my $conf = $self->{params}->get('conf');
	$self->set('colours', $self->initialise_colours());
	$self->set('path', $conf->get_path('static_path') . '/graphs/' );
	my $repository_name = $conf->repository;
	$repository_name =~ s/\W/_/g;
	$self->{'filename'} = $repository_name . "_" . $self->{'filename'};
	$self->set('url_relative', $conf->static_url . '/graphs/' . $self->{'filename'});

	return $self;
}

sub render
{
	my( $self ) = @_;

	$self->$RENDER_METHOD();
}

sub initialise_colours
{
	my ($self) = @_;
	my $colours = [];
	my $colour_values = [0x33, 0x66, 0x99, 0xcc, 0xff];
	foreach my $red (@{$colour_values}){
		foreach my $green (@{$colour_values}){
			foreach my $blue (@{$colour_values}){
				next if ( ($blue == $green) and ($blue == $red) );
				next if (
						(($blue >= 0xcc) and ($red >= 0xcc) and ($green > 0x99)) or
						(($blue >= 0xcc) and ($green >= 0xcc) and ($red > 0x99)) or
						(($green >= 0xcc) and ($red >= 0xcc) and ($blue > 0x99))
					);
				push @{$colours}, ($red * 0x010000) + ($green * 0x000100) + ($blue);
			}
		}
	}
	my $good_colours = [0x000080,0xff00ff,0xffff00,0x00ffff,0x800080,0x80000,0x008080,0x0000ff,0x00ccff,0xccffff,0xccffcc,0xffff99,0x99ccff];
	$colours = [@{$good_colours}, shuffle(@{$colours})];
	return $colours;
}

sub colour_to_rgb
{
	my( $c ) = @_;

	return [ ($c & 0xff0000)/0x10000, ($c & 0x00ff00)/0x100, $c & 0x0000ff ];
}

sub chart_colours
{
	my( $self ) = @_;

	return map { colour_to_rgb( $_ ) } @{$self->{colours}};
}

1;
