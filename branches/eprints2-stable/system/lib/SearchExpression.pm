######################################################################
#
# EPrints::SearchExpression
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

B<EPrints::SearchExpression> - undocumented

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
#  Search Expression
#
#   Represents a whole set of search fields.
#
######################################################################
#
#  __LICENSE__
#
######################################################################

package EPrints::SearchExpression;

use EPrints::SearchField;
use EPrints::SearchCondition;
use EPrints::Session;
use EPrints::Database;
use EPrints::Plugins;
use EPrints::Language;

use URI::Escape;

use strict;
# order method not presercved.

$EPrints::SearchExpression::CustomOrder = "_CUSTOM_";


#cjg non user defined sort methods => pass comparator method my reference
# eg. for later_in_thread


######################################################################
=pod

=item $thing = EPrints::SearchExpression->new( %data )

undocumented

=cut
######################################################################

@EPrints::SearchExpression::OPTS = (
	"dataset", 	"allow_blank", 	"satisfy_all", 	
	"fieldnames", 	"staff", 	"order", 	"custom_order",
	"keep_cache", 	"cache_id", 	"prefix", 	"defaults",
	"citation", 	"page_size", 	"filters", 	"default_order",
	"preamble_phrase", 		"title_phrase", "search_fields" );

sub new
{
	my( $class, %data ) = @_;
	
	my $self = {};
	bless $self, $class;
	# only table is required.
	# setup defaults for the others:
	$data{allow_blank} = 0 if ( !defined $data{allow_blank} );
	$data{satisfy_all} = 1 if ( !defined $data{satisfy_all} );
	$data{fieldnames} = [] if ( !defined $data{fieldnames} );
	$data{prefix} = "" if ( !defined $data{prefix} );

	if( 
		defined $data{use_cache} || 
		defined $data{use_oneshot_cache} || 
		defined $data{use_private_cache} )
	{
		print STDERR <<END;
-------------------------------------------------------------
EPRINTS WARNING: The old cache parameters to SearchExpression have been
deprecated. Everything will probably work as expected, but you should maybe
check your scripts. (if it's in the core code, please email 
support\@eprints.org

Deprecated: use_oneshot_cache use_private_cache use_cache

Please use instead: keep_cache

All cache's are now private. oneshot caches will be created and
destroyed automatically if "order" or "custom_order" is set or 
if a range of results is requested.
-------------------------------------------------------------
END
	}

	foreach( @EPrints::SearchExpression::OPTS )
	{
		$self->{$_} = $data{$_};
	}

	if( defined $data{dataset_id} )
	{
		$self->{dataset} = &ARCHIVE->get_dataset( $data{dataset_id} );
	}

	if( defined $self->{custom_order} ) 
	{ 
		$self->{order} = $EPrints::SearchExpression::CustomOrder;
		# can't cache a search with a custom ordering.
	}

	if( !defined $self->{defaults} ) 
	{ 
		$self->{defaults} = {};
	}

	# no order now means "do not order" rather than "use default order"
#	if( !defined $self->{order} && defined $self->{dataset})
#	{
#		# Get {order} from {dataset} if possible.
#
#		$self->{order} = &ARCHIVE->get_conf( 
#					"default_order", 
#					$self->{dataset}->confid );
#	}
	

	# Arrays for the SearchField objects
	$self->{searchfields} = [];
	$self->{filterfields} = {};
	# Map for MetaField names -> corresponding SearchField objects
	$self->{searchfieldmap} = {};

	$self->{allfields} = [];#kill this snipe.

	# Little hack to solve the problem of not knowing what
	# the fields in the subscription spec are until we load
	# the config.
	if( $self->{fieldnames} eq "subscriptionfields" )
	{
		$self->{fieldnames} = &ARCHIVE->get_conf(
			"subscription_fields" );
	}

	if( $self->{fieldnames} eq "editpermfields" )
	{
		$self->{fieldnames} = &ARCHIVE->get_conf(
			"editor_limit_fields" );
#cjg
	}

	# CONVERT FROM OLD SEARCH CONFIG 
	if( !defined $self->{search_fields} )
	{
		$self->{search_fields} = [];
		foreach my $fieldname (@{$self->{fieldnames}})
		{
			# If the fieldname contains a /, it's a 
			# "search >1 at once" entry
			my $f = {};
				
			if( $fieldname =~ m/^!(.*)$/ )
			{
				# "extra" field - one not in the current 
				# dataset. HACK - do not use!
				$f->{id} = $1;
				$f->{default} = $self->{defaults}->{$1};
				$f->{meta_fields} = $fieldname;
			}
			else
			{
				$f->{default}=$self->{defaults}->{$fieldname};

				# Split up the fieldnames
				my @f = split( /\//, $fieldname );
				$f->{meta_fields} = \@f;
				$f->{id} = join( '/', sort @f );

			}
			push @{$self->{search_fields}}, $f;
		}
	}

	if( !defined $self->{"default_order"} )
	{
		$self->{"default_order"} = 
			&ARCHIVE->get_conf( "default_order", "eprint" );
	}

	if( !defined $self->{"page_size"} )
	{
		$self->{"page_size"} = 
			&ARCHIVE->get_conf( "results_page_size" );
	}

	foreach my $fielddata (@{$self->{search_fields}})
	{
		my @meta_fields;
		foreach my $fieldname ( @{$fielddata->{meta_fields}} )
		{
			# Put the MetaFields in a list
			push @meta_fields, 
	EPrints::Utils::field_from_config_string( $self->{dataset}, $fieldname );
		}

		my $id =  $fielddata->{id};
		if( !defined $id )
		{
			$id = join( 
				"/", 
				@{$fielddata->{meta_fields}} );
		}

		# Add a reference to the list
		my $sf = $self->add_field( 
			\@meta_fields, 
			$fielddata->{default},
			undef,
			undef,
			$fielddata->{id},
			0 );
	}

	foreach my $filterdata (@{$self->{filters}})
	{
		my @meta_fields;
		foreach my $fieldname ( @{$filterdata->{meta_fields}} )
		{
			# Put the MetaFields in a list
			push @meta_fields, 
	EPrints::Utils::field_from_config_string( $self->{dataset}, $fieldname );
		}
	
		# Add a reference to the list
		$self->add_field(
			\@meta_fields, 
			$filterdata->{value},
			$filterdata->{match},
			$filterdata->{merge},
			$filterdata->{id},
			1 );
	}

	if( defined $self->{cache_id} )
	{
		unless( $self->from_cache( $self->{cache_id} ) )
		{
			return; #cache gone 
		}
	}
	
	return( $self );
}


######################################################################
=pod

=item $ok = $thing->from_cache( $id )

undocumented

=cut
######################################################################

sub from_cache
{
	my( $self, $id ) = @_;

	my $string = &DATABASE->cache_exp( $id );

	return( 0 ) if( !defined $string );
	$self->from_string( $string );
	$self->{keep_cache} = 1;
	$self->{cache_id} = $id;
	return( 1 );
}


######################################################################
=pod

=item $foo = $thing->add_field( $metafields, $value, $match, $merge, $id, $filter )

Adds a new search field for the MetaField $field, or list of fields
if $metafields is an array ref, with default $value. If a search field
already exist, the value of that field is replaced with $value.


=cut
######################################################################

sub add_field
{
	my( $self, $metafields, $value, $match, $merge, $id, $filter ) = @_;

	# metafields may be a field OR a ref to an array of fields

	# Create a new searchfield
	my $searchfield = EPrints::SearchField->new( 
					$self->{dataset},
					$metafields,
					$value,
					$match,
					$merge,
					$self->{prefix},
					$id );

	my $sf_id = $searchfield->get_id();
	unless( defined $self->{searchfieldmap}->{$sf_id} )
	{
		push @{$self->{searchfields}}, $sf_id;
	}
	# Put it in the name -> searchfield map
	# (possibly replacing an old one)
	$self->{searchfieldmap}->{$sf_id} = $searchfield;

	if( $filter )
	{
		$self->{filtersmap}->{$sf_id} = $searchfield;
	}

	return $searchfield;
}



######################################################################
=pod

=item $foo = $thing->get_searchfield( $sf_id )

undocumented

=cut
######################################################################

sub get_searchfield
{
	my( $self, $sf_id ) = @_;

	return $self->{searchfieldmap}->{$sf_id};
}

######################################################################
#
# clear()
#
#  Clear the search values of all search fields in the expression.
#
######################################################################


######################################################################
=pod

=item $foo = $thing->clear

undocumented

=cut
######################################################################

sub clear
{
	my( $self ) = @_;
	
	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		$sf->clear;
	}
	
	$self->{satisfy_all} = 1;
}



######################################################################
=pod

=item $xhtml = $thing->render_search_fields( [$help] )

Renders the search fields for this search expression for inclusion
in a form. If $help is true then this also renders the help for
each search field.

Skips filter fields.

=cut
######################################################################

sub render_search_fields
{
	my( $self, $help ) = @_;

	my $frag = &SESSION->make_doc_fragment;

	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		my $div = &SESSION->make_element( 
				"div" , 
				class => "searchfieldname" );
		$div->appendChild( $sf->render_name );
		$frag->appendChild( $div );
		if( $help )
		{
			$div = &SESSION->make_element( 
				"div" , 
				class => "searchfieldhelp" );
			$div->appendChild( $sf->render_help );
			$frag->appendChild( $div );
		}

		$div = &SESSION->make_element( 
			"div" , 
			class => "searchfieldinput" );
		$frag->appendChild( $sf->render() );
	}

	return $frag;
}


