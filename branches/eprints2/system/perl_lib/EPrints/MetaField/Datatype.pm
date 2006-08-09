######################################################################
#
# EPrints::MetaField::Datatype;
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

B<EPrints::MetaField::Datatype> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# type_set

package EPrints::MetaField::Datatype;

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

	return $session->get_repository->get_types( $self->{type_set} );
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my @types = $session->get_repository->get_types( $self->{type_set} );

	return @types;
}

sub render_option
{
	my( $self, $session, $value ) = @_;

	return $session->render_type_name( $self->{type_set}, $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{type_set} = $EPrints::MetaField::REQUIRED;
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
}



######################################################################
1;
