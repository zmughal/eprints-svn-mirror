######################################################################
#
# EPrints::Value
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

B<EPrints::Value> - Represents a value. 

=head1 DESCRIPTION

This object represents a single value and the EPrints::Type of that value.

=cut

package EPrints::Value;

use Carp;
use Data::Dumper;
use strict;

######################################################################
=pod

=item $field = EPrints::Value->new( $type, [$data] );

Create a new value object. It should have a $type which is a
EPrints::Type object and an optional data value. 

=cut
######################################################################

sub new
{
	my( $class, $type, $data ) = @_;

	my $self = {};
	bless $self, $class;
	$self->{type} = $type;
	$self->{data} = $data;

	return $self;
}

######################################################################
=pod

=item $type = $field->getType()

Return the type of this field

=cut
######################################################################

sub getType
{
	my( $self ) = @_;

	return $self->{type};
}

######################################################################
=pod

=item $string = $type->toString()

Convert this object to a string.

=cut
######################################################################

sub toString
{
	my( $self ) = @_;

	return Dumper( $self->exportData );
}

######################################################################
=pod

=item $data_struct = $field->exportData()

Convert this value to a perl data structure.

=cut
######################################################################

sub exportData
{
	my( $self ) = @_;

	return $self->{type}->exportData( $self->{data} );
}

######################################################################
=pod

=item $data = $field->getData()

Return the data in this value.

asArray, asPrim and asHash should be used for preference as these
will do some type checking and give better error reports.

=cut
######################################################################

sub getData
{
	my( $self ) = @_;

	#return $self->{type}->exportData( $self->{data} );
	return $self->{data};
}

######################################################################
=pod

=item $data = $field->asArray()

Return the data in this value. Die with an error if this is not legal.

=cut
######################################################################

sub asArray
{
	my( $self ) = @_;

	croak( "Called asArray in illegal context" );
}

######################################################################
=pod

=item $data = $field->asHash()

Return the data in this value. Die with an error if this is not legal.

=cut
######################################################################

sub asHash
{
	my( $self ) = @_;

	croak( "Called asHash in illegal context" );
}


######################################################################
=pod

=item $data = $field->asPrim()

Return the data in this value. Die with an error if this is not legal.

=cut
######################################################################

sub asPrim
{
	my( $self ) = @_;

	croak( "Called asPrim in illegal context" );
}



######################################################################
1; # For use/require success
######################################################################

=pod
=back
=cut

