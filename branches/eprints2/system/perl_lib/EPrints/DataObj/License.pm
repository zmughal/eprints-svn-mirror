######################################################################
#
# EPrints::DataObj::License
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

B<EPrints::DataObj::License> - Licenses dataset

=head1 DESCRIPTION

Licenses contains a listing of end-user licenses that may be granted by a user (typically for Documents).

The C<name> is the multilanguage human-readable name of the license. The C<url> is the URL for the license (which is linked to in render_single_citation).

=head1 INSTANCE VARIABLES

=over 4

=item $obj->{ "data" }

=item $obj->{ "dataset" }

=item $obj->{ "session" }

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::License;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

=pod

=item $thing = EPrints::DataObj::License->get_system_field_info

Core fields contained in a license.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"licenseid", type=>"text", required=>1 },

		{ name=>"rev_number", type=>"int", required=>1 },

		{ name=>"url", type=>"text", required=>1, },
		
		{ name=>"name", type=>"text", required=>1, multilang=>1 },
	);
}

######################################################################
=pod

=head2 Constructor Methods

=cut
######################################################################

=pod

=item $thing = EPrints::DataObj::License->new( $session, $licenseid )

The data object identified by $licenseid.

=cut

sub new
{
	my( $class, $session, $licenseid ) = @_;

	return $session->get_db()->get_single( 
			$session->get_repository->get_dataset( "license" ), 
			$licenseid );
}

=pod

=item $thing = EPrints::DataObj::License->new_from_data( $session, $known )

A new C<EPrints::DataObj::License> object containing data $known (a hash reference).

=cut

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	my $self = {};
	
	$self->{data} = $known;
	$self->{dataset} = $session->get_repository->get_dataset( "license" ); 
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

=item EPrints::DataObj::License::remove_all( $session )

Remove all records from the license dataset.

=cut

sub remove_all
{
	my( $class, $session ) = @_;

	my $ds = $session->get_repository->get_dataset( "license" );
	foreach my $obj ( $session->get_db()->get_all( $ds ) )
	{
		$obj->remove();
	}
	return;
}

=pod

=item ($tags,$labels) = EPrints::DataObj::License::tags_and_labels( $session, $dataset )

Returns the tags and labels for all records in this dataset.

=cut

sub tags_and_labels
{
	my( $class, $session, $ds ) = @_;

	my $searchexp = EPrints::SearchExpression->new(
		allow_blank => 1,
		custom_order => "licenseid",
		session => $session,
		dataset => $ds );

	$searchexp->perform_search();
	
	my( @tags, %labels );
	foreach my $l ( $searchexp->get_records() )
	{
		push @tags, my $id = $l->get_value( "licenseid" );
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

=item $url = $obj->get_url( [$staff] )

The URL for the data object.

=cut

sub get_url
{
	my( $self, $staff ) = @_;
	return $self->get_value( "url" );
}

=pod

=item $label = $obj->get_label()

The human-readable label for the $obj in the current language. Defaults to english and, if that isn't available, the C<licenseid>.

=cut

sub get_label
{
	my( $self ) = @_;
	my $langid = $self->{ "session" }->get_langid();
	
	my $name = $self->get_value( "name" );
	return $name->{ $langid } || $name->{ "en" } || $self->get_value( "licenseid" );
}

=pod

=item EPrints::DataObj::License::render( "oooops" )

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

L<EPrints::MetaField::License>, L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

