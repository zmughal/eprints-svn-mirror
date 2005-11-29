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

B<EPrints::SearchExpression> - Represents a single search

=head1 DESCRIPTION

The SearchExpression object represents the conditions of a single 
search. 

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

package EPrints::SearchExpression;

use EPrints::SearchField;
use EPrints::SearchCondition;
use EPrints::Session;
use EPrints::EPrint;
use EPrints::Database;
use EPrints::Language;

use URI::Escape;
use strict;

$EPrints::SearchExpression::CustomOrder = "_CUSTOM_";

######################################################################
=pod

=item $thing = EPrints::SearchExpression->new( %data )

undocumented

=cut
######################################################################

@EPrints::SearchExpression::OPTS = (
	"session", 	"dataset", 	"allow_blank", 	"satisfy_all", 	
	"fieldnames", 	"staff", 	"order", 	"custom_order",
	"keep_cache", 	"cache_id", 	"prefix", 	"defaults",
	"citation", 	"page_size", 	"filters", 	"default_order",
	"preamble_phrase", 		"title_phrase", "search_fields",
	"controls" );

sub new
{
	my( $class, %data ) = @_;
	
	my $self = {};
	bless $self, $class;
	# only session & table are required.
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
		my ($package, $filename, $line) = caller;
		print STDERR <<END;
-----------------------------------------------------------------------
EPRINTS WARNING: The old cache parameters to SearchExpression have been
deprecated. Everything will probably work as expected, but you should 
maybe check your scripts. (if it's in the core code, please email 
support\@eprints.org

Deprecated: use_oneshot_cache use_private_cache use_cache

Please use instead: keep_cache

All cache's are now private. oneshot caches will be created and
destroyed automatically if "order" or "custom_order" is set or if a 
range of results is requested.
-----------------------------------------------------------------------
The deprecated parameter was passed to SearchExpression->new from
$filename line $line
-----------------------------------------------------------------------
END

	}

	foreach( @EPrints::SearchExpression::OPTS )
	{
		$self->{$_} = $data{$_};
	}

	if( defined $data{"dataset_id"} )
	{
		$self->{"dataset"} = $self->{"session"}->get_archive->get_dataset( $data{"dataset_id"} );
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
#		$self->{order} = $self->{session}->get_archive->get_conf( 
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
		$self->{fieldnames} = $self->{session}->get_archive->get_conf(
			"subscription_fields" );
	}

	if( $self->{fieldnames} eq "editpermfields" )
	{
		$self->{fieldnames} = $self->{session}->get_archive->get_conf(
			"editor_limit_fields" );
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
			$self->{session}->get_archive->get_conf( 
				"default_order",
				"eprint" );
	}

	if( !defined $self->{"page_size"} )
	{
		$self->{"page_size"} = 
			$self->{session}->get_archive->get_conf( 
				"results_page_size" );
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

	$self->{controls} = {} unless( defined $self->{controls} );
	$self->{controls}->{top} = 0 unless( defined $self->{controls}->{top} );
	$self->{controls}->{bottom} = 1 unless( defined $self->{controls}->{bottom} );

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

	my $string = $self->{session}->get_db()->cache_exp( $id );

	return( 0 ) if( !defined $string );
	$self->from_string( $string );
	$self->{keep_cache} = 1;
	$self->{cache_id} = $id;
	return( 1 );
}


######################################################################
=pod

=item $searchfield = $searchexp->add_field( $metafields, $value, $match, $merge, $id, $filter )

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
					$self->{session},
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

=item $searchfield = $searchexp->get_searchfield( $sf_id )

undocumented

=cut
######################################################################

sub get_searchfield
{
	my( $self, $sf_id ) = @_;

	return $self->{searchfieldmap}->{$sf_id};
}

######################################################################
=pod

=item $searchexp->clear

Clear the search values of all search fields in the expression.

=cut
######################################################################

sub clear
{
	my( $self ) = @_;
	
	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		$sf->clear();
	}
	
	$self->{satisfy_all} = 1;
}



######################################################################
=pod

=item $xhtml = $searchexp->render_search_fields( [$help] )

Renders the search fields for this search expression for inclusion
in a form. If $help is true then this also renders the help for
each search field.

Skips filter fields.

=cut
######################################################################

sub render_search_fields
{
	my( $self, $help ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		my $div = $self->{session}->make_element( 
				"div" , 
				class => "searchfieldname" );
		$div->appendChild( $sf->render_name );
		$frag->appendChild( $div );
		if( $help )
		{
			$div = $self->{session}->make_element( 
				"div" , 
				class => "searchfieldhelp" );
			$div->appendChild( $sf->render_help );
			$frag->appendChild( $div );
		}

		$div = $self->{session}->make_element( 
			"div" , 
			class => "searchfieldinput" );
		$frag->appendChild( $sf->render() );
	}

	return $frag;
}


