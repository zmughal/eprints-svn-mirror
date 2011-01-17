######################################################################
#
# EPrints::Search::Condition::False
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

B<EPrints::Search::Condition::False> - "False" search condition

=head1 DESCRIPTION

Matches no items.

=cut

package EPrints::Search::Condition::False;

use EPrints::Search::Condition;

@ISA = qw( EPrints::Search::Condition );

use strict;

sub new
{
	my( $class ) = @_;

	return bless { op=>"FALSE" }, $class;
}

sub logic
{
	return "1=0";
}

1;