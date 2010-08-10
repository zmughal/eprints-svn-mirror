######################################################################
#
# EPrints::MetaField::Namedset;
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

B<EPrints::MetaField::Namedset> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# set_name

package EPrints::MetaField::Namedset;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Set );
}

use EPrints::MetaField::Set;

sub tags
{
	my( $self, $session ) = @_;

	if( defined $self->{options} )
	{
		return @{$self->{options}};
	}
	return $session->get_repository->get_types( $self->{set_name} );
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	if( defined $self->{options} )
	{
		return @{$self->{options}};
	}
	my @types = $session->get_repository->get_types( $self->{set_name} );

	return @types;
}

sub render_option
{
	my( $self, $session, $value ) = @_;

	if( !defined $value )
	{
		return $self->SUPER::render_option( $session, $value );
	}

	return $session->render_type_name( $self->{set_name}, $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{set_name} = $EPrints::MetaField::REQUIRED;
	$defaults{options} = $EPrints::MetaField::UNDEF;
	return %defaults;
}

sub get_search_group { return 'set'; }

=item $ov = $field->ordervalue_basic( $value, $session, $langid )

Return $value as an order value that will be cmp().

For Namedset this returns the values in the order they are given in the named set.

=cut

sub ordervalue_basic
{
	my( $self, $value, $session, $langid ) = @_;

	my @types = $self->tags( $session );
	foreach my $i (0..$#types)
	{
		return sprintf("%06d", $i)
			if $types[$i] eq $value;
	}

	# this will always come after any known values
	return $value;
}


######################################################################
1;