######################################################################
=pod

=item $foo = $thing->render_search_form( $help, $show_anyall )

undocumented

=cut
######################################################################

sub render_search_form
{
	my( $self, $help, $show_anyall ) = @_;

	my $form = &SESSION->render_form( "get" );
	$form->appendChild( $self->render_search_fields( $help ) );

	my $div;
	my $menu;

	if( $show_anyall )
	{
		$menu = &SESSION->render_option_list(
			name=>$self->{prefix}."_satisfyall",
			values=>[ "ALL", "ANY" ],
			default=>( defined $self->{satisfy_all} && $self->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			labels=>{ "ALL" => &SESSION->phrase( 
						"lib/searchexpression:all" ),
				  "ANY" => &SESSION->phrase( 
						"lib/searchexpression:any" )} );

		my $div = &SESSION->make_element( 
			"div" , 
			class => "searchanyall" );
		$div->appendChild( 
			&SESSION->html_phrase( 
				"lib/searchexpression:must_fulfill",  
				anyall=>$menu ) );
		$form->appendChild( $div );	
	}

	$form->appendChild( $self->render_order_menu );

	$div = &SESSION->make_element( 
		"div" , 
		class => "searchbuttons" );
	$div->appendChild( &SESSION->render_action_buttons( 
		_order => [ "search", "newsearch" ],
		newsearch => &SESSION->phrase( "lib/searchexpression:action_reset" ),
		search => &SESSION->phrase( "lib/searchexpression:action_search" ) )
 	);
	$form->appendChild( $div );	

	return( $form );
}


######################################################################
=pod

=item $foo = $thing->render_order_menu

undocumented

=cut
######################################################################

sub render_order_menu
{
	my( $self ) = @_;

	my $order = $self->{order};

	if( !defined $order )
	{
		$order = $self->{default_order};
	}


	my @tags = keys %{&ARCHIVE->get_conf(
			"order_methods",
			$self->{dataset}->confid )};

	my $menu = &SESSION->render_option_list(
		name=>$self->{prefix}."_order",
		values=>\@tags,
		default=>$order,
		labels=>&SESSION->get_order_names( $self->{dataset} ) );
	my $div = &SESSION->make_element( "div" , class => "searchorder" );
	$div->appendChild( 
		&SESSION->html_phrase( 
			"lib/searchexpression:order_results", 
			ordermenu => $menu  ) );

	return $div;
}



######################################################################
=pod

=item $foo = $thing->get_order

undocumented

=cut
######################################################################

sub get_order
{
	my( $self ) = @_;
	return $self->{order};
}


######################################################################
=pod

=item $foo = $thing->get_satisfy_all

undocumented

=cut
######################################################################

sub get_satisfy_all
{
	my( $self ) = @_;
	return $self->{satisfy_all};
}


######################################################################
=pod

=item $foo = $thing->from_form

undocumented

=cut
######################################################################

sub from_form
{
	my( $self ) = @_;

	my $id = &SESSION->param( "_cache" );
	if( defined $id )
	{
		return if( $self->from_cache( $id ) );
		# cache expired...
	}

	my $exp = &SESSION->param( "_exp" );
	if( defined $exp )
	{
		$self->from_string( $exp );
		return;
		# cache expired...
	}

	my @problems;
	foreach my $sf ( $self->get_non_filter_searchfields )
	{
                next if( $self->{filtersmap}->{$sf->get_id} );
		my $prob = $sf->from_form();
		push @problems, $prob if( defined $prob );
	}
	my $anyall = &SESSION->param( $self->{prefix}."_satisfyall" );

	if( defined $anyall )
	{
		$self->{satisfy_all} = ( $anyall eq "ALL" );
	}
	
	$self->{order} = &SESSION->param( $self->{prefix}."_order" );

	if( $self->is_blank && ! $self->{allow_blank} )
	{
		push @problems, &SESSION->phrase( 
			"lib/searchexpression:least_one" );
	}
	
	return( scalar @problems > 0 ? \@problems : undef );
}


######################################################################
=pod

=item $boolean = $searchexp->is_blank

Return true is this searchexpression has no conditions set, otherwise
true.

If any field is set to "exact" then it can never count as unset.

=cut
######################################################################

sub is_blank
{
	my( $self ) = @_;

	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		next unless( $sf->is_set );
		return( 0 ) ;
	}

	return( 1 );
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


######################################################################
=pod

=item $foo = $thing->serialise

undocumented

=cut
######################################################################

sub serialise
{
	my( $self ) = @_;

	# nb. We don't serialise 'staff mode' as that does not affect the
	# results of a search, only how it is represented.

	my @parts;
	push @parts, $self->{allow_blank}?1:0;
	push @parts, $self->{satisfy_all}?1:0;
	push @parts, $self->{order};
	push @parts, $self->{dataset}->id();
	# This inserts an "-" field which we use to spot the join between
	# the properties and the fields, so in a pinch we can add a new 
	# property in a later version without breaking when we upgrade.
	push @parts, "-";
	my $search_field;
	foreach my $sf_id (sort @{$self->{searchfields}})
	{
		my $search_field = $self->get_searchfield( $sf_id );
		my $fieldstring = $search_field->serialise();
		next unless( defined $fieldstring );
		push @parts, $fieldstring;
	}
	my @escapedparts;
	foreach( @parts )
	{
		# clone the string, so we can escape it without screwing
		# up the origional.
		my $bit = $_;
		$bit="" unless defined( $bit );
		$bit =~ s/[\\\|]/\\$&/g; 
		push @escapedparts,$bit;
	}
	return join( "|" , @escapedparts );
}	

######################################################################
=pod

=item $searchexp->from_string( $string )

Unserialises the contents of $string but only into the fields alrdeady
existing in $searchexp. Set the order and satisfy_all mode but do not 
affect the dataset or allow blank.

=cut
######################################################################

sub from_string
{
	my( $self, $string ) = @_;

	return unless( EPrints::Utils::is_set( $string ) );

	my( $pstring , $fstring ) = split /\|-\|/ , $string ;
	$fstring = "" unless( defined $fstring ); # avoid a warning

	my @parts = split( /\|/ , $pstring );
	$self->{satisfy_all} = $parts[1]; 
	$self->{order} = $parts[2];
# not overriding these bits
#	$self->{allow_blank} = $parts[0];
#	$self->{dataset} = &ARCHIVE->get_dataset( $parts[3] ); 

	my $sf_data = {};
	foreach( split /\|/ , $fstring )
	{
		my $data = EPrints::SearchField->unserialise( $_ );
		$sf_data->{$data->{"id"}} = $data;	
	}

	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		my $data = $sf_data->{$sf->get_id};
		$self->add_field( 
			$sf->get_fields(), 
			$data->{"value"},
			$data->{"match"},
			$data->{"merge"},
			$sf->get_id() );
	}
}



