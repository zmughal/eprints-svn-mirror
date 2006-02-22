######################################################################
#
# EPrints::MetaField::License;
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

B<EPrints::MetaField::License> - A named URL

=head1 DESCRIPTION

A URL that also contains a multi-language label. It is rendered as a link on the label.

=head1 SEE ALSO

L<EPrints::DataObj::License>

=over 4

=cut

# datasetid

package EPrints::MetaField::License;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Set );
}

use EPrints::MetaField::Set;

sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;
	
	my $ds = $session->get_repository->get_dataset(
			$self->get_property( "datasetid" ) );
	my $obj = $session->get_db()->get_single( $ds, $value );

	my $text = $session->make_text( $obj->get_label() );

	return $text if( $dont_link );

	my $a = $session->render_link( $obj->get_url() );
	$a->appendChild( $text );

	return $a;
}

sub tags_and_labels
{
	my( $self, $session ) = @_;

	my $ds = $session->get_repository->get_dataset(
			$self->get_property( "datasetid" ) );

	return $ds->make_object( $session, {} )->tags_and_labels( $session, $ds );
}

sub get_values { get_unsorted_values( @_ ) }

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my( $tags, undef ) = $self->tags_and_labels( $session );

	return $tags;
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	my $ds = $session->get_repository->get_dataset( 
			$self->{datasetid} );	

	return $session->make_text(
		$ds->get_object( $session, $value )->get_label()
	);
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
}

######################################################################
1;
