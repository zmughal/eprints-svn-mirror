package EPrints::TempDir;

use strict;
use warnings;

use File::Temp;
use File::Path qw/ rmtree /;

our @ISA = qw( File::Temp );

=pod

=head1 NAME

EPrints::TempDir - Create temporary directories that can automatically be removed

=head1 SYNOPSIS

	use EPrints::TempDir;

	my $dir = EPrints::TempDir->new(
		TEMPLATE => 'tempXXXXX',
		DIR => 'mydir',
		UNLINK => 1);

=head1 DESCRIPTION

This module is basically a clone of File::Temp, but provides an object-interface to directory creation.

=cut

use overload '""' => sub { return shift->{'dir'} };

sub new {
	my $class = shift;
	my $templ = 'eprintsXXXXX';
	if( 1 == @_ % 2 ) {
		$templ = shift;
	}
	my %args = (TEMPLATE=>$templ,@_);
	$args{dir} = SUPER::tempdir(%args);
	return bless \%args, ref($class) || $class;
}

sub DESTROY
{
	my $self = shift;
	if( $self->{UNLINK} ) {
		rmtree($self->{dir},0,0);
	}
}

1;
