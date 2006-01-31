######################################################################
#
# EPrints::History
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

B<EPrints::History> - An element in the history of the arcvhive.

=head1 DESCRIPTION

This class describes a single item in the history dataset. A history
object describes a single action taken on a single item in another
dataset.

Changes to document are considered part of changes to the eprint it
belongs to.

=head1 METADATA

=over 4

=item historyid (int)

The unique numerical ID of this history event. 

=item userid (itemref)

The id of the user who caused this event. A value of zero or undefined
indicates that there was no user responsible (ie. a script did it). 

=item datasetid (text)

The name of the dataset to which the modified item belongs.

=item objectid (int)

The numerical ID of the object in the dataset. Being numerical means
this will only work for users and eprints. (maybe subscriptions).

=item revision (int)

The revision of the object. This is the revision number after the
action occured. Not all actions increase the revision number.

=item timestamp (time)

The moment at which this thing happened.

=item action (set)

The type of event. Provisionally, this is a subset of the new list
of privilages.

=item details (longtext)

If this is a "rejection" then the details contain the message sent
to the user. 

=back

=head1 METHODS

=over 4

=cut

package EPrints::History;
@ISA = ( 'EPrints::DataObj' );
use EPrints::DataObj;

use strict;


######################################################################
=pod

=item $field_info = EPrints::History->get_system_field_info

Return the metadata field configuration for this object.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"historyid", type=>"int", required=>1 }, 

		{ name=>"userid", type=>"itemref", 
			datasetid=>"user", required=>0 },

		# should maybe be a set?
		{ name=>"datasetid", type=>"text" }, 

		# is this required?
		{ name=>"objectid", type=>"int" }, 

		{ name=>"revision", type=>"int" },

		{ name=>"timestamp", type=>"time" }, 

		# TODO should be a set when I know what the actions will be
		{ name=>"action", type=>"text" }, 

		{ name=>"details", type=>"longtext" }, 
	);
}



######################################################################
=pod

=item $history = EPrints::History->new( $session, $historyid )

Return a history object with id $historyid, from the database.

Return undef if no such object extists.

=cut
######################################################################

sub new
{
	my( $class, $session, $historyid ) = @_;

	return $session->get_db()->get_single( 
			$session->get_archive()->get_dataset( "history" ), 
			$historyid );

}



######################################################################
=pod

=item undef = EPrints::History->new_from_data( $session, $data )

Create a new History object from the given $data. Used to turn items
from the database into objects.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data ) = @_;

	my $self = {};
	
	$self->{data} = $data;
	$self->{dataset} = $session->get_archive()->get_dataset( "history" ); 
	$self->{session} = $session;
	bless $self, $class;

	return( $self );
}



######################################################################
=pod

=item $history->commit 

Not meaningful. History can't be altered.

=cut
######################################################################

sub commit 
{
	my( $self, $force ) = @_;

	$self->{session}->get_archive->log(
		"WARNING: Called commit on a EPrints::History object." );
	return 0;
}


######################################################################
=pod

=item $history->remove

Not meaningful. History can't be altered.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	$self->{session}->get_archive->log(
		"WARNING: Called remove on a EPrints::History object." );
	return 0;
}

######################################################################
=pod

=item EPrints::History::create( $session, $data );

Create a new history object from this data. Unlike other create
methods this one does not return the new object as it's never 
needed, and would increase the load of modifying items.

Also, this does not queue the fields for indexing.

=cut
######################################################################

sub create
{
	my( $session, $data ) = @_;

	# don't want to mangle the origional data.
	$data = EPrints::Utils::clone( $data );
	
	$data->{historyid} = $session->get_db()->counter_next( "historyid" );
	$data->{timestamp} = EPrints::Utils::get_datetimestamp( time );
	my $dataset = $session->get_archive()->get_dataset( "history" );
	my $success = $session->get_db()->add_record( $dataset, $data );

	return( undef );

#	if( $success )
#	{
#		my $eprint = EPrints::History->new( $session, $new_id, $dataset );
#		$eprint->queue_all;
#		return $eprint;
#	}
#
##	$newsub->queue_all;
}


######################################################################
=pod

=item $history->render

This can't be rendered in this way so this just reports an error
and stack trace.

=cut
######################################################################

sub render
{
	confess( "oooops" ); # use render citation
}

1;

######################################################################
=pod

=back

=cut

