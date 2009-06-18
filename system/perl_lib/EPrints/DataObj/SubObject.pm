######################################################################
#
# EPrints::DataObj::SubObject
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


=head1 NAME

B<EPrints::DataObj::SubObject> - virtual class to support sub-objects

=head1 DESCRIPTION

This virtual class provides some utility methods to objects that are sub-objects of other data objects.

It expects to find "datasetid" and "objectid" fields to identify the parent object with.

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::SubObject;

@ISA = qw( EPrints::DataObj );

use strict;

=item $dataobj = EPrints::DataObj::File->new_from_data( $session, $data [, $dataset ] )

Looks for a special B<_parent> element in $data and uses it to set the parent object, if defined.

=cut

sub new_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $parent = delete $data->{_parent};

	my $self = $class->SUPER::new_from_data( $session, $data, $dataset );

	if( defined $parent )
	{
		$self->set_parent( $parent );
	}

	return $self;
}

=item $dataobj = EPrints::DataObj::File->create_from_data( $session, $data [, $dataset ] )

Looks for a special B<_parent> element in $data and uses it to create default values for B<datasetid> and B<objectid> if parent is available and those fields exist on the object.

=cut

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $parent = $data->{_parent};
	if( defined( $parent ) )
	{
		if( $dataset->has_field( "datasetid" ) )
		{
			$data->{datasetid} ||= $parent->get_dataset->confid;
		}
		if( $dataset->has_field( "objectid" ) )
		{
			$data->{objectid} ||= $parent->get_id;
		}
	}

	return $class->SUPER::create_from_data( $session, $data, $dataset );
}

=item $dataobj = $dataobj->get_parent( [ $datasetid [, $objectid ] ] )

Get and cache the parent data object. If $datasetid and/or $objectid are specified will use these values rather than the stored values.

Subsequent calls to get_parent will return the cached object, regardless of $datasetid and $objectid.

=cut

sub get_parent
{
	my( $self, $datasetid, $objectid ) = @_;

	return $self->{_parent} if defined( $self->{_parent} );

	my $session = $self->get_session;

	$datasetid = $self->get_value( "datasetid" ) unless defined $datasetid;
	$objectid = $self->get_value( "objectid" ) unless defined $objectid;

	my $ds = $session->get_repository->get_dataset( $datasetid );

	my $parent = $ds->get_object( $session, $objectid );
	$self->set_parent( $parent );

	return $parent;
}

sub set_parent
{
	my( $self, $parent ) = @_;

	$self->{_parent} = $parent;
}

=item $id = $dataobj->get_parent_dataset_id()

Returns the id of the dataset that the parent object belongs to.

=cut

sub get_parent_dataset_id
{
	my( $self ) = @_;

	return $self->get_value( "datasetid" );
}

=item $id = $dataobj->get_parent_id()

Returns the id of the parent data object.

=cut

sub get_parent_id
{
	my( $self ) = @_;

	return $self->get_value( "objectid" );
}

1;
