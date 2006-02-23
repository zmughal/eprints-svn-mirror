######################################################################
#
# EPrints::DataObj::Access
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

B<EPrints::DataObj::Access> - Accesses to the Web server

=head1 DESCRIPTION

Inherits from L<EPrints::DataObj>.

=head1 INSTANCE VARIABLES

=over 4

=item $obj->{ "data" }

=item $obj->{ "dataset" }

=item $obj->{ "session" }

=back

=head1 CORE FIELDS

=over 4

=item accessid

Unique id for the access.

=item timestamp

Time of access.

=item requester_id

Id of the requesting user-agent (typically IP address).

=item requester_user_agent

The HTTP user agent string (useful for robots spotting).

=item requester_country

Country the request originated from.

=item requester_institution

Institution the request originated from.

=item referring_entity_id

Id of the object from which the user agent came from (i.e. HTTP referrer).

=item service_type_id

Id of the type of service requested.

=item referent_id

Id of the object requested.

=item referent_docid

Id of the document requested (if relevent).

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Access;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

=pod

=item $thing = EPrints::DataObj::Access->get_system_field_info

Core fields contained in a Web access.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"accessid", type=>"int", required=>1 },

		{ name=>"timestamp", type=>"time", required=>1, },

		{ name=>"requester_id", type=>"text", required=>1, },

		{ name=>"requester_user_agent", type=>"text", required=>0, },

		{ name=>"requester_country", type=>"text", required=>0, },

		{ name=>"requester_institution", type=>"text", required=>0, },

		{ name=>"referring_entity_id", type=>"text", required=>0, },

		{ name=>"service_type_id", type=>"text", required=>1, },

		{ name=>"referent_id", type=>"text", required=>1, },

		{ name=>"referent_docid", type=>"text", required=>0, },
	);
}

######################################################################
=pod

=back

=head2 Constructor Methods

=over 4

=cut
######################################################################

=pod

=item $thing = EPrints::DataObj::Access->new( $session, $accessid )

The data object identified by $accessid.

=cut

sub new
{
	my( $class, $session, $accessid ) = @_;

	return $session->get_db()->get_single( 
			$session->get_repository->get_dataset( "accesslog" ), 
			$accessid );
}

=pod

=item $thing = EPrints::DataObj::Access->new_from_data( $session, $known )

A new C<EPrints::DataObj::Access> object containing data $known (a hash reference).

=cut

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	my $self = {};
	
	$self->{data} = $known;
	$self->{dataset} = $session->get_repository->get_dataset( "accesslog" ); 
	$self->{session} = $session;
	bless $self, $class;

	return( $self );
}

######################################################################
=pod

=head2 Class Methods

=cut
######################################################################

=pod

=item EPrints::DataObj::Access::remove_all( $session )

Remove all records from the license dataset.

=cut

sub remove_all
{
	my( $class, $session ) = @_;

	my $ds = $session->get_repository->get_dataset( "accesslog" );
	foreach my $obj ( $session->get_db()->get_all( $ds ) )
	{
		$obj->remove();
	}
	return;
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::Access->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;
	
	$data->{accessid} = $session->get_db->counter_next( "accessid" );

	$data->{timestamp} = EPrints::Utils::get_datetimestamp( time );

	return $data;
}

=item ($tags,$labels) = EPrints::DataObj::Access::tags_and_labels( $session, $dataset )

Returns the tags and labels for all records in this dataset.

=cut

sub tags_and_labels
{
	my( $class, $session, $ds ) = @_;

	my $searchexp = EPrints::SearchExpression->new(
		allow_blank => 1,
		custom_order => "accessid",
		session => $session,
		dataset => $ds );

	$searchexp->perform_search();
	
	my( @tags, %labels );
	foreach my $l ( $searchexp->get_records() )
	{
		push @tags, my $id = $l->get_value( "accessid" );
		$labels{$id} = $l->get_label();
	}

	$searchexp->dispose();

	return( \@tags, \%labels );
}

######################################################################
=pod

=head2 Object Methods

=cut
######################################################################

=pod

=item $foo = $thing->commit() 

undocumented

=cut

sub commit 
{
	my( $self, $force ) = @_;

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	

	my $rv = $self->{session}->get_db()->update(
			$self->{dataset},
			$self->{data} );
	
	$self->queue_changes;

	return $rv;
}

=pod

=item $foo = $thing->remove()

Remove this record from the data set.

=cut

sub remove
{
	my( $self ) = @_;
	
	return $self->{session}->get_db()->remove(
		$self->{dataset},
		$self->get_id );
}

=pod

=item EPrints::DataObj::Access::render( "oooops" )

undocumented

=cut

sub render
{
	EPrints::abort( "oooops" ); # use render citation
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

