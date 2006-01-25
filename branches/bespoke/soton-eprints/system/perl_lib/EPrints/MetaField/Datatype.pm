######################################################################
#
# EPrints::MetaField::Datatype;
#
######################################################################
#
#  This file is part of GNU EPrints 2.
#  
#  Copyright (c) 2000-2004 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 2 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 2 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 2; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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
	
	my $ds = $session->get_archive()->get_dataset(
			$self->get_property( "datasetid" ) );

	return $ds->render_type_name( $session, $value );
}


sub tags_and_labels
{
	my( $self, $session ) = @_;

	my $ds = $session->get_archive()->get_dataset( 
			$self->{datasetid} );	

	return( $ds->get_types(), $ds->get_type_names( $session ) );
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $ds = $session->get_archive()->get_dataset( 
			$self->{datasetid} );	
	return $ds->get_types();
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	my $ds = $session->get_archive()->get_dataset( 
			$self->{datasetid} );	
	return $session->make_text( 
		$ds->get_type_name( $session, $value ) );
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
	my( $self, $session, $dataset, %opts ) = @_;

	my $ds = $session->get_archive()->get_dataset(
		$self->{datasetid} );
	my @outvalues = @{$ds->get_types()};

	return \@outvalues;
}


######################################################################
1;