######################################################################
=pod

=item $newsearchexp = $thing->clone

undocumented

=cut
######################################################################

sub clone
{
	my( $self ) = @_;

	my $clone = EPrints::SearchExpression->new( %{$self} );
	
	foreach my $sf_id ( keys %{$self->{searchfieldmap}} )
	{
		my $sf = $self->{searchfieldmap}->{$sf_id};
		$clone->add_field(
			$sf->get_fields,
			$sf->get_value,
			$sf->get_match,
			$sf->get_merge,
			$sf->get_id );
	}

	return $clone;
}




######################################################################
=pod

=item $conditions = $thing->get_conditons

undocumented

=cut
######################################################################

sub get_conditions
{
	my( $self ) = @_;

	my $any_field_set = 0;
	my @r = ();
	foreach my $sf ( $self->get_searchfields )
	{
		next unless( $sf->is_set() );
		$any_field_set = 1;

		push @r, $sf->get_conditions;
	}

	my $cond;
	if( $any_field_set )
	{
		if( $self->{satisfy_all} )
		{
			$cond = EPrints::SearchCondition->new( "AND", @r );
		}
		else
		{
			$cond = EPrints::SearchCondition->new( "OR", @r );
		}
	}
	else
	{
		if( $self->{allow_blank} )
		{
			$cond = EPrints::SearchCondition->new( "TRUE" );
		}
		else
		{
			$cond = EPrints::SearchCondition->new( "FALSE" );
		}
	}
		
	$cond->optimise;

	return $cond;
}


