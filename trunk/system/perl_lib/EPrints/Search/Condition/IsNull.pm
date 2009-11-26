######################################################################
#
# EPrints::Search::Condition::IsNull
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

B<EPrints::Search::Condition::IsNull> - "IsNull" search condition

=head1 DESCRIPTION

Matches items where the field is null.

=cut

package EPrints::Search::Condition::IsNull;

use EPrints::Search::Condition::Comparison;

@ISA = qw( EPrints::Search::Condition::Comparison );

use strict;

sub new
{
	my( $class, @params ) = @_;

	return $class->SUPER::new( "is_null", @params );
}

sub _item_matches
{
	my( $self, $item ) = @_;

	return $item->is_set( $self->{field}->get_name );
}

sub get_op_val
{
	return 4;
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $field = $self->{field};

	my $table = $self->{join}->{alias};
	my $sql_name = $field->get_sql_name;

	return $db->quote_identifier( $table, $sql_name )." is Null";
}

sub logic
{
	my( $self, %opts ) = @_;

	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;
	if( !$self->{field}->get_property( "multiple" ) )
	{
		$prefix = "";
	}

	my $db = $opts{session}->get_database;
	my $table = $prefix . $self->table;
	my $sql_name = $self->{field}->get_sql_name;

	return $db->quote_identifier( $table, $sql_name )." is Null";
}

1;
