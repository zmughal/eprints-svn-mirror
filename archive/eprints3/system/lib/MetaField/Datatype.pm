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

# datasetid

package EPrints::MetaField::Datatype;

use EPrints::Session;

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
	my( $self, $value, $dont_link ) = trim_params(@_);
	
	return $self->get_dataset->render_type_name( $value );
}


sub tags_and_labels
{
	my( $self ) = trim_params(@_);

	my $ds = $self->get_dataset;

	return( $ds->get_types(), $ds->get_type_names );
}

sub get_unsorted_values
{
	my( $self, $dataset, %opts ) = trim_params(@_);

	return $self->get_types->get_types();
}

sub get_value_label
{
	my( $self, $value ) = trim_params(@_);

	my $vn = $self->get_dataset->get_type_name( $value );
	return &SESSION->make_text( $vn );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
}

sub get_values
{
	my( $self, $dataset, %opts ) = trim_params(@_);

	my @outvalues = @{$self->get_dataset->get_types()};

	return \@outvalues;
}

# not inherrited, just used by Datatype for convenience
sub get_dataset
{
	my( $self ) = @_;

	return &ARCHIVE->get_dataset( $self->{datasetid} );	
}

######################################################################
1;