######################################################################
=pod

=item $xhtml = $searchexp->render_search_form( $help, $show_anyall )

undocumented

=cut
######################################################################

sub render_search_form
{
	my( $self, $help, $show_anyall ) = @_;

	my $form = $self->{session}->render_form( "get" );
	if( $self->{controls}->{top} )
	{
		$form->appendChild( $self->render_controls );
	}
	$form->appendChild( $self->render_search_fields( $help ) );

	my @sfields = $self->get_non_filter_searchfields;
	if( $show_anyall && (scalar @sfields) > 1)
	{
		my $menu = $self->{session}->render_option_list(
			name=>$self->{prefix}."_satisfyall",
			values=>[ "ALL", "ANY" ],
			default=>( defined $self->{satisfy_all} && $self->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			labels=>{ "ALL" => $self->{session}->phrase( 
						"lib/searchexpression:all" ),
				  "ANY" => $self->{session}->phrase( 
						"lib/searchexpression:any" )} );

		my $div = $self->{session}->make_element( 
			"div" , 
			class => "searchanyall" );
		$div->appendChild( 
			$self->{session}->html_phrase( 
				"lib/searchexpression:must_fulfill",  
				anyall=>$menu ) );
		$form->appendChild( $div );	
	}

	$form->appendChild( $self->render_order_menu );

	if( $self->{controls}->{bottom} )
	{
		$form->appendChild( $self->render_controls );
	}

	return( $form );
}

sub render_controls
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( 
		"div" , 
		class => "searchbuttons" );
	$div->appendChild( $self->{session}->render_action_buttons( 
		_order => [ "search", "newsearch" ],
		newsearch => $self->{session}->phrase( "lib/searchexpression:action_reset" ),
		search => $self->{session}->phrase( "lib/searchexpression:action_search" ) )
 	);
	return $div;
}


######################################################################
=pod

=item $xhtml = $searchexp->render_order_menu

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


	my @tags = keys %{$self->{session}->get_archive()->get_conf(
			"order_methods",
			$self->{dataset}->confid )};

	my $menu = $self->{session}->render_option_list(
		name=>$self->{prefix}."_order",
		values=>\@tags,
		default=>$order,
		labels=>$self->{session}->get_order_names( 
						$self->{dataset} ) );
	my $div = $self->{session}->make_element( 
		"div" , 
		class => "searchorder" );
	$div->appendChild( 
		$self->{session}->html_phrase( 
			"lib/searchexpression:order_results", 
			ordermenu => $menu  ) );

	return $div;
}



######################################################################
=pod

=item $order_id = $searchexp->get_order

Return the id string of the type of ordering. This will be a value
in the search configuration.

=cut
######################################################################

sub get_order
{
	my( $self ) = @_;
	return $self->{order};
}


######################################################################
=pod

=item $bool = $searchexp->get_satisfy_all

Return true if this search requires that all the search fields with
values are satisfied. 

=cut
######################################################################

sub get_satisfy_all
{
	my( $self ) = @_;

	return $self->{satisfy_all};
}


######################################################################
=pod

=item @problems = $searchexp->from_form

Populate the conditions of this search based on parameters taken
from the CGI interface.

Return an array containg XHTML descriptions of any problems.

=cut
######################################################################

