######################################################################
#
# EPrints::SearchField
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

B<EPrints::SearchField> - undocumented

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

#####################################################################
#
#  Search Field
#
#   Represents a single field in a search.
#
######################################################################
#
#  __LICENSE__
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
	my( $class, $session, $dataset, $fields, $value, $match, $merge, $prefix ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{session} = $session;
	$self->{dataset} = $dataset;

	$self->{value} = $value;
	$self->{match} = ( defined $match ? $match : "EQ" );
	$self->{merge} = ( defined $merge ? $merge : "PHR" );

	if( ref( $fields ) ne "ARRAY" )
	{
		$fields = [ $fields ];
	}

	$self->{fieldlist} = $fields;
	my( @fieldnames, @display_names );
	foreach my $f (@{$fields})
	{
		if( !defined $f )
		{
			#cjg an aktual error.
			die "Field not defined in SearchField";
		}
		push @fieldnames, $f->get_sql_name();
		push @display_names, $f->display_name( $self->{session} );
	}

	$prefix = "" unless defined $prefix;
		
	$self->{display_name} = join '/', @display_names;
	$self->{id} = join '/', sort @fieldnames;
	$self->{form_name_prefix} = $prefix.$self->{id};
	$self->{field} = $fields->[0];

	if( $self->{field}->get_property( "hasid" ) )
	{
		$self->{field} = $self->{field}->get_main_field();
	}

	# a search is "simple" if it contains a mix of fields. 
	# 'text indexable" fields (longtext,text,url & email) all count 
	# as one type. int & year count as one type.

	foreach my $f (@{$fields})
	{
		my $f_searchgroup = $f->get_search_group;
		if( !defined $self->{search_mode} ) 
		{
			$self->{search_mode} = $f_searchgroup;
			next;
		}
		if( $self->{search_mode} ne $f_searchgroup )
		{
			$self->{search_mode} = 'simple';
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
	
	$self->{match} = "NO";
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

	my $val = $self->{session}->param( $self->{form_name_prefix} );
	$val =~ s/^\s+//;
	$val =~ s/\s+$//;
	$val = undef if( $val eq "" );

	my $problem;

	( $self->{value}, $self->{merge}, $self->{match}, $problem ) =
		$self->{field}->from_search_form( 
			$self->{session}, 
			$self->{form_name_prefix} );

	$self->{value} = "" unless( defined $self->{value} );
	$self->{merge} = "PHR" unless( defined $self->{merge} );
	$self->{match} = "EQ" unless( defined $self->{match} );

	# match = NO? if value==""

	if( $problem )
	{
		$self->{match} = "NO";
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

	if( $self->{match} eq "NO" )
	{
		return EPrints::SearchCondition->new( 'FALSE' );
	}

	if( $self->{match} eq "EX" )
	{
		return $self->get_conditions_no_split( $self->{value} );
	}

	if( !EPrints::Utils::is_set( $self->{value} ) )
	{
		return EPrints::SearchCondition->new( 'FALSE' );
	}

	my @parts;
	if( $self->{search_mode} eq "simple" )
	{
		@parts = EPrints::Index::split_words( 
			$self->{session},  # could be just archive?
			EPrints::Index::apply_mapping( 
				$self->{session}, 
				$self->{value} ) );
	}
	else
	{
		@parts = $self->{field}->split_search_value( 
			$self->{session},
			$self->{value} );
	}

	my @r = ();
	foreach my $value ( @parts )
	{
		push @r, $self->get_conditions_no_split( $value );
	}
	
	return EPrints::SearchCondition->new( 
		($self->{merge}eq"ANY"?"OR":"AND"), 
		@r );
}

sub get_conditions_no_split
{
	my( $self,  $search_value ) = @_;

	# special case for name?

	my @r = ();
	foreach my $field ( @{$self->{fieldlist}} )
	{
		push @r, $field->get_search_conditions( 
				$self->{session},
				$self->{dataset},
				$search_value,
				$self->{match},
				$self->{merge},
				$self->{search_mode} );
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

	return $self->{value};
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

	return $self->{match};
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

	return $self->{merge};
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
	return $self->{field};
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
	return $self->{fieldlist};
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

	return $self->{field}->render_search_input( 
					$self->{session}, 
					$self->{form_name_prefix},
					$self->{value},
					$self->{merge} );
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

	my $frag = $self->{session}->make_doc_fragment;

	my $sfname = $self->{session}->make_text( $self->{display_name} );

	return $self->{field}->render_search_description(
			$self->{session},
			$sfname,
			$self->{value},
			$self->{merge},
			$self->{match} );
}

######################################################################
=pod

=item $foo = $sf->get_help

undocumented

=cut
######################################################################

sub get_help
{
        my( $self ) = @_;

        return $self->{session}->phrase( "lib/searchfield:help_".$self->{field}->get_type() );
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
	return $self->{field}->is_type( @types );
}


######################################################################
=pod

=item $foo = $sf->get_display_name

undocumented

=cut
######################################################################

sub get_display_name
{
	my( $self ) = @_;
	return $self->{display_name};
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
	return $self->{id};
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

	return EPrints::Utils::is_set( $self->{value} ) || $self->{match} eq "EX";
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

	# cjg. Might make an teeny improvement if
	# we sorted the {value} so that equiv. searches
	# have the same serialisation string.

	my @fnames;
	foreach( @{$self->{fieldlist}} )
	{
		push @fnames, $_->get_name().($_->get_property( "idpart" )?".id":"");
	}
	
	my @escapedparts;
	foreach(join( "/", sort @fnames ),
		$self->{merge}, 	
		$self->{match}, 
		$self->{value} )
	{
		my $item = $_;
		$item =~ s/[\\\:]/\\$&/g;
		push @escapedparts, $item;
	}
	return join( ":" , @escapedparts );
}


######################################################################
=pod

=item $thing = EPrints::SearchField->unserialise( $session, $dataset, $string )

undocumented

=cut
######################################################################

sub unserialise
{
	my( $class, $session, $dataset, $string ) = @_;

	$string=~m/^([^:]*):([^:]*):([^:]*):(.*)$/;
	my( $fields, $merge, $match, $value ) = ( $1, $2, $3, $4 );
	# Un-escape (cjg, not very tested)
	$value =~ s/\\(.)/$1/g;

	my @fields = ();
	foreach( split( "/" , $fields ) )
	{
		push @fields, $dataset->get_field( $_ );
	}

	return $class->new( $session, $dataset, \@fields, $value, $match, $merge );
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

	$self->{dataset} = $dataset;
}




1;

######################################################################
=pod

=back

=cut



