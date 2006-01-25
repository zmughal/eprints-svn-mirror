######################################################################
#
# EPrints::MetaField::Search;
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

B<EPrints::MetaField::Search> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# datasetid

package EPrints::MetaField::Search;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Basic );
}

use EPrints::MetaField::Basic;

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return $self->get_sql_name()." TEXT".($notnull?" NOT NULL":"");
}

# never SQL index this type
sub get_sql_index
{
	my( $self ) = @_;

	return undef;
}


sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;

	my $searchexp = $self->make_searchexp( $session, $value );
	my $desc = $searchexp->render_description;
	$searchexp->dispose;
	return $desc;
}


######################################################################
# 
# $searchexp = $field->make_searchexp( $session, $value, [$prefix] )
#
# This method should only be called on fields of type "search". 
# Return a search expression from the serialised expression in value.
# $prefix is passed to the SearchExpression to prefix all HTML form
# field ids when more than one search will exist in the same form. 
#
######################################################################

sub make_searchexp
{
	my( $self, $session, $value, $prefix ) = @_;

	my $ds = $session->get_archive()->get_dataset( 
			$self->{datasetid} );	

	my $searchexp = EPrints::SearchExpression->new(
		session => $session,
		dataset => $ds,
		prefix => $prefix,
		fieldnames => $self->get_property( "fieldnames" ) );
	$searchexp->from_string( $value );

	return $searchexp;
}		

sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff, $obj ) = @_;

	#cjg NOT CSS'd properly.

	my $div = $session->make_element( 
		"div", 
		style => "padding: 6pt; margin-left: 24pt; " );

	# cjg - make help an option?

	my $searchexp = $self->make_searchexp( 
		$session,
		$value,
		$self->{name}.$suffix."_" );
	$div->appendChild( $searchexp->render_search_fields( 0 ) );
	if( $self->get_property( "allow_set_order" ) )
	{
		$div->appendChild( $searchexp->render_order_menu );
	}
	$searchexp->dispose();

	return [ [ { el=>$div } ] ];
}


sub form_value_basic
{
	my( $self, $session, $suffix ) = @_;
	
	my $ds = $session->get_archive()->get_dataset( 
			$self->{datasetid} );	
	my $searchexp = EPrints::SearchExpression->new(
		session => $session,
		dataset => $ds,
		prefix => $self->{name}.$suffix."_",
		fieldnames => $self->get_property( "fieldnames" ) );
	$searchexp->from_form;
	my $value = undef;
	unless( $searchexp->is_blank )
	{
		$value = $searchexp->serialise;	
	}
	$searchexp->dispose();

	return $value;
}

sub get_search_group { return 'search'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	$defaults{fieldnames} = $EPrints::MetaField::REQUIRED;
	$defaults{allow_set_order} = 0;
	return %defaults;
}


######################################################################
1;
