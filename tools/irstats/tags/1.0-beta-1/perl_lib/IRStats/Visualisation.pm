package IRStats::Visualisation;

use strict;
use warnings;
use Data::Dumper;
use Carp;

sub new
{
	my ($class, $data) = @_;
	$data = {} unless defined $data;
	return bless $data, $class;

}

sub get
{
	my ($self, $param) = @_;
	return $self->{$param} if (defined $self->{$param});
    return "ERR";
}

sub set
{
	my ($self, $param, $value) = @_;

	$self->{$param} = $value;
}

1;

