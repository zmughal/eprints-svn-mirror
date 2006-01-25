######################################################################
#
# EPrints::License
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

B<EPrints::License> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

######################################################################
#
# License class.
#
#  Handles the licenses dataset.
#
######################################################################
#
#  __LICENSE__
#
######################################################################

package EPrints::License;
@ISA = ( 'EPrints::DataObj' );
use EPrints::DataObj;

use EPrints::Database;
use EPrints::SearchExpression;

use strict;


######################################################################
=pod

=item $thing = EPrints::License->get_system_field_info

undocumented

=cut
######################################################################

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

=item $thing = EPrints::License->new( $session, $licenseid )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $session, $licenseid ) = @_;

	return $session->get_db()->get_single( 
			$session->get_archive()->get_dataset( "license" ), 
			$licenseid );
}



######################################################################
=pod

=item $thing = EPrints::License->new_from_data( $session, $known )

undocumented

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	my $self = {};
	
	$self->{data} = $known;
	$self->{dataset} = $session->get_archive()->get_dataset( "license" ); 
	$self->{session} = $session;
	bless $self, $class;

	return( $self );
}

######################################################################
=pod

=item $foo = $thing->commit 

undocumented

=cut
######################################################################

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


######################################################################
=pod

=item $foo = $thing->remove

undocumented

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	return $self->{session}->get_db()->remove(
		$self->{dataset},
		$self->get_id );
}


######################################################################
=pod

=item EPrints::License::remove_all( $session )

undocumented

=cut
######################################################################

sub remove_all
{
	my( $class, $session ) = @_;

	my $ds = $session->get_archive()->get_dataset( "license" );
	foreach my $obj ( $session->get_db()->get_all( $ds ) )
	{
		$obj->remove();
	}
	return;
}

=pod

=item ($tags,$labels) = EPrints::License::tags_and_labels( $session, $dataset )

Returns the tags and labels for all records in this dataset.

=cut

sub tags_and_labels
{
	my( $class, $session, $ds ) = @_;

	my( @tags, %labels );
	foreach my $l ( $session->get_db()->get_all( $ds ) )
	{
		push @tags, my $id = $l->get_value( "licenseid" );
		$labels{$id} = $l->get_label( $session );
	}

	return( \@tags, \%labels );
}

=pod

=item $url = $obj->get_url( [$staff] )

Returns the URL for the data object.

=cut

sub get_url
{
	my( $self, $staff ) = @_;
	return $self->get_value( "url" );
}

=pod

=item $label = $obj->get_label( $session (

Returns the label for the current $session (handles multilanguage).

=cut

sub get_label
{
	my( $self, $session ) = @_;
	
	my $name = $self->get_value( "name" );
	return $name->{ $session->get_langid() } || $name->{ "en" } || $self->get_value( "licenseid" );
}

# Licenses don't have a type.
#
# sub get_type
# {
# }

#deprecated

sub create
{
	my( $session, $data ) = @_;

	# don't want to mangle the origional data.
	$data = EPrints::Utils::clone( $data );
	
	$data->{licenseid} = $session->get_db()->counter_next( "historyid" );
	$data->{timestamp} = EPrints::Utils::get_datetimestamp( time );
	my $dataset = $session->get_archive()->get_dataset( "license" );
	my $success = $session->get_db()->add_record( $dataset, $data );

	return( undef );
}

######################################################################
=pod

=item EPrints::License::render( "oooops" )

undocumented

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

