######################################################################
#
#  Search Expression
#
#   Represents a whole set of search fields.
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

package EPrints::SearchExpression;

use EPrints::SearchField;
use EPrints::Session;
use EPrints::EPrint;
use EPrints::Database;
use EPrints::Language;

use strict;


######################################################################
#
# $exp = new( $session,
#             $table,
#             $allow_blank,
#             $satisfy_all,
#             $fields,
#             $orderby,
#             $defaultorder )
#
#  Create a new search expression, to search $table for the MetaField's
#  in $fields (an array ref.) Blank SearchExpressions are made for each
#  of these fields.
#
#  If $allowblank is non-zero, the searcher can leave all fields blank
#  in order to retrieve everything. In some cases this might be a bad
#  idea, for instance letting someone retrieve every eprint in the
#  archive might be a bit silly and lead to performance problems...
#
#  If $satisfyall is non-zero, then a retrieved eprint must satisy
#  all of the conditions set out in the search fields. Otherwise it
#  can satisfy any single specified condition.
#
#  $orderby specifies the possibilities for ordering the expressions,
#  in the form of a hash ref. This maps a text description of the ordering
#  to the SQL clause that will have the appropriate result.
#   e.g.  "by year (newest first)" => "year ASC, author, title"
#
#  Use from_form() to update with terms from a search form (or URL).
#
#  Use add_field() to add new SearchFields. You can't have more than
#  one SearchField for any single MetaField, though - add_field() will
#  wipe over the old SearchField in that case.
#
######################################################################

sub new
{
	my( $class,
	    $session,
	    $table,
	    $allow_blank,
	    $satisfy_all,
	    $fields,
	    $orderby,
	    $defaultorder ) = @_;
	
	my $self = {};
	bless $self, $class;

	# only session & table are required.
	# setup defaults for the others:
	$allow_blank = 0 if ( !defined $allow_blank );
	$satisfy_all = 1 if ( !defined $satisfy_all );
	$fields = [] if ( !defined $fields );
	$orderby = {} if ( !defined $orderby );

	$self->{session} = $session;
	$self->{table} = $table;
	$self->{allow_blank} = $allow_blank;
	$self->{satisfy_all} = $satisfy_all;

	# We're going to change the orderby stuff, so that we get
	#   $self->{order_ids}  array of ids
	#   $self->{order_desc} maps ids -> descriptions
	#   $self->{order_func}  maps ids -> func
	#   $self->{order}      id of default
	my $idcount = 0;
	$self->{order_ids} = [];
	$self->{order_desc} = {};
	$self->{order_func} = {};
	
	foreach (sort keys %{$orderby})
	{
		# IDs will be order0, order1, ...
		my $id = "order$idcount";
		$idcount++;
		$self->{order_desc}->{$id} = $_;
#EPrints::Log::debug( "SearchExpression", "Desc: $id -> $_" );
		$self->{order_func}->{$id} = $orderby->{$_};
		push @{$self->{order_ids}}, $id;
	
		$self->{order} = $id if( defined $defaultorder && $defaultorder eq $_ );
	}

	# Array for the SearchField objects
	$self->{searchfields} = [];
	# Map for MetaField names -> corresponding SearchField objects
	$self->{searchfieldmap} = {};

	# tmptable represents cached results table.	
	$self->{tmptable} = undef;
	
	foreach (@$fields)
	{
		$self->add_field( $_, undef );
	}
	
	return( $self );
}


######################################################################
#
# add_field( $field, $value )
#
#  Adds a new search field for the MetaField $field, or list of fields
#  if $field is an array ref, with default $value. If a search field
#  already exist, the value of that field is replaced with $value.
#
######################################################################

sub add_field
{
	my( $self, $field, $value ) = @_;

	# Create a new searchfield
	my $searchfield = new EPrints::SearchField( $self->{session},
	                                            $self->{table},					
	                                            $field,
	                                            $value );

	if( defined $self->{searchfieldmap}->{$searchfield->{formname}} )
	{
		# Already got a seachfield, just update the value
		$self->{searchfieldmap}->{$searchfield->{formname}}->set_value( $value );
	}
	else
	{
		# Add it to our list
		push @{$self->{searchfields}}, $searchfield;
		# Put it in the name -> searchfield map
		$self->{searchfieldmap}->{$searchfield->{formname}} = $searchfield;
	}
}


######################################################################
#
# clear()
#
#  Clear the search values of all search fields in the expression.
#
######################################################################

sub clear
{
	my( $self ) = @_;
	
	foreach (@{$self->{searchfields}})
	{
		$_->set_value( "" );
	}
	
	$self->{satisfy_all} = 1;
}


