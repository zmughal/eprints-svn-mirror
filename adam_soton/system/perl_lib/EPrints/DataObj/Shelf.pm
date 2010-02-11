######################################################################
#
# EPrints::DataObj::Shelf
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

B<EPrints::DataObj::Shelf> - Single shelf.

=head1 DESCRIPTION

A shelf is a sub class of EPrints::DataObj.

Each one belongs to one and only one user, although one user may own
multiple shelves.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::DataObj::Shelf;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;


######################################################################
=pod

=item $field_config = EPrints::DataObj::Shelf->get_system_field_info

Return an array describing the system metadata of the saved search.
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"shelfid", type=>"int", required=>1, import=>0, can_clone=>1, },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

		{ name=>"userid", type=>"itemref", 
			datasetid=>"user", required=>1 },

		{ name=>"title", type=>"text" },

		{ name=>"description", type=>"text" },

		{ name=>"public", type=>"boolean", input_style=>"radio" },

                { name=>"items", type=>"itemref", datasetid=>"eprint", multiple=>1, required=>1 },

		{ name=>"datestamp", type=>"time", required=>0, import=>0,
			render_res=>"minute", render_style=>"short", can_clone=>0 },
		
		{ name=>"lastmod", type=>"time", required=>0, import=>0,
			render_res=>"minute", render_style=>"short", can_clone=>0 },
	

	);
}


######################################################################
=pod

=item $shelf = EPrints::DataObj::Shelf->new( $session, $id )

Return new Saved Search object, created by loading the Saved Search
with id $id from the database.

=cut
######################################################################

sub new
{
	my( $class, $session, $id ) = @_;

	return $session->get_database->get_single( 	
		$session->get_repository->get_dataset( "shelf" ),
		$id );
}

######################################################################
=pod

=item $shelf = EPrints::DataObj::Shelf->new_from_data( $session, $data )

Construct a new EPrints::DataObj::Shelf object based on the $data hash 
reference of metadata.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "shelf" ) );
}


######################################################################
# =pod
# 
# =item $shelf = EPrints::DataObj::Shelf->create( $session, $userid )
# 
# Create a new saved search. entry in the database, belonging to user
# with id $userid.
# 
# =cut
######################################################################

sub create
{
	my( $class, $session, $userid ) = @_;

	return EPrints::DataObj::Shelf->create_from_data( 
		$session, 
		{ userid=>$userid },
		$session->get_repository->get_dataset( "shelf" ) );
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::Shelf->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	my $id = $session->get_database->counter_next( "shelfid" );

	$data->{shelfid} = $id;
	$data->{rev_number} = 1;
	$data->{public} = "FALSE";

#	$session->get_repository->call(
#		"set_shelf_defaults",
#		$data,
#		$session );

	return $data;
}	


######################################################################
=pod

=item $success = $shelf->remove

Remove the saved search.

=cut
######################################################################

sub get_user
{
	my( $self ) = @_;

	return EPrints::User->new( 
		$self->{session},
		$self->get_value( "userid" ) );
}

sub has_owner
{
	my( $self, $possible_owner ) = @_;

	if( $possible_owner->get_value( "userid" ) == $self->get_value( "userid" ) )
	{
		return 1;
	}

	return 0;
}

sub get_url
{
	my( $self , $staff ) = @_;

	return undef if( $self->get_value("public") ne "TRUE" );

	return $self->{session}->get_repository->get_conf( "http_cgiurl" )."/shelf?shelfid=".$self->get_id;
}

sub get_item_ids
{
	my ( $self ) = @_;

	return $self->get_value('items');
}


sub get_items
{
	my ($self) = @_;

	my $session = $self->{session};

        my $ds = $session->get_repository->get_dataset( 'eprint' );

	my $items = [];

	return $items unless $self->is_set('items');

	foreach my $eprintid (@{$self->get_value('items')})
	{
		push @{$items},  $ds->get_object( $session, $eprintid );
	}

        return $items;
}


=pod

=back

=cut

1;