sub from_form
{
	my( $self ) = @_;

	my $id = $self->{session}->param( "_cache" );
	if( defined $id )
	{
		return if( $self->from_cache( $id ) );
		# cache expired...
	}

	my $exp = $self->{session}->param( "_exp" );
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
	my $anyall = $self->{session}->param( $self->{prefix}."_satisfyall" );

	if( defined $anyall )
	{
		$self->{satisfy_all} = ( $anyall eq "ALL" );
	}
	
	$self->{order} = $self->{session}->param( $self->{prefix}."_order" );

	if( $self->is_blank && ! $self->{allow_blank} )
	{
		push @problems, $self->{session}->phrase( 
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
=pod

=item $string = $searchexp->serialise

Return a text representation of the search expression, for persistent
storage. Doesn't store table or the order by fields, just the field
names, values, default order and satisfy_all.

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
#	$self->{dataset} = $self->{session}->get_archive()->get_dataset( $parts[3] ); 

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

=item $newsearchexp = $searchexp->clone

Return a new search expression which is a duplicate of this one.

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

=item $conditions = $searchexp->get_conditons

Return a tree of EPrints::SearchCondition objects describing the
simple steps required to perform this search.

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

=item $searchexp->process_webpage()

Look at data from the CGI interface and return a webpage. This is
the core of the search UI.

=cut
######################################################################

sub process_webpage
{
	my( $self ) = @_;

	if( $self->{staff} && !$self->{session}->auth_check( "staff-view" ) )
	{
		$self->{session}->terminate();
		exit( 0 );
	}

	my $action_button = $self->{session}->get_action_button();

	# Check if we need to do a search. We do if:
	#  a) if the Search button was pressed.
	#  b) if there are search parameters but we have no value for "submit"
	#     (i.e. the search is a direct GET from somewhere else)

	if( defined $action_button && $action_button eq "search" ) 
	{
		$self->_dopage_results();
		return;
	}

	if( defined $action_button && $action_button eq "export_redir" ) 
	{
		$self->_dopage_export_redir();
		return;
	}

	if( defined $action_button && $action_button eq "export" ) 
	{
		$self->_dopage_export();
		return;
	}

	if( !defined $action_button && $self->{session}->have_parameters() ) 
	{
		# a internal button, probably
		$self->_dopage_results();
		return;
	}

	if( defined $action_button && $action_button eq "newsearch" )
	{
		# To reset the form, just reset the URL.
		my $url = $self->{session}->get_uri();
		# Remove everything that's part of the query string.
		$url =~ s/\?.*//;
		$self->{session}->redirect( $url );
		return;
	}
	
	if( defined $action_button && $action_button eq "update" )
	{
		$self->from_form();
	}

	# Just print the form...

	my $page = $self->{session}->make_doc_fragment();
	$page->appendChild( $self->_render_preamble );
	$page->appendChild( $self->render_search_form( 1 , 1 ) );

	$self->{session}->build_page( $self->_render_title, $page, "search_form" );
	$self->{session}->send_page();
}

######################################################################
# 
# $searchexp->_dopage_export_redir
#
# Redirect to the neat export URL for the requested export format.
#
######################################################################

sub _dopage_export_redir
{
	my( $self ) = @_;

	my $exp = $self->{session}->param( "_exp" );
	my $cacheid = $self->{session}->param( "_cache" );
	my $format = $self->{session}->param( "_output" );
	my $plugin = $self->{session}->plugin( "output/".$format );

	my $url = $self->{session}->get_uri();
	#cjg escape URL'ify urls in this bit... (4 of them?)
	my $escexp = $exp;
	$escexp =~ s/ /+/g; # not great way...
	my $fullurl = "$url/export_".$self->{session}->get_archive->get_id."_".$format.$plugin->param("suffix")."?_exp=$escexp&_output=$format&_action_export=1&_cache=$cacheid";

	$self->{session}->redirect( $fullurl );
}

######################################################################
# 
# $searchexp->_dopage_export
#
# Export the search results using the specified output plugin.
#
######################################################################

sub _dopage_export
{
	my( $self ) = @_;

	my $format = $self->{session}->param( "_output" );

	$self->from_form;
	my $results = $self->perform_search;

	if( !defined $results ) {
		$self->{session}->build_page( 
			$self->{session}->html_phrase( "lib/searchexpression:export_error_title" ),
			$self->{session}->html_phrase( "lib/searchexpression:export_error_search" ),
			"export_error" );
		$self->{session}->send_page;
		return;
	}

	my @plugins = $self->{session}->plugin_list( can_accept=>"list/eprint", is_visible=>"all" );
	my $ok = 0;
	foreach( @plugins ) { if( $_ eq "output/$format" ) { $ok = 1; last; } }
	unless( $ok ) {
		$self->{session}->build_page( 
			$self->{session}->html_phrase( "lib/searchexpression:export_error_title" ),
			$self->{session}->html_phrase( "lib/searchexpression:export_error_format" ),
			"export_error" );
		$self->{session}->send_page;
		return;
	}

	my $plugin = $self->{session}->plugin( "output/$format" );
	$self->{session}->send_http_header( "content_type"=>$plugin->param("mimetype") );
	print $results->export( $format );	
}
	

######################################################################
# 
# $searchexp->_dopage_results
#
# Send the results of this search page
#
######################################################################

sub _dopage_results
{
	my( $self ) = @_;

	# We need to do a search
	my $problems = $self->from_form;
	
	if( defined $problems && scalar( @$problems ) > 0 )
	{
		$self->_dopage_problems( @$problems );
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
		$self->_dopage_problems( $self->{error} );
		return;
	}

	my $n_results = $self->count();

	my $offset = $self->{session}->param( "_offset" ) + 0;
	my $pagesize = $self->{page_size};

	@results = $self->get_records( $offset , $pagesize );
	$t3 = EPrints::Session::microtime();
	$self->dispose();

	my $plast = $offset + $pagesize;
	$plast = $n_results if $n_results< $plast;

	my %bits = ();
	
	if( scalar $n_results > 0 )
	{
		$bits{matches} = 
			$self->{session}->html_phrase( 
				"lib/searchexpression:results",
				from => $self->{session}->make_text( $offset+1 ),
				to => $self->{session}->make_text( $plast ),
				n => $self->{session}->make_text( $n_results )  
			);
	}
	else
	{
		$bits{matches} = 
			$self->{session}->html_phrase( 
				"lib/searchexpression:noresults" );
	}



	my @plugins = $self->{session}->plugin_list( 
					can_accept=>"list/".$self->{dataset}->confid, 
					is_visible=>"all" );
	$bits{export} = $self->{session}->make_doc_fragment;
	if( scalar @plugins > 0 ) {
		my $select = $self->{session}->make_element( "select", name=>"_output" );
		foreach my $plugin_id ( @plugins ) {
			$plugin_id =~ m/\/(.*)$/;
			my $option = $self->{session}->make_element( "option", value=>$1 );
			my $plugin = $self->{session}->plugin( $plugin_id );
			$option->appendChild( $plugin->render_name );
			$select->appendChild( $option );
		}
		my $button = $self->{session}->make_doc_fragment;
		$button->appendChild( $self->{session}->make_element( 
				"input", 
				type=>"submit", 
				name=>"_action_export_redir", 
				value=>$self->{session}->phrase( "lib/searchexpression:export_button" ) ) );
		$button->appendChild( 
			$self->{session}->make_element( 
				"input", 
				type=>"hidden", 
				name=>"_cache", 
				value=>$self->{cache_id} ) );
		$button->appendChild( 
			$self->{session}->make_element( 
				"input", 
				type=>"hidden", 
				name=>"_exp", 
				value=>$self->serialise ) );
		$bits{export} = $self->{session}->html_phrase( "lib/searchexpression:export_section",
					menu => $select,
					button => $button );
	}
	

	$bits{time} = $self->{session}->html_phrase( 
		"lib/searchexpression:search_time", 
		searchtime => $self->{session}->make_text($t3-$t1) );

	my $index = new EPrints::Index( 
			$self->{session}, 
			$self->{dataset} );

	$bits{last_index} = $self->{session}->html_phrase( 
		"lib/searchexpression:last_index", 
		index_datestamp => $self->{session}->make_text( 
					$index->get_last_timestamp ) );

	$bits{searchdesc} = $self->render_description;

	my $links = $self->{session}->make_doc_fragment();
	$bits{controls} = $self->{session}->make_element( "p", class=>"searchcontrols" );
	my $url = $self->{session}->get_uri();
	#cjg escape URL'ify urls in this bit... (4 of them?)
	my $escexp = $self->serialise();	
	$escexp =~ s/ /+/g; # not great way...
	my $a;
	my $cspan;
	if( $offset > 0 ) 
	{
		my $bk = $offset-$pagesize;
		my $fullurl = "$url?_cache=".$self->{cache_id}."&_exp=$escexp&_offset=".($bk<0?0:$bk);
		$a = $self->{session}->render_link( $fullurl );
		my $pn = $pagesize>$offset?$offset:$pagesize;
		$a->appendChild( 
			$self->{session}->html_phrase( 
				"lib/searchexpression:prev",
				n=>$self->{session}->make_text( $pn ) ) );
		$cspan = $self->{session}->make_element( 'span', class=>"searchcontrol" );
		$cspan->appendChild( $a );
		$bits{controls}->appendChild( $cspan );
		$bits{controls}->appendChild( $self->{session}->html_phrase( "lib/searchexpression:seperator" ) );
		$links->appendChild( $self->{session}->make_element( "link",
						rel=>"Prev",
						href=>EPrints::Utils::url_escape( $fullurl ) ) );
	}

	$a = $self->{session}->render_link( "$url?_cache=".$self->{cache_id}."&_exp=$escexp&_action_update=1" );
	$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:refine" ) );
	$cspan = $self->{session}->make_element( 'span', class=>"searchcontrol" );
	$cspan->appendChild( $a );
	$bits{controls}->appendChild( $cspan );
	$bits{controls}->appendChild( $self->{session}->html_phrase( "lib/searchexpression:seperator" ) );

	$a = $self->{session}->render_link( $url );
	$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:new" ) );
	$cspan = $self->{session}->make_element( 'span', class=>"searchcontrol" );
	$cspan->appendChild( $a );
	$bits{controls}->appendChild( $cspan );

	if( $offset + $pagesize < $n_results )
	{
		my $fullurl="$url?_cache=".$self->{cache_id}."&_exp=$escexp&_offset=".($offset+$pagesize);
		$a = $self->{session}->render_link( $fullurl );
		my $nn = $n_results - $offset - $pagesize;
		$nn = $pagesize if( $pagesize < $nn);
		$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:next",
					n=>$self->{session}->make_text( $nn ) ) );
		$bits{controls}->appendChild( $self->{session}->html_phrase( "lib/searchexpression:seperator" ) );
		$cspan = $self->{session}->make_element( 'span', class=>"searchcontrol" );
		$cspan->appendChild( $a );
		$bits{controls}->appendChild( $cspan );
		$links->appendChild( $self->{session}->make_element( "link",
						rel=>"Next",
						href=>EPrints::Utils::url_escape( $fullurl ) ) );
	}

	$bits{results} = $self->{session}->make_doc_fragment;
	foreach my $result ( @results )
	{
		my $p = $self->{session}->make_element( "p" );
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
			$self->{session}->make_doc_fragment;
	}

	my $page = $self->{session}->render_form( "GET" );
	$page->appendChild( $self->{session}->html_phrase(
		"lib/searchexpression:results_page",
		%bits ));

	$self->{session}->build_page( 
		$self->{session}->html_phrase( 
				"lib/searchexpression:results_for", 
				title => $self->_render_title ),
		$page,
		"search_results",
		$links );
	$self->{session}->send_page();
}


######################################################################
# 
# $searchexp->_render_title
#
# Return the title for the search page
#
######################################################################

sub _render_title
{
	my( $self ) = @_;

	return $self->{"session"}->html_phrase( $self->{"title_phrase"} );
}

######################################################################
# 
# $searchexp->_render_preamble
#
# Return the preamble for the search page
#
######################################################################

sub _render_preamble
{
	my( $self ) = @_;

	if( defined $self->{"preamble_phrase"} )
	{
		return $self->{"session"}->html_phrase(
				$self->{"preamble_phrase"} );
	}
	return $self->{"session"}->make_doc_fragment;
}

######################################################################
# 
# $searchexp->_dopage_problems( @problems )
#
# Output a page which explains any problems with a search expression.
# Such as searching for the years "2001-20FISH"
#
######################################################################

sub _dopage_problems
{
	my( $self , @problems ) = @_;	
	# Problem with search expression. Report an error, and redraw the form
		
	my $page = $self->{session}->make_doc_fragment();
	$page->appendChild( $self->_render_preamble );

	my $problem_box = $self->{session}->make_element( 
				"div",
				class=>"problems" );
	$problem_box->appendChild( $self->{session}->html_phrase( "lib/searchexpression:form_problem" ) );

	# List the problem(s)
	my $ul = $self->{session}->make_element( "ul" );
	$page->appendChild( $ul );
	my $problem;
	foreach $problem (@problems)
	{
		my $li = $self->{session}->make_element( 
			"li",
			class=>"problem" );
		$ul->appendChild( $li );
		$li->appendChild( $self->{session}->make_text( $problem ) );
	}
	$problem_box->appendChild( $ul );
	$page->appendChild( $problem_box );
	$page->appendChild( $self->render_search_form( 1 , 1 ) );
			
	$self->{session}->build_page( $self->_render_title, $page, "search_problems" );
	$self->{session}->send_page();
}


######################################################################
=pod

=item $dataset = $searchexp->get_dataset

Return the EPrints::DataSet which this search relates to.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}


