######################################################################
#
#  Search Expression
#
#   Represents a whole set of search fields.
#
######################################################################
#
#  16/03/2000 - Created by Robert Tansley
#
######################################################################

package EPrints::SearchExpression;

use EPrints::SearchField;
use EPrints::Session;
use EPrints::EPrint;
use EPrints::Database;

use strict;


######################################################################
#
# $exp = new( $session,
#             $table,
#             $satisfyall,
#             $fields,
#             $orderby,
#             $defaultorder )
#
#  Create a new search expression, to search $table for the MetaField's
#  in $fields (an array ref.) Blank SearchExpressions are made for each
#  of these fields.
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
	    $satisfyall,
	    $fields,
	    $orderby,
	    $defaultorder ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{session} = $session;
	$self->{table} = $table;
	$self->{satisfy_all} = $satisfyall;

	# We're going to change the orderby stuff, so that we get
	#   $self->{order_ids}  array of ids
	#   $self->{order_desc} maps ids -> descriptions
	#   $self->{order_sql}  maps ids -> sql
	#   $self->{order}      id of default
	my $idcount = 0;
	$self->{order_ids} = [];
	$self->{order_desc} = {};
	$self->{order_sql} = {};
	
	foreach (sort keys %{$orderby})
	{
		# IDs will be order0, order1, ...
		my $id = "order$idcount";
		$idcount++;
		$self->{order_desc}->{$id} = $_;
#EPrints::Log->debug( "SearchExpression", "Desc: $id -> $_" );
		$self->{order_sql}->{$id} = $orderby->{$_};
		push @{$self->{order_ids}}, $id;
	
		$self->{order} = $id if( $defaultorder eq $_ );
	}

	# Array for the SearchField objects
	$self->{searchfields} = [];
	# Map for MetaField names -> corresponding SearchField objects
	$self->{searchfieldmap} = {};
	
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
	                                            $field,
	                                            $value );

	if( defined $self->{searchfieldmap}->{$searchfield->{formname}} )
	{
		# Already got a seachfield, just update the value
		$self->{searchfieldmap}->{$searchfield->{formname}}->{value} = $value;
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
		delete $_->{value};
	}
	
	$self->{satisfy_all} = 1;
}


######################################################################
#
# $html = render_search_form( $help )
#
#  Render the search form. If $help is 1, then help is written with
#  the search fields.
#
######################################################################

sub render_search_form
{
	my( $self, $help ) = @_;
	
	my %shown_help;

	my $html;

	$html = "<CENTER><P><TABLE BORDER=0>\n";
	
	my $sf;

	foreach $sf (@{$self->{searchfields}})
	{
		if( $help && !defined 
			$shown_help{$EPrints::SearchField::search_help{$sf->{type}}} )
		{
			$html .= "<TR><TD COLSPAN=2 ALIGN=CENTER><EM>";
			$html .= $EPrints::SearchField::search_help{$sf->{type}};
			$html .= "</EM</TD></TR>\n";
			$shown_help{$EPrints::SearchField::search_help{$sf->{type}}} = 1;
		}
		
		$html .= "<TR><TD><STRONG>$sf->{displayname}</STRONG></TD><TD>";
		$html .= $sf->render_html();
		$html .= "</TD></TR>\n";

		$html .= "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n";
	}
	
	$html .= "</TABLE></P></CENTER>\n";

	$html .= "<CENTER><P>Retrived records must fulfill ";
	$html .= $self->{session}->{render}->{query}->popup_menu(
		-name=>"_satisfyall",
		-values=>[ "ALL", "ANY" ],
		-default=>"ALL",
		-labels=>{ "ALL" => "all", "ANY" => "any" } );
	$html .= " of these conditions.</P></CENTER>\n";

	$html .= "<CENTER><P>Order the results: ";

	$html .= $self->{session}->{render}->{query}->popup_menu(
		-name=>"_order",
		-values=>$self->{order_ids},
		-default=>$self->{order},
		-labels=>$self->{order_desc} );
		
	$html .= "</P></CENTER>\n";

	return( $html );
}