######################################################################
=pod

=item $foo = $thing->process_webpage()

undocumented

=cut
######################################################################

sub process_webpage
{
	my( $self ) = @_;

	if( $self->{staff} && !&SESSION->auth_check( "staff-view" ) )
	{
		&SESSION->terminate;
		exit( 0 );
	}

	my $pagesize = $self->{page_size};

	my $preamble;
	if( defined $self->{"preamble_phrase"} )
	{
		$preamble = &SESSION->html_phrase( $self->{"preamble_phrase"} );
	}
	else
	{
		$preamble = &SESSION->make_doc_fragment;
	}

	my $title = &SESSION->html_phrase( $self->{"title_phrase"} );

	my $action_button = &SESSION->get_action_button();

	# Check if we need to do a search. We do if:
	#  a) if the Search button was pressed.
	#  b) if there are search parameters but we have no value for "submit"
	#     (i.e. the search is a direct GET from somewhere else)

	if( ( defined $action_button && $action_button eq "search" ) 
            || 
	    ( !defined $action_button && &SESSION->have_parameters() ) )
	{
		# We need to do a search
		my $problems = $self->from_form;
		
		if( defined $problems && scalar( @$problems ) > 0 )
		{
			$self->_render_problems( 
					$title, 
					$preamble, 
					@$problems );
			return;
		}

		# Everything OK with form.
			

		my( $t1 , $t2 , $t3 , @results );

		$t1 = EPrints::Session::microtime();

		$self->perform_search();

		$t2 = EPrints::Session::microtime();

		if( defined $self->{error} ) 
		{	
			# Error with search.
			$self->_render_problems( 
					$title, 
					$preamble, 
					$self->{error} );
			return;
		}

		my $n_results = $self->count();

		my $offset = &SESSION->param( "_offset" ) + 0;

		@results = $self->get_records( $offset , $pagesize );
		$t3 = EPrints::Session::microtime();
		$self->dispose();

		my $plast = $offset + $pagesize;
		$plast = $n_results if $n_results< $plast;

		my %bits = ();
		
		if( scalar $n_results > 0 )
		{
			$bits{matches} = 
				&SESSION->html_phrase( 
					"lib/searchexpression:results",
					from => &SESSION->make_text($offset+1),
					to => &SESSION->make_text( $plast ),
					n => &SESSION->make_text( $n_results )  
				);
		}
		else
		{
			$bits{matches} = 
				&SESSION->html_phrase( 
					"lib/searchexpression:noresults" );
		}

		$bits{time} = &SESSION->html_phrase( 
			"lib/searchexpression:search_time", 
			searchtime => &SESSION->make_text($t3-$t1) );
		my $index = new EPrints::Index( $self->{dataset} );

		$bits{last_index} = &SESSION->html_phrase( 
			"lib/searchexpression:last_index", 
			index_datestamp => &SESSION->make_text( 
						$index->get_last_timestamp ) );

		$bits{searchdesc} = $self->render_description;

		my $links = &SESSION->make_doc_fragment();
		$bits{controls} = &SESSION->make_element( "p", class=>"searchcontrols" );
		my $url = &SESSION->get_uri();
		#cjg escape URL'ify urls in this bit... (4 of them?)
		my $escexp = $self->serialise();	
		$escexp =~ s/ /+/g; # not great way...
		my $a;
		if( $offset > 0 ) 
		{
			my $bk = $offset-$pagesize;
			my $fullurl = "$url?_cache=".$self->{cache_id}."&_exp=$escexp&_offset=".($bk<0?0:$bk);
			$a = &SESSION->render_link( $fullurl );
			my $pn = $pagesize>$offset?$offset:$pagesize;
			$a->appendChild( 
				&SESSION->html_phrase( 
					"lib/searchexpression:prev",
					n=>&SESSION->make_text( $pn ) ) );
			$bits{controls}->appendChild( $a );
			$bits{controls}->appendChild( &SESSION->html_phrase( "lib/searchexpression:seperator" ) );
			$links->appendChild( &SESSION->make_element( "link",
							rel=>"Prev",
							href=>EPrints::Utils::url_escape( $fullurl ) ) );
		}

		$a = &SESSION->render_link( "$url?_cache=".$self->{cache_id}."&_exp=$escexp&_action_update=1" );
		$a->appendChild( &SESSION->html_phrase( "lib/searchexpression:refine" ) );
		$bits{controls}->appendChild( $a );
		$bits{controls}->appendChild( &SESSION->html_phrase( "lib/searchexpression:seperator" ) );

		$a = &SESSION->render_link( $url );
		$a->appendChild( &SESSION->html_phrase( "lib/searchexpression:new" ) );
		$bits{controls}->appendChild( $a );

		if( $offset + $pagesize < $n_results )
		{
			my $fullurl="$url?_cache=".$self->{cache_id}."&_exp=$escexp&_offset=".($offset+$pagesize);
			$a = &SESSION->render_link( $fullurl );
			my $nn = $n_results - $offset - $pagesize;
			$nn = $pagesize if( $pagesize < $nn);
			$a->appendChild( &SESSION->html_phrase( "lib/searchexpression:next",
						n=>&SESSION->make_text( $nn ) ) );
			$bits{controls}->appendChild( &SESSION->html_phrase( "lib/searchexpression:seperator" ) );
			$bits{controls}->appendChild( $a );
			$links->appendChild( &SESSION->make_element( "link",
							rel=>"Next",
							href=>EPrints::Utils::url_escape( $fullurl ) ) );
		}

		$bits{results} = &SESSION->make_doc_fragment;
		foreach my $result ( @results )
		{
			my $p = &SESSION->make_element( "p" );
			$p->appendChild( 
				$result->render_citation_link( 
					$self->{citation},  #undef unless specified
					$self->{staff} ) );
			$bits{results}->appendChild( $p );
		}
		

		if( $n_results > 0 )
		{
			# Only print a second set of controls if 
			# there are matches.
			$bits{controls_if_matches} = 
				EPrints::XML::clone_node( $bits{controls}, 1 );
		}
		else
		{
			$bits{controls_if_matches} = 
				&SESSION->make_doc_fragment;
		}

		my $page = &SESSION->html_phrase(
			"lib/searchexpression:results_page",
			%bits );
	
		&SESSION->build_page( 
			&SESSION->html_phrase( 
					"lib/searchexpression:results_for", 
					title => $title ),
			$page,
			"search_results",
			$links );
		&SESSION->send_page();
		return;
	}

	if( defined $action_button && $action_button eq "newsearch" )
	{
		# To reset the form, just reset the URL.
		my $url = &SESSION->get_uri();
		# Remove everything that's part of the query string.
		$url =~ s/\?.*//;
		&SESSION->redirect( $url );
		return;
	}
	
	if( defined $action_button && $action_button eq "update" )
	{
		$self->from_form();
	}

	# Just print the form...

	my $page = &SESSION->make_doc_fragment();
	$page->appendChild( $preamble );
	$page->appendChild( $self->render_search_form( 1 , 1 ) );

	&SESSION->build_page( $title, $page, "search_form" );
	&SESSION->send_page();
}