######################################################################
=pod

=item $searchexp->set_dataset( $dataset )

Set the EPrints::DataSet which this search relates to.

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

=item $xhtml = $searchexp->render_description

Return an XHTML DOM description of this search expressions current
parameters.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	$frag->appendChild( $self->render_conditions_description );
	$frag->appendChild( $self->{session}->make_text( " " ) );
	$frag->appendChild( $self->render_order_description );

	return $frag;
}

######################################################################
=pod

=item $xhtml = $searchexp->render_conditions_description

Return an XHTML DOM description of this search expressions conditions.
ie title is "foo" 

=cut
######################################################################

sub render_conditions_description
{
	my( $self ) = @_;

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

	my $frag = $self->{session}->make_doc_fragment;

	for( my $i=0; $i<scalar @bits; ++$i )
	{
		if( $i>0 )
		{
			$frag->appendChild( $self->{session}->html_phrase( 
				$joinphraseid ) );
		}
		$frag->appendChild( $bits[$i] );
	}

	if( scalar @bits > 0 )
	{
		$frag->appendChild( $self->{session}->make_text( "." ) );
	}
	else
	{
		$frag->appendChild( $self->{session}->html_phrase(
			"lib/searchexpression:desc_no_conditions" ) );
	}

	return $frag;
}