######################################################################
#
# @problems = from_form()
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

	push @problems, "You need to specify something for at least one field!"
		unless( $onedefined );

	my $anyall = $self->{session}->{render}->param( "_satisfyall" );
	
	$self->{satisfy_all} = !( defined $anyall && $anyall eq "ANY" );
	$self->{order} = $self->{session}->{render}->param( "_order" );
	
	return( scalar @problems > 0 ? \@problems : undef );
}


######################################################################
#
# @eprints = do_eprint_search()
#
#  Performs the actual search, and returns the results as EPrint objects.
#  If undef is returned, it means that something went wrong during the
#  search. An empty list indicates there were no matches.
#
######################################################################

sub do_eprint_search
{
	my( $self ) = @_;
	
	my( $sql, $order ) = $self->get_sql_order();
	
	return( EPrints::EPrint->retrieve_eprints(
		$self->{session},
		$EPrints::Database::table_archive,
		[ $sql ],
		$order ) );
}


######################################################################
#
# @users = do_user_search()
#
#  Performs an actual search, returing EPrints::User objects.
#  If undef is returned, it means that something went wrong during the
#  search. An empty list indicates there were no matches.
#
######################################################################

sub do_user_search
{
	my( $self ) = @_;
	
	my( $sql, $order ) = $self->get_sql_order();
	
	return( EPrints::User->retrieve_users(
		$self->{session},
		[ $sql ],
		$order ) );
}


######################################################################
#
# ( $sql, $order ) = get_sql_order()
#
#  Returns the SQL for the search ($sql) and the ordering ($order).
#
######################################################################

sub get_sql_order
{
	my( $self ) = @_;

	my $first = 1;
	my $sql = "";

EPrints::Log->debug( "SearchExpression", "Number of search fields: ".scalar( @{$self->{searchfields}} ) );

	# Make the SQL condition
	foreach (@{$self->{searchfields}})
	{
		my $sql_term = $_->get_sql();

		if( defined $sql_term )
		{
			$sql .= ( $self->{satisfy_all} ? " AND " : " OR " ) unless( $first );
			$first = 0 if( $first );
			
			$sql .= "($sql_term)";
		}
	}

	my $order = (defined $self->{order} ?
		[ $self->{order_sql}->{$self->{order}} ] :
		undef );

	return( $sql, $order );
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
	                      $self->{satisfy_all}==0 ? "ALL" : "ANY" )."\]";

	# default order
	$text_rep .= "\[";
	$text_rep .= $self->{order} if( defined $self->{order} );
	$text_rep .= "\]";
	
	foreach (@{$self->{searchfields}})
	{
		$text_rep .= "\[$_->{formname}\]\[$_->{value}\]";
	}
	
#EPrints::Log->debug( "SearchExpression", "Text rep is >>>$text_rep<<<" );

	return( $text_rep );
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
	
	# Split everything up
	my @elements = /(\[[^\]]+\])/, $text_rep;
	
	my $satisfyall = shift @elements;

	# Satisfy all?
	$self->{satisfy_all} = ( defined $satisfyall && $satisfyall eq "ANY" ? 0
	                                                                     : 1);
	
	# Get the order
	my $order = shift @elements;
	$self->{order} = $order if( defined $order && $order ne "" );

	# Get the field values	
	while( $#elements > 0 )
	{
		my $formname = shift @elements;
		my $value = shift @elements;
	
		my $sf = $self->{searchfieldmap}->{$formname};
		
		$sf->{value} = $value if( defined $sf && defined $value && $value ne "" );
	}
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
	my( $class, $what, $fieldnames ) = @_;

	my @metafields;

	# We want to search the relevant MetaFields
	my @all_fields;

	@all_fields = EPrints::MetaInfo->get_all_eprint_fields()
		if( $what eq "eprints" );

	@all_fields = EPrints::MetaInfo->get_user_fields()
		if( $what eq "users" );

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
				push @multiple_fields, EPrints::MetaInfo->find_field( \@all_fields,
				                                                      $_ );
			}
			
			# Add a reference to the list
			push @metafields, \@multiple_fields;
		}
		else
		{
			# Single field
			push @metafields, EPrints::MetaInfo->find_field( \@all_fields,
			                                                  $_ );
		}
	}
	
	return( @metafields );
}

	

1;
