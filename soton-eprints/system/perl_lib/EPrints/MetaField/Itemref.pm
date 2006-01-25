######################################################################
#
# EPrints::MetaField::Itemref;
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

B<EPrints::MetaField::Itemref> - Reference to an object with an "int" type of ID field.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Itemref;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Int );
}

use EPrints::MetaField::Int;

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	return %defaults;
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff ) = @_;

	my $ex = $self->SUPER::get_basic_input_elements( $session, $value, $suffix, $staff );

	my $ds = $session->get_archive->get_dataset( 
			$self->get_property('datasetid') );
	my $desc;
	if( defined $value )
	{
		my $object = $ds->get_object( $session, $value );
		if( defined $object )
		{
			$desc = $object->render_citation_link;
		}
		else
		{
			$desc = $session->html_phrase( 
				"lib/metafield/itemref:not_found",
					id=>$session->make_text($value),
					objtype=>$session->html_phrase(
				"general:dataset_object_".$ds->confid));
		}
	}
	else
	{
		$desc = $session->make_doc_fragment;
	}
	push @{$ex->[0]}, {el=>$desc};

	return $ex;
}

sub get_input_elements
{   
	my( $self, $session, $value, $staff ) = @_;

	my $ex = $self->SUPER::get_input_elements( $session, $value, $staff );

	#my $buttons = $ex->[scalar @{$ex}-1]->[1]->{el};
	#$buttons->appendChild( $session->render_internal_buttons( $self->{name}."_null" => "Check ID's" ));
	my $buttons = $session->make_doc_fragment;
	$buttons->appendChild( 
		$session->render_internal_buttons( 
			$self->{name}."_null" => $session->phrase(
				"lib/metafield/itemref:lookup" )));
	my $bl = [];
	# pad the bottom line by one if this is a list to 
	# skip the column with the number in.
	if( $self->get_property( 'multiple' ) )
	{
		push @{$bl},{};
	}
	push @{$bl},{el=>$buttons,colspan=>3};
	push @{$ex}, $bl;

	return $ex;
}




######################################################################
1;