######################################################################
=pod

=item $xhtml = $searchexp->render_order_description

Return an XHTML DOM description of how this search is ordered.

=cut
######################################################################

sub render_order_description
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	# empty if there is no order.
	return $frag unless( EPrints::Utils::is_set( $self->{order} ) );

	# empty if it's a custom ordering
	return $frag if( $self->{"order"} eq $EPrints::SearchExpression::CustomOrder );

	$frag->appendChild( $self->{session}->html_phrase(
		"lib/searchexpression:desc_order",
		order => $self->{session}->make_text(
			$self->{session}->get_order_name(
				$self->{dataset},
				$self->{order} ) ) ) );

	return $frag;
}
	

######################################################################
=pod

=item $searchexp->set_property( $property, $value );

Set any single property of this search, such as the order.

=cut
######################################################################

sub set_property
{
	my( $self, $property, $value ) = @_;

	$self->{$property} = $value;
}



######################################################################
=pod

=item @search_fields = $searchexp->get_searchfields()

Return the EPrints::SearchField objects relating to this search.

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

=item @search_fields = $searchexp->get_non_filter_searchfields();

Return the EPrints::SearchField objects relating to this search,
which are normal search fields, and not "filters".

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

=item @search_fields = $searchexp->get_set_searchfields

Return the searchfields belonging to this search expression which
have a value set. 

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
#   {results}  - the SearchResults object which describes the results.
#	