######################################################################
#
# $html = render_search_form( $help, $show_anyall )
#
#  Render the search form. If $help is 1, then help is written with
#  the search fields. If $show_anyall is 1, then the "must satisfy any/
#  all" field is shown at the bottom of the form.
#
######################################################################

sub render_search_form
{
	my( $self, $help, $show_anyall ) = @_;
	
	my %shown_help;

	my $html;

	my $menu;

	$html = "<P><TABLE BORDER=\"0\">\n";
	
	my $sf;

	foreach $sf (@{$self->{searchfields}})
	{
		my $shelp = $sf->search_help();
		if( $help && !defined $shown_help{$shelp} )
		{
			$html .= "<TR><TD COLSPAN=\"2\">";
			$html .= $shelp;
			$html .= "</TD></TR>\n";
			$shown_help{$shelp}=1;
		}
		
		$html .= "<TR><TD>$sf->{displayname}</TD><TD>";
		$html .= $sf->render_html();
		$html .= "</TD></TR>\n";

		$html .= "<TR><TD COLSPAN=\"2\">&nbsp;</TD></TR>\n";
	}
	
	$html .= "</TABLE></P>\n";

	if( $show_anyall )
	{
		$menu = $self->{session}->{render}->{query}->popup_menu(
			-name=>"_satisfyall",
			-values=>[ "ALL", "ANY" ],
			-default=>( defined $self->{satisfy_all} && $self->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			-labels=>{ "ALL" => $self->{session}->{lang}->phrase("F:all"),
				   "ANY" => $self->{session}->{lang}->phrase("F:any") } );
		$html .= "<P>";
		$html .= $self->{session}->{lang}->phrase( "H:mustfulfill",
							   $menu );
		$html .= "</P>\n";
	}


	$menu = $self->{session}->{render}->{query}->popup_menu(
		-name=>"_order",
		-values=>$self->{order_ids},
		-default=>$self->{order},
		-labels=>$self->{order_desc} );
		
	$html .= "<P>";
	$html .= $self->{session}->{lang}->phrase( "H:orderresults", $menu );
	$html .= "</P>\n";

	return( $html );
}


######################################################################
#
# $problems = from_form()
#
#  Update the search fields in this expression from the current HTML
#  form. Any problems are returned in @problems.
#
######################################################################

sub from_form
{
	my( $self ) = @_;

	my @problems;
	my $onedefined = 0;
	
	foreach( @{$self->{searchfields}} )
	{
		my $prob = $_->from_form();
		$onedefined = 1 if( defined $_->{value} );
		
		push @problems, $prob if( defined $prob );
	}

	push @problems, $self->{session}->{lang}->phrase("H:leastone")
		unless( $self->{allow_blank} || $onedefined );

	my $anyall = $self->{session}->{render}->param( "_satisfyall" );

	if( defined $anyall )
	{
		$self->{satisfy_all} = ( $anyall eq "ALL" );
	}
	
	$self->{order} = $self->{session}->{render}->param( "_order" );
	
	return( scalar @problems > 0 ? \@problems : undef );
}



######################################################################
#
# $text_rep = to_string()
#
#  Return a text representation of the search expression, for persistent
#  storage. Doesn't store table or the order by fields, just the field
#  names, values, default order and satisfy_all.
#
######################################################################

sub to_string
{
	my( $self ) = @_;

	# Start with satisfy all
	my $text_rep = "\[".( defined $self->{satisfy_all} &&
	                      $self->{satisfy_all}==0 ? "ANY" : "ALL" )."\]";

	# default order
	$text_rep .= "\[";
	$text_rep .= _escape_search_string( $self->{order} ) if( defined $self->{order} );
	$text_rep .= "\]";
	
	foreach (@{$self->{searchfields}})
	{
		$text_rep .= "\["._escape_search_string( $_->{formname} )."\]\[".
			( defined $_->{value} ? _escape_search_string( $_->{value} ) : "" )."\]";
	}
	
#EPrints::Log::debug( "SearchExpression", "Text rep is >>>$text_rep<<<" );

	return( $text_rep );
}

sub _escape_search_string
{
	my( $string ) = @_;
	$string =~ s/[\\\[]/\\$&/g; 
	return $string;
}

sub _unescape_search_string
{
	my( $string ) = @_;
	$string =~ s/\\(.)/$1/g; 
	return $string;
}

######################################################################
#
# state_from_string( $text_rep )
#
#  reinstate the search expression's values from the given text
#  representation, previously generated by to_string(). Note that the
#  fields used must have been passed into the constructor.
#
######################################################################

sub state_from_string
{
	my( $self, $text_rep ) = @_;
	
EPrints::Log::debug( "SearchExpression", "state_from_string ($text_rep)" );

	# Split everything up

	my @elements = ();
	while( $text_rep =~ s/\[((\\\[|[^\]])*)\]//i )
	{
		push @elements, _unescape_search_string( $1 );
		print STDERR "el ($1)\n";
	}
	
	my $satisfyall = shift @elements;

	# Satisfy all?
	$self->{satisfy_all} = ( defined $satisfyall && $satisfyall eq "ANY" ? 0
	                                                                     : 1 );
	
	# Get the order
	my $order = shift @elements;
	$self->{order} = $order if( defined $order && $order ne "" );

	# Get the field values
	while( $#elements > 0 )
	{
		my $formname = shift @elements;
		my $value = shift @elements;
	
		my $sf = $self->{searchfieldmap}->{$formname};
#EPrints::Log::debug( "SearchExpression", "Eep! $formname not in searchmap!" )
#	if( !defined $sf );
		$sf->set_value( $value ) if( defined $sf && defined $value && $value ne "" );
	}

#EPrints::Log::debug( "SearchExpression", "new text rep: (".$self->to_string().")" );
}



######################################################################
#
# @metafields = make_meta_fields( $what, $fieldnames )
#
#  A static method, that finds MetaField objects for the given named
#  metafields. You can pass @metafields to the SearchForm and 
#  SearchExpression constructors.
#
#  $what must be "eprints" or "users", depending on what metafields
#  you want.
#
#  If a field name is given as e.g. "title/keywords/abstract", they'll
#  be put in an array ref in the returned array. When @metafields is
#  passed into the SearchForm constructor, a SearchField that will search
#  the title, keywords and abstracts fields together will be created.
#
######################################################################

sub make_meta_fields
{
	my( $what, $fieldnames ) = @_;

	my @metafields;

	# We want to search the relevant MetaFields
	my @all_fields;

	@all_fields = EPrints::MetaInfo::get_fields( $what );

	foreach (@$fieldnames)
	{
		# If the fieldname contains a /, it's a "search >1 at once" entry
		if( /\// )
		{
			# Split up the fieldnames
			my @multiple_names = split /\//, $_;
			my @multiple_fields;
			
			# Put the MetaFields in a list
			foreach (@multiple_names)
			{
				push @multiple_fields, EPrints::MetaInfo::find_field( \@all_fields,
				                                                      $_ );
			}
			
			# Add a reference to the list
			push @metafields, \@multiple_fields;
		}
		else
		{
			# Single field
			push @metafields, EPrints::MetaInfo::find_field( \@all_fields,
			                                                  $_ );
		}
	}
	
	return( @metafields );
}


sub perform_search 
{
	my ( $self ) = @_;

	my @searchon = ();
	foreach( @{$self->{searchfields}} )
	{
		if ( defined $_->{value} )
		{
			push @searchon , $_;
		}
	}
	@searchon = sort { return $a->approx_rows() <=> $b->approx_rows() } 
		         @searchon;

#EPrints::Log::debug("optimised order:");

	my $buffer = undef;
	$self->{ignoredwords} = [];
	my $badwords;
	foreach( @searchon )
	{
		EPrints::Log::debug($_->{field}->{name}."--".$_->{value});
		my $error;
		( $buffer , $badwords , $error) = 
			$_->do($buffer , $self->{satisfy_all} );

		if( defined $error )
		{
			$self->{tmptable} = undef;
			$self->{error} = $error;
			return;
		}
		if( defined $badwords )
		{
			push @{$self->{ignoredwords}},@{$badwords};
		}
	}
	
        my @fields = EPrints::MetaInfo::get_fields( $self->{table} );
        my $keyfield = $fields[0];
	$self->{error} = undef;
	$self->{tmptable} = $buffer;

}
	
sub count 
{
	my ( $self ) = @_;

	if ( $self->{tmptable} )
	{
		return $self->{session}->{database}->count_buffer( 
			$self->{tmptable} );
	}	

	EPrints::Log::log_entry(
		EPrints::Language::logphrase( "L:not_cached" ) );
		
}


sub get_records 
{
	my ( $self , $max ) = @_;
	
	if ( $self->{tmptable} )
	{
        	my @fields = EPrints::MetaInfo::get_fields( $self->{table} );
        	my $keyfield = $fields[0];

		my ( $buffer, $overlimit ) = $self->{session}->{database}->distinct_and_limit( 
							$self->{tmptable}, 
							$keyfield, 
							$max );

		my @records = $self->{session}->{database}->from_buffer( $self->{table}, $buffer );
		if( !$overlimit )
		{
			@records = sort 
				{ &{$self->{order_func}->{$self->{order}}}($a,$b); }
				@records;
		}
		return @records;
	}	

	EPrints::Log::log_entry(
		EPrints::Language::logphrase( "L:not_cached" ) );
		
}

1;
