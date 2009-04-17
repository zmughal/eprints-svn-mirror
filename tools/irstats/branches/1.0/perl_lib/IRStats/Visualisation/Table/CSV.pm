package IRStats::Visualisation::Table::CSV;

use strict;
use warnings;

our @ISA = qw/ IRStats::Visualisation::Table /;

sub new
{
	my ($class, $data) = @_;
	my $self = $class->SUPER::new($data);
	$self->{'normalised'} = 0;

	return $self;
}

sub render
{
	my ($self) = @_;
	$self->normalise();
	my $csv = join (',',@{$self->{'columns'}});
	$csv .= "\n";
	foreach (@{$self->{'rows'}})
	{
		$csv .= join (',', @{$_});
		$csv .= "\n";
	}
	return $csv;
}

sub normalise_cell
{
	my ($data) = @_;
	if ($data =~ /[\n" ,]/)
	{
		$data =~ s/"/""/g; #escape quotes
		$data = '"' . $data . '"'; #delimit data;
	}
	return $data;
}

sub normalise
{
	my ($self) = @_;
	return if ($self->{'normalised'});  #check, just in case
	$self->{'normalised'} = 1;

	foreach (@{$self->{'headings'}})
	{
		$_ = normalise_cell($_);
	}

	foreach (@{$self->{'rows'}})
	{
		foreach (@{$_})
		{
			$_ = normalise_cell($_);
		}
	}
}


1;