######################################################################
=pod

=item $cache_id = $searchexp->get_cache_id

Return the ID of the cache containing the results of this search,
if known.

=cut
######################################################################

sub get_cache_id
{
	my( $self ) = @_;
	
	return $self->{cache_id};
}

######################################################################
=pod

=item $results = $searchexp->perform_search

Execute this search and return a EPrints::SearchResults object
representing the results.

=cut
######################################################################

sub perform_search
{
	my( $self ) = @_;
	$self->{error} = undef;

	if( defined $self->{results} )
	{
		return $self->{results};
	}

	# cjg hmmm check cache still exists?
	if( defined $self->{cache_id} )
	{
		$self->{results} = EPrints::SearchResults->new( 
			session => $self->{session},
			dataset => $self->{dataset},
			cache_id => $self->{cache_id}, 
			desc => $self->render_conditions_description,
			desc_order => $self->render_order_description,
		);
		return $self->{results};
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
			$order = $self->{session}->get_archive()->get_conf( 
						"order_methods" , 
						$self->{dataset}->confid(),
						$self->{order} );
		}
	}

	#my $conditions = $self->get_conditions;
	#print STDERR $conditions->describe."\n\n";

	my $unsorted_matches = $self->get_conditions->process( 
						$self->{session} );

	$self->{results} = EPrints::SearchResults->new( 
		session => $self->{session},
		dataset => $self->{dataset},
		order => $order,
		encoded => $self->serialise,
		keep_cache => $self->{keep_cache},
		ids => $unsorted_matches, 
		desc => $self->render_conditions_description,
		desc_order => $self->render_order_description,
	);

	$self->{cache_id} = $self->{results}->get_cache_id;

	return $self->{results};
}



 ######################################################################
 # Legacy functions which daisy chain to the results object
 ######################################################################


sub cache_results
{
	my( $self ) = @_;

	if( !defined $self->{result} )
	{
		$self->{session}->get_archive()->log( "\$searchexp->cache_results() : Search has not been performed" );
		return;
	}

	$self->{results}->cache;
}

sub dispose
{
	my( $self ) = @_;

	return unless defined $self->{results};

	$self->{results}->dispose;
}

sub count
{
	my( $self ) = @_;

	return unless defined $self->{results};

	$self->{results}->count;
}

sub get_records
{
	my( $self , $offset , $count ) = @_;
	
	return $self->{results}->get_records( $offset , $count );
}

sub get_ids
{
	my( $self , $offset , $count ) = @_;
	
	return $self->{results}->get_ids( $offset , $count );
}

sub map
{
	my( $self, $function, $info ) = @_;	

	return $self->{results}->map( $function, $info );
}












package EPrints::SearchResults;

#   {ids} - a reference to an array of id's.
#         undefined if search has not been performed
#	  can be ["ALL"] to indicate all items in
#	  dataset.
#



######################################################################
=pod

=item $results = EPrints::SearchResults->new( 
			session => $session,
			dataset => $dataset,
			[desc => $desc],
			[desc_order => $desc_order],
			ids => $ids,
			[encoded => $encoded],
			[keep_cache => $keep_cache],
			[order => $order] );

=item $results = EPrints::SearchResults->new( 
			session => $session,
			dataset => $dataset,
			[desc => $desc],
			[desc_order => $desc_order],
			cache_id => $cache_id );

Creates a new search results object in memory only. Results will be
cached if anything requiring order is required, or an explicit 
cache() method is called.

encoded is the serialised version of the searchexpression which
created this results set.

If keep_cache is set then the cache will not be disposed of at the
end of the current $session. If cache_id is set then keep_cache is
automatically true.

