######################################################################
#
# EPrints::Search::Condition::And
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::Search::Condition::And> - Intersect results of several sub-conditions

=head1 DESCRIPTION

Intersect the results of sub-conditions.

=cut

package EPrints::Search::Condition::And;

use EPrints::Search::Condition::Control;

BEGIN
{
	our @ISA = qw( EPrints::Search::Condition::Control );
}

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = bless { op=>"AND", sub_ops=>\@params }, $class;

	$self->{prefix} = $self->{op}.($self+0)."_";

	return $self;
}

sub optimise_specific
{
	my( $self ) = @_;

	my $tree = $self;

	my $keep_ops = [];
	foreach my $sub_op ( @{$tree->{sub_ops}} )
	{
		# if an OR contains TRUE or an
		# AND contains FALSE then we can
		# cancel it all out.
		return $sub_op if( $sub_op->{op} eq "FALSE" );

		# just filter these out
		next if( $sub_op->{op} eq "TRUE" );
		
		push @{$keep_ops}, $sub_op;
	}
	$tree->{sub_ops} = $keep_ops;

	return $tree;
}

sub item_matches
{
	my( $self, $item ) = @_;

	foreach my $sub_op ( $self->ordered_ops )
	{
		my $r = $sub_op->item_matches( $item );
		return( 0 ) if( $r == 0 );
	}

	return( 1 );
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my @logic;
	foreach my $sub_op ( $self->ordered_ops )
	{
		push @logic, $sub_op->get_query_logic( %opts );
	}

	return "(" . join(") AND (", @logic) . ")";
}

1;