######################################################################
# 
# $foo = $thing->_render_problems( $title, $preamble, @problems )
#
# undocumented
#
######################################################################

sub _render_problems
{
	my( $self , $title, $preamble, @problems ) = @_;	
	# Problem with search expression. Report an error, and redraw the form
		
	my $page = &SESSION->make_doc_fragment();
	$page->appendChild( $preamble );

	my $problem_box = &SESSION->make_element( 
				"div",
				class=>"problems" );
	$problem_box->appendChild( &SESSION->html_phrase( "lib/searchexpression:form_problem" ) );

	# List the problem(s)
	my $ul = &SESSION->make_element( "ul" );
	$page->appendChild( $ul );
	my $problem;
	foreach $problem (@problems)
	{
		my $li = &SESSION->make_element( 
			"li",
			class=>"problem" );
		$ul->appendChild( $li );
		$li->appendChild( &SESSION->make_text( $problem ) );
	}
	$problem_box->appendChild( $ul );
	$page->appendChild( $problem_box );
	$page->appendChild( $self->render_search_form( 1 , 1 ) );
			
	&SESSION->build_page( $title, $page, "search_problems" );
	&SESSION->send_page();
}


######################################################################
=pod

=item $foo = $thing->get_dataset

undocumented

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}


######################################################################
=pod