=cut
######################################################################

sub new
{
	my( $class, %opts ) = @_;

	my $self = {};
	$self->{session} = $opts{session};
	$self->{dataset} = $opts{dataset};
	$self->{ids} = $opts{ids};
	$self->{order} = $opts{order};
	$self->{encoded} = $opts{encoded};
	$self->{cache_id} = $opts{cache_id};
	$self->{keep_cache} = $opts{keep_cache};
	$self->{desc} = $opts{desc};
	$self->{desc_order} = $opts{desc_order};

	if( !defined $self->{cache_id} && !defined $self->{ids} ) 
	{
		EPrints::Config::abort( "cache_id or ids must be defined in a EPrints::SearchResults->new()" );
	}
	if( !defined $self->{session} )
	{
		EPrints::Config::abort( "session must be defined in a EPrints::SearchResults->new()" );
	}
	if( !defined $self->{dataset} )
	{
		EPrints::Config::abort( "dataset must be defined in a EPrints::SearchResults->new()" );
	}
	bless $self, $class;

	if( $self->{cache_id} )
	{
		$self->{keep_cache} = 1;
	}

	if( $self->{keep_cache} )
	{
		$self->cache;
	}

	return $self;
}


######################################################################
=pod

=item $newresults = $results->reorder( $new_order );

Create a new results set from this one, but sorted in a new way.

=cut
######################################################################

sub reorder
{
	my( $self, $new_order ) = @_;

	# must be cached to be reordered
	$self->cache;

	my $db = $self->{session}->get_db;

	my $srctable = $db->cache_table( $self->{cache_id} );

	my $new_cache_id  = $db->cache( 
		$self->{encoded}."(reordered:$new_order)", # nb. not very neat. 
		$self->{dataset},
		$srctable,
		$new_order );

	my $new_list = EPrints::SearchResults->new( 
		session=>$self->{session},
		dataset=>$self->{dataset},
		desc=>$self->{desc}, # don't pass desc_order!
		order=>$new_order,
		keep_cache=>$self->{keep_cache},
		cache_id => $new_cache_id );
		
	return $new_list;
}
		

######################################################################
=pod

=item $results->cache

Cause the results of this search to be cached.

=cut
######################################################################

sub cache
{
	my( $self ) = @_;

	return if( defined $self->{cache_id} );

	if( $self->_matches_none && !$self->{keep_cache} )
	{
		# not worth caching zero in a temp table!
		return;
	}

	my $srctable;
	if( $self->_matches_all )
	{
		$srctable = $self->{dataset}->get_sql_table_name();
	}
	else
	{
		$srctable = $self->{session}->get_db()->make_buffer(
			$self->{dataset}->get_key_field()->get_name(),
			$self->{ids} );
	}

	$self->{cache_id} = $self->{session}->get_db()->cache( 
		$self->{encoded}, 
		$self->{dataset},
		$srctable,
		$self->{order} );

	unless( $self->_matches_all )
	{
		$self->{session}->get_db()->dispose_buffer( $srctable );
	}
		
}

######################################################################
=pod

=item $cache_id = $results->get_cache_id

Return the ID of the cache table for these results, or undef.

=cut
######################################################################

sub get_cache_id
{
	my( $self ) = @_;
	
	return $self->{cache_id};
}



######################################################################
=pod

=item $results->dispose

Clean up the cache table if appropriate.

=cut
######################################################################

sub dispose
{
	my( $self ) = @_;

	if( defined $self->{cache_id} && !$self->{keep_cache} )
	{
		$self->{session}->get_db->drop_cache( $self->{cache_id} );
		delete $self->{cache_id};
	}
}


######################################################################
=pod

=item $n = $results->count 

Return the number of values in this results set.

=cut
######################################################################

sub count 
{
	my( $self ) = @_;

	if( defined $self->{ids} )
	{
		if( $self->_matches_all )
		{
			return $self->{dataset}->count( $self->{session} );
		}
		return( scalar @{$self->{ids}} );
	}

	if( defined $self->{cache_id} )
	{
		#cjg Should really have a way to get at the
		# cache. Maybe we should have a table object.
		return $self->{session}->get_db()->count_table( 
			"cache".$self->{cache_id} );
	}

	EPrints::Config::abort( "Called \$results->count() where there was no cache or ids." );
}


######################################################################
=pod

=item @dataobjs = $results->get_records( [$offset], [$count] )

Return the objects described by these results. $count is the maximum
to return. $offset is what index through the results to start from.

=cut
######################################################################

sub get_records
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 0 );
}


######################################################################
=pod

=item $ids = $results->get_ids( [$offset], [$count] )

Return a reference to an array containing the ids of the specified
range of results. This is more efficient if you just need the ids.

