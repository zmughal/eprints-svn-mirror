######################################################################
#
# EPrints::SearchField
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

B<EPrints::SearchField> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{"foo"}
#     undefined
#
######################################################################

#####################################################################
#
#  Search Field
#
#   Represents a single field in a search.
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

#cjg =- None of the SQL values are ESCAPED - do it at one go later!

package EPrints::SearchField;

use EPrints::Session;
use EPrints::Database;
use EPrints::Subject;
use EPrints::Index;
use EPrints::SearchCondition;

use strict;

# Nb. match=EX searches CANNOT be used in the HTML form (currently)
# EX is "Exact", like EQuals but allows blanks.
# EX search on subject only searches for that subject, not things
# below it.

#cjg MAKE $field $fields and _require_ a [] 

######################################################################
=pod

=item $thing = EPrints::SearchField->new( $session, $dataset, $fields, $value, $match, $merge, $prefix )

undocumented

Special case - if match is "EX" and field type is name then value must
be a name hash.

=cut
######################################################################

sub new
{
	my( $class, $session, $dataset, $fields, $value, $match, $merge, $prefix, $id ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{"session"} = $session;
	$self->{"dataset"} = $dataset;

	$self->{"value"} = $value;
	$self->{"match"} = ( defined $match ? $match : "EQ" );
	$self->{"merge"} = ( defined $merge ? $merge : "PHR" );

	if( ref( $fields ) ne "ARRAY" )
	{
		$fields = [ $fields ];
	}

	$self->{"fieldlist"} = $fields;

	$prefix = "" unless defined $prefix;
		
	$self->{"id"} = $id;

	if( !defined $self->{"id"} )
	{
		my( @fieldnames );
		foreach my $f (@{$self->{"fieldlist"}})
		{
			push @fieldnames, $f->get_sql_name();
		}
		$self->{"id"} = join '/', sort @fieldnames;
	}


	$self->{"form_name_prefix"} = $prefix.$self->{"id"};
	$self->{"field"} = $fields->[0];

	if( $self->{"field"}->get_property( "hasid" ) )
	{
		$self->{"field"} = $self->{"field"}->get_main_field();
	}

	# a search is "simple" if it contains a mix of fields. 
	# 'text indexable" fields (longtext,text,url & email) all count 
	# as one type. int & year count as one type.

	foreach my $f (@{$fields})
	{
		my $f_searchgroup = $f->get_search_group;
		if( !defined $self->{"search_mode"} ) 
		{
			$self->{"search_mode"} = $f_searchgroup;
			next;
		}
		if( $self->{"search_mode"} ne $f_searchgroup )
		{
			$self->{"search_mode"} = 'simple';
			last;
		}
	}

	return $self;
}

	

######################################################################
=pod

=item $foo = $sf->clear

undocumented

=cut
######################################################################

sub clear
{
	my( $self ) = @_;
	
	$self->{"match"} = "NO";
}

######################################################################
#
# $problem = from_form()
#
#  Update the value of the field from the form. Returns any problem
#  that might have happened, or undef if everything was OK.
#
######################################################################


######################################################################
=pod

=item $foo = $sf->from_form

undocumented

=cut
######################################################################

sub from_form
{
	my( $self ) = @_;

	my $val = $self->{"session"}->param( $self->{"form_name_prefix"} );
	$val =~ s/^\s+//;
	$val =~ s/\s+$//;
	$val = undef if( $val eq "" );

	my $problem;

	( $self->{"value"}, $self->{"merge"}, $self->{"match"}, $problem ) =
		$self->{"field"}->from_search_form( 
			$self->{"session"}, 
			$self->{"form_name_prefix"} );

	$self->{"value"} = "" unless( defined $self->{"value"} );
	$self->{"merge"} = "PHR" unless( defined $self->{"merge"} );
	$self->{"match"} = "EQ" unless( defined $self->{"match"} );

	# match = NO? if value==""

	if( $problem )
	{
		$self->{"match"} = "NO";
		return $problem;
	}

	return;
}
	
	



######################################################################
=pod

=item $foo = $sf->get_conditions 

undocumented

=cut
######################################################################

sub get_conditions
{
	my( $self ) = @_;

	if( $self->{"match"} eq "NO" )
	{
		return EPrints::SearchCondition->new( 'FALSE' );
	}

	if( $self->{"match"} eq "EX" )
	{
		return $self->get_conditions_no_split( $self->{"value"} );
	}

	if( !EPrints::Utils::is_set( $self->{"value"} ) )
	{
		return EPrints::SearchCondition->new( 'FALSE' );
	}

	my @parts;
	if( $self->{"search_mode"} eq "simple" )
	{
		@parts = EPrints::Index::split_words( 
			$self->{"session"},  # could be just archive?
			EPrints::Index::apply_mapping( 
				$self->{"session"}, 
				$self->{"value"} ) );
	}
	else
	{
		@parts = $self->{"field"}->split_search_value( 
			$self->{"session"},
			$self->{"value"} );
	}

	my @r = ();
	foreach my $value ( @parts )
	{
		push @r, $self->get_conditions_no_split( $value );
	}
	
	return EPrints::SearchCondition->new( 
		($self->{"merge"}eq"ANY"?"OR":"AND"), 
		@r );
}

sub get_conditions_no_split
{
	my( $self,  $search_value ) = @_;

	# special case for name?

	my @r = ();
	foreach my $field ( @{$self->{"fieldlist"}} )
	{
		push @r, $field->get_search_conditions( 
				$self->{"session"},
				$self->{"dataset"},
				$search_value,
				$self->{"match"},
				$self->{"merge"},
				$self->{"search_mode"} );
	}
	return EPrints::SearchCondition->new( 'OR', @r );
}	


	
######################################################################
=pod

=item $foo = $sf->get_value

undocumented

=cut
######################################################################

sub get_value
{
	my( $self ) = @_;

	return $self->{"value"};
}


######################################################################
=pod

=item $foo = $sf->get_match

undocumented

=cut
######################################################################

sub get_match
{
	my( $self ) = @_;

	return $self->{"match"};
}


######################################################################
=pod

=item $foo = $sf->get_merge

undocumented

=cut
######################################################################

sub get_merge
{
	my( $self ) = @_;

	return $self->{"merge"};
}



#returns the FIRST field which should indicate type and stuff.

######################################################################
=pod

=item $foo = $sf->get_field

undocumented

=cut
######################################################################

sub get_field
{
	my( $self ) = @_;
	return $self->{"field"};
}

######################################################################
=pod

=item $foo = $sf->get_fields

undocumented

=cut
######################################################################

sub get_fields
{
	my( $self ) = @_;
	return $self->{"fieldlist"};
}




######################################################################
=pod

=item $xhtml = $sf->render

Returns an XHTML tree of this search field which contains all the 
input boxes required to search this field. 

=cut
######################################################################

sub render
{
	my( $self ) = @_;

	return $self->{"field"}->render_search_input( $self->{"session"}, $self );
}

######################################################################
=pod

=item $xhtml = $sf->get_form_prefix

Return the string use to prefix form field names so values
don't get mixed with other search fields.

=cut
######################################################################

sub get_form_prefix
{
	my( $self ) = @_;
	return $self->{"form_name_prefix"};
}



######################################################################
=pod

=item $xhtml = $sf->render_description

Returns an XHTML DOM object describing this field and its current
settings.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $frag = $self->{"session"}->make_doc_fragment;

	my $sfname = $self->render_name;

	return $self->{"field"}->render_search_description(
			$self->{"session"},
			$sfname,
			$self->{"value"},
			$self->{"merge"},
			$self->{"match"} );
}