=item $foo = $thing->set_dataset( $dataset )

undocumented

=cut
######################################################################

sub set_dataset
{
	my( $self, $dataset ) = @_;

	# Any cache is now meaningless...
	$self->dispose; # clean up cache if it's not shared.
	delete $self->{cache_id}; # forget about it even if it is shared.

	$self->{dataset} = $dataset;
	foreach my $sf ( $self->get_searchfields )
	{
		$sf->set_dataset( $dataset );
	}
}


######################################################################
=pod

=item $xhtml = $thing->render_description

Return an XHTML DOM description of this search expressions current
parameters.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $frag = &SESSION->make_doc_fragment;

	my @bits = ();
	foreach my $sf ( $self->get_searchfields )
	{
		next unless( $sf->is_set );
		push @bits, $sf->render_description;
	}

	my $joinphraseid = "lib/searchexpression:desc_or";
	if( $self->{satisfy_all} )
	{
		$joinphraseid = "lib/searchexpression:desc_and";
	}

	for( my $i=0; $i<scalar @bits; ++$i )
	{
		if( $i>0 )
		{
			$frag->appendChild( &SESSION->html_phrase( 
				$joinphraseid ) );
		}
		$frag->appendChild( $bits[$i] );
	}

	if( scalar @bits > 0 )
	{
		$frag->appendChild( &SESSION->make_text( "." ) );
	}
	else
	{
		$frag->appendChild( &SESSION->html_phrase(
			"lib/searchexpression:desc_no_conditions" ) );
	}

	if( EPrints::Utils::is_set( $self->{order} ) &&
		$self->{"order"} ne $EPrints::SearchExpression::CustomOrder )
	{
		$frag->appendChild( &SESSION->make_text( " " ) );
		$frag->appendChild( &SESSION->html_phrase(
			"lib/searchexpression:desc_order",
			order => &SESSION->make_text(
				&SESSION->get_order_name(
					$self->{dataset},
					$self->{order} ) ) ) );
	} 

	return $frag;
}
	

