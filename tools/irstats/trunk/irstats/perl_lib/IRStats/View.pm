package IRStats::View;

use strict;
use warnings;

sub new
{
	my ($class, $params, $database) = @_;

	my $self = bless {
		database => $database,
		params => $params
	}, $class;
}

sub get
{
    my ($self, $param) = @_;
    return $self->{$param} if (defined $self->{$param});
    return "ERR";
}


sub render
{
	my ($self) = @_;
	$self->populate();
	$self->{'visualisation'}->render();
}


1;