######################################################################
=pod

=item $foo = $sf->render_name

Return XHTML object of this searchfields name.

=cut
######################################################################

sub render_name
{
	my( $self ) = @_;

	if( defined $self->{"id"} )
	{
		my $phraseid = "searchfield_name_".$self->{"id"};
		if( $self->{"session"}->get_lang->has_phrase( $phraseid ) )
		{
			return $self->{"session"}->html_phrase( $phraseid );
		}
	}

	# No id was set, gotta make a normal name from 
	# the metadata fields.
	my( $sfname ) = $self->{"session"}->make_doc_fragment;
	my( $first ) = 1;
	foreach my $f (@{$self->{"fieldlist"}})
	{
		if( !$first ) 
		{ 
			$sfname->appendChild( 
				$self->{"session"}->make_text( "/" ) );
		}
		$first = 0;
		$sfname->appendChild( $f->render_name( $self->{"session"} ) );
	}
	return $sfname;
}


######################################################################
=pod

=item $foo = $sf->render_help

undocumented

=cut
######################################################################

sub render_help
{
        my( $self ) = @_;

	my $custom_help = "searchfield_help_".$self->{"id"};
	my $phrase_id = "lib/searchfield:help_".$self->{"field"}->get_type();
	if( $self->{"session"}->get_lang->has_phrase( $custom_help ) )
	{
		$phrase_id = $custom_help
	}
		
        return $self->{"session"}->html_phrase( $phrase_id );
}


######################################################################
=pod

=item $foo = $sf->is_type( @types )

undocumented

=cut
######################################################################

sub is_type
{
	my( $self, @types ) = @_;
	return $self->{"field"}->is_type( @types );
}


######################################################################
=pod

=item $foo = $sf->get_id

undocumented

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;
	return $self->{"id"};
}


######################################################################
=pod

=item $foo = $sf->is_set

undocumented

=cut
######################################################################

sub is_set
{
	my( $self ) = @_;

	return EPrints::Utils::is_set( $self->{"value"} ) || $self->{"match"} eq "EX";
}


######################################################################
=pod

=item $foo = $sf->serialise

undocumented

=cut
######################################################################

sub serialise
{
	my( $self ) = @_;

	return undef unless( $self->is_set() );

	my @escapedparts;
	foreach($self->{"id"},
		$self->{"merge"}, 	
		$self->{"match"}, 
		$self->{"value"} )
	{
		my $item = $_;
		$item =~ s/[\\\:]/\\$&/g;
		push @escapedparts, $item;
	}
	return join( ":" , @escapedparts );
}


#sub serial_id
#{
#	my( $self ) = @_;
#
#	my @fnames;
#	foreach( @{$self->{"fieldlist"}} )
#	{
#		push @fnames, $_->get_name().($_->get_property( "idpart" )?".id":"");
#	}
#	return join( "/", sort @fnames ),
#}
	


######################################################################
=pod

=item $thing = EPrints::SearchField::unserialise( $string )

undocumented

=cut
######################################################################

sub unserialise
{
	my( $class, $string ) = @_;

	$string=~m/^([^:]*):([^:]*):([^:]*):(.*)$/;
	my $data = {};
	$data->{"id"} = $1;
	$data->{"merge"} = $2;
	$data->{"match"} = $3;
	$data->{"value"} = $4;
	# Un-escape (cjg, not very tested)
	$data->{"value"} =~ s/\\(.)/$1/g;

	return $data;
}

# only really meaningful to move between eprint datasets
# could be dangerous later with complex datasets.
# currently only used by the OAI code.

######################################################################
=pod

=item $foo = $sf->set_dataset( $dataset )

undocumented

=cut
######################################################################

sub set_dataset
{
	my( $self, $dataset ) = @_;

	$self->{"dataset"} = $dataset;
}




1;

######################################################################
=pod

=back

=cut