######################################################################
=pod

=item $thing->set_property( $property, $value );

undocumented

=cut
######################################################################

sub set_property
{
	my( $self, $property, $value ) = @_;

	$self->{$property} = $value;
}



######################################################################
=pod

=item @search_fields = $self->get_searchfields()

undocumented

=cut
######################################################################

sub get_searchfields
{
	my( $self ) = @_;

	my @search_fields = ();
	foreach my $id ( @{$self->{searchfields}} ) 
	{ 
		push @search_fields, $self->get_searchfield( $id ); 
	}
	
	return @search_fields;
}

######################################################################
=pod

=item @search_fields = $self->get_non_filter_searchfields();

undocumented

=cut
######################################################################

sub get_non_filter_searchfields
{
	my( $self ) = @_;

	my @search_fields = ();
	foreach my $id ( @{$self->{searchfields};} ) 
	{ 
                next if( $self->{filtersmap}->{$id} );
		push @search_fields, $self->get_searchfield( $id ); 
	}
	
	return @search_fields;
}





######################################################################
=pod

=item @set_search_fields = $self->get_set_searchfields

undocumented

=cut
######################################################################

sub get_set_searchfields
{
	my( $self ) = @_;

	my @set_fields = ();
	foreach my $sf ( $self->get_searchfields )
	{
		next unless( $sf->is_set() );
		push @set_fields , $sf;
	}
	return @set_fields;
}











 ######################################################################
 ##
 ##
 ##  SEARCH THE DATABASE AND CACHE CODE
 ##
 ##
 ######################################################################


#
# Search related instance variables
#   {cache_id}  - the ID of the table the results are cached & 
#			ordered in.
#
#   {unsorted_matches} - a reference to an array of id's.
#		          undefined if search has not been performed
#			  can be ["ALL"] to indicate all items in
#			  dataset.





######################################################################
=pod

=item $foo = $thing->get_cache_id

undocumented

=cut
######################################################################

sub get_cache_id
{
	my( $self ) = @_;
	
	return $self->{cache_id};
}

######################################################################
=pod

=item $thing->perform_search

undocumented

=cut
######################################################################

sub perform_search
{
	my( $self ) = @_;
	$self->{error} = undef;

	# cjg hmmm check cache still exists?
	if( defined $self->{cache_id} )
	{
		return;
	}

	#print STDERR $self->get_conditions->describe."\n\n";

	$self->{unsorted_matches} = $self->get_conditions->process;

	if( $self->{keep_cache} )
	{
		$self->cache_results;
	}
}

######################################################################
=pod

=item $thing->cache_search

undocumented

=cut
######################################################################

sub cache_results
{
	my( $self ) = @_;

	return if( defined $self->{cache_id} );

	if( !defined $self->{unsorted_matches} )
	{
		&ARCHIVE->log( "\$searchexp->cache_search() : Search has not been performed" );
		return;
	}

	if( $self->_matches_none && !$self->{keep_cache} )
	{
		# not worth caching zero in a temp table!
		return;
	}

	my $srctable;
	if( $self->_matches_all )
	{
		$srctable = $self->{dataset}->get_sql_table_name;
	}
	else
	{
		$srctable = &DATABASE->make_buffer(
			$self->{dataset}->get_key_field()->get_name,
			$self->{unsorted_matches} );
	}

	my $order;
	if( defined $self->{order} )
	{
		if( $self->{order} eq $EPrints::SearchExpression::CustomOrder )
		{
			$order = $self->{custom_order};
		}
		else
		{
			$order = &ARCHIVE->get_conf( 
						"order_methods" , 
						$self->{dataset}->confid,
						$self->{order} );
		}
	}

	$self->{cache_id} = &DATABASE->cache( 
		$self->serialise(), 
		$self->{dataset},
		$srctable,
		$order );

	unless( $self->_matches_all )
	{
		&DATABASE->dispose_buffer( $srctable );
	}
		
}



######################################################################
=pod

=item $searchexp->dispose

Clean up cache files is appropriate.

=cut
######################################################################

