######################################################################
#
# EPrints::Search::Condition::Or
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

B<EPrints::Search::Condition::Or> - "Or"

=head1 DESCRIPTION

Union of results of several sub conditions

=cut

package EPrints::Search::Condition::Or;

use EPrints::Search::Condition::Control;
use Scalar::Util qw( refaddr );

@ISA = qw( EPrints::Search::Condition::Control );

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = bless { op=>"OR", sub_ops=>\@params }, $class;

	$self->{prefix} = $self;
	$self->{prefix} =~ s/^.*:://;

	return $self;
}

sub optimise_specific
{
	my( $self, %opts ) = @_;

	my $keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		# {ANY} OR TRUE is always TRUE
		return $sub_op if $sub_op->{op} eq "TRUE";

		# {ANY} OR FALSE is always {ANY}
		next if @{$keep_ops} > 0 && $sub_op->{op} eq "FALSE";
		
		push @{$keep_ops}, $sub_op;
	}
	$self->{sub_ops} = $keep_ops;

	return $self if @{$self->{sub_ops}} == 1;

	my $dataset = $opts{dataset};

	my %tables;
	$keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		my $inner_dataset = $sub_op->dataset;
		my $table = $sub_op->table;
		# doesn't need a sub-query
		if( !defined $inner_dataset )
		{
			push @$keep_ops, $sub_op;
		}
		else
		{
			push @{$tables{$table}||=[]}, $sub_op;
		}
	}

	foreach my $table (keys %tables)
	{
		push @$keep_ops, EPrints::Search::Condition::SubQuery->new(
				$tables{$table}->[0]->dataset,
				@{$tables{$table}}
			);
	}
	$self->{sub_ops} = $keep_ops;

	return $self;
}

sub joins
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $dataset = $opts{dataset};

	my $alias = "or_".refaddr( $self );
	my $key_name = $dataset->get_key_field->get_sql_name;

	my @unions;
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		push @unions, $sub_op->sql( %opts, key_alias => $key_name );
	}

	my $sql = "(".join(' UNION ', @unions).")";

	return {
		type => "inner",
		subquery => $sql,
		alias => $alias,
		key => $key_name,
	};
}

sub logic
{
	my( $self, %opts ) = @_;

	return ();
}

1;
