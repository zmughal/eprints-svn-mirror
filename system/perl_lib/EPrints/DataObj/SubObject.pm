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

	$parent = $ds->get_object( $session, $objectid );
	$self->set_parent( $parent );

	return $parent;
}

sub set_parent
{
	my( $self, $parent ) = @_;

	$self->{_parent} = $parent;
}

1;