sub dispose
{
	my( $self ) = @_;

	if( defined $self->{cache_id} && !$self->{keep_cache} )
	{
		&DATABASE->drop_cache( $self->{cache_id} );
		delete $self->{cache_id};
	}
}





######################################################################
#
# Object List Functions
#
######################################################################









######################################################################
=pod

=item $foo = $thing->count 

undocumented

=cut
######################################################################

sub count 
{
	my( $self ) = @_;

	if( defined $self->{unsorted_matches} )
	{
		if( $self->_matches_all )
		{
			return $self->{dataset}->count;
		}
		return( scalar @{$self->{unsorted_matches}} );
	}

	if( defined $self->{cache_id} )
	{
		#cjg Should really have a way to get at the
		# cache. Maybe we should have a table object.
		return &DATABASE->count_table( "cache".$self->{cache_id} );
	}

	#cjg ERROR to user?
	&ARCHIVE->log( "\$searchexp->count() : Search has not been performed" );
}


######################################################################
=pod

=item $foo = $thing->get_records( $offset, $count )

undocumented

=cut
######################################################################

sub get_records
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 0 );
}


######################################################################
=pod

=item $foo = $thing->get_ids( $offset, $count )

Return a reference to an array containing 

=cut
######################################################################

sub get_ids
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 1 );
}


######################################################################
# 
# $foo = $thing->_matches_none
#
# undocumented
#
######################################################################

sub _matches_none
{
	my( $self ) = @_;

	if( !defined $self->{unsorted_matches} )
	{
		print STDERR "Error: Calling _matches_none when unsorted_matches not set\n";
		return 0;
	}

	return( scalar @{$self->{unsorted_matches}} == 0 );
}

######################################################################
# 
# $foo = $thing->_matches_all
#
# undocumented
#
######################################################################

sub _matches_all
{
	my( $self ) = @_;

	if( !defined $self->{unsorted_matches} )
	{
		print STDERR "Error: Calling _matches_all when unsorted_matches not set\n";
		return 0;
	}

	return( 0 ) if( !defined $self->{unsorted_matches}->[0] );

	return( $self->{unsorted_matches}->[0] eq "ALL" );
}

######################################################################
# 
# $foo = $thing->_get_records ( $offset, $count, $justids )
#
# undocumented
#
######################################################################

sub _get_records 
{
	my ( $self , $offset , $count, $justids ) = @_;


	if( defined $self->{unsorted_matches} )
	{
		if( $self->_matches_none )
		{
			if( $justids )
			{
				return [];
			}
			else
			{
				return ();
			}
		}

		if( !defined $offset && !defined $count )
		{
			if( $justids )
			{
				if( $self->_matches_all )
				{
					return $self->{dataset}->get_item_ids; 
				}
				return $self->{unsorted_matches};
			}
	
			if( $self->_matches_all )
			{
				return &DATABASE->get_all( $self->{dataset} );
			}
			
			# we are returning all matches, but there's no
			# easy shortcut.
		}
	}

	if( !defined $self->{cache_id} )
	{
		$self->cache_results;
	}

	my $r = &DATABASE->from_cache( 
			$self->{dataset}, 
			$self->{cache_id},
			$offset,
			$count,	
			$justids );

	return $r if( $justids );
		
	return @{$r};
}


######################################################################
=pod

=item $foo = $thing->map( $function, $info, [$offset], [$count] )

undocumented

=cut
######################################################################

sub map
{
	my( $self, $function, $info, $offset, $count ) = @_;	

	$count = $self->count() unless defined $count;
	$offset = 0 unless defined $offset;

	my $CHUNKSIZE = 100;

	for( my $chunk_offset = $offset; $chunk_offset < $count+$offset; $chunk_offset+=$CHUNKSIZE )
	{
		my $this_chunk = $CHUNKSIZE;
		if( $chunk_offset + $CHUNKSIZE > $count+$offset )
		{
			$this_chunk = $offset+$count - $chunk_offset;
		}
		my @records = $self->get_records( $chunk_offset, $this_chunk );
		foreach my $item ( @records )
		{
			&{$function}( 
				$self->{dataset}, 
				$item, 
				$info );
		}
	}
}


######################################################################
=pod

=item $searchexp->export( $scheme, %opts );

Use a conversion pluging to convert this list to the required
metadata scheme.

=cut
######################################################################

sub export
{
	my( $self, $scheme, %opts ) = @_;

	$opts{'mode'} = 'default' unless defined $opts{'mode'};
	my $dstype = $self->{dataset}->confid;
	$opts{'objs'} = $self;

	return &ARCHIVE->plugin(
		'export/objs.'.$dstype.'/'.$scheme.'/'.$opts{'mode'},
		%opts );
}

	



1;

######################################################################
=pod

=back

=cut