=cut
######################################################################

sub get_ids
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 1 );
}


######################################################################
# 
# $bool = $results->_matches_none
#
######################################################################

sub _matches_none
{
	my( $self ) = @_;

	if( !defined $self->{ids} )
	{
		EPrints::Config::abort( "Error: Calling _matches_none when {ids} not set\n" );
	}

	return( scalar @{$self->{ids}} == 0 );
}

######################################################################
# 
# $bool = $results->_matches_all
#
######################################################################

sub _matches_all
{
	my( $self ) = @_;

	if( !defined $self->{ids} )
	{
		EPrints::Config::abort( "Error: Calling _matches_all when {ids} not set\n" );
	}

	return( 0 ) if( !defined $self->{ids}->[0] );

	return( $self->{ids}->[0] eq "ALL" );
}

######################################################################
# 
# $ids/@dataobjs = $results->_get_records ( $offset, $count, $justids )
#
# Method which handles getting results or ids.
#
######################################################################

sub _get_records 
{
	my ( $self , $offset , $count, $justids ) = @_;

	if( defined $self->{ids} )
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

		# quick solutions if we don't need to order anything...
		if( !defined $offset && !defined $count && !defined $self->{order} )
		{
			if( $justids )
			{
				if( $self->_matches_all )
				{
					return $self->{dataset}->get_item_ids( $self->{session} );
				}
				else
				{
					return $self->{ids};
				}
			}
	
			if( $self->_matches_all )
			{
				return $self->{session}->get_db->get_all(
					$self->{dataset} );
			}
		}

		# If the above tests failed then	
		# we are returning all matches, but there's no
		# easy shortcut.
	}

	if( !defined $self->{cache_id} )
	{
		$self->cache;
	}

	my $r = $self->{session}->get_db()->from_cache( 
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

=item $results->map( $function, $info )

Map the given function pointer to all the results in the set, in
order. This loads the results in batches of 100 to reduce memory 
requirements.

$info is a datastructure which will be passed to the function each 
time and is useful for holding or collecting state.

Example:

 my $info = { matches => 0 };
 $results->map( \&deal, $info );
 print "Matches: ".$info->{matches}."\n";


 sub deal
 {
 	my( $session, $dataset, $eprint, $info ) = @_;
 
 	if( $eprint->get_value( "a" ) eq $eprint->get_value( "b" ) ) {
 		$info->{matches} += 1;
 	}
 }	

=cut
######################################################################

sub map
{
	my( $self, $function, $info ) = @_;	

	my $count = $self->count();

	my $CHUNKSIZE = 100;

	for( my $offset = 0; $offset < $count; $offset+=$CHUNKSIZE )
	{
		my @records = $self->get_records( $offset, $CHUNKSIZE );
		foreach my $item ( @records )
		{
			&{$function}( 
				$self->{session}, 
				$self->{dataset}, 
				$item, 
				$info );
		}
	}
}

######################################################################
=pod

=item $plugin_output = $results->export( $plugin_id, %params )

Apply an output plugin to this list of items. If the param "fh"
is set it will send the results to a filehandle rather than return
them as a string. 

=cut
######################################################################

sub export
{
	my( $self, $out_plugin_id, %params ) = @_;

	my $plugin_id = "output/".$out_plugin_id;
	my $plugin = $self->{session}->plugin( $plugin_id );

	unless( defined $plugin )
	{
		EPrints::Config::abort( "Could not find plugin $plugin_id" );
	}

	my $req_plugin_type = "list/".$self->{dataset}->confid;

	unless( $plugin->can_accept( $req_plugin_type ) )
	{
		EPrints::Config::abort( 
"Plugin $plugin_id can't process $req_plugin_type data." );
	}
	
	
	return $plugin->output_list( list=>$self, %params );
}

######################################################################
=pod

=item $dataset = $results->get_dataset

Return the EPrints::DataSet which this results set relates to.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}

######################################################################
=pod

=item $xhtml = $results->render_description

Return a DOM XHTML description of this list, if available, or an
empty fragment.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	if( defined $self->{desc} )
	{
		$frag->appendChild( $self->{session}->clone_for_me( $self->{desc}, 1 ) );
		$frag->appendChild( $self->{session}->make_text( " " ) );
	}
	if( defined $self->{desc_order} )
	{
		$frag->appendChild( $self->{session}->clone_for_me( $self->{desc_order}, 1 ) );
	}

	return $frag;
}

sub DESTROY
{
	my( $self ) = @_;

	if( defined $self->{desc} ) { EPrints::XML::dispose( $self->{desc} ); }
	if( defined $self->{desc_order} ) { EPrints::XML::dispose( $self->{desc_order} ); }
}

1;

######################################################################
=pod

=back

=cut

