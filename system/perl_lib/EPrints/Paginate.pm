######################################################################
#
# EPrints::Paginate
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

B<EPrints::Paginate> - Methods for rendering a paginated List

=head1 DESCRIPTION

=over 4

=cut

######################################################################
package EPrints::Paginate;

use URI::Escape;
use strict;

######################################################################
=pod

=item $xhtml = EPrints::Paginate->paginate_list( $session, $basename, $list, %opts )

Render a "paginated" view of the list i.e. display a "page" of items 
with links to navigate through the list.

$basename is the basename to use for pagination-specific CGI parameters, to avoid clashes.

%opts is a hash of options which can be used to customise the 
behaviour and/or rendering of the paginated list. See EPrints::Search 
for a good example!

B<Behaviour options:>

=over 4

=item page_size	

The maximum number of items to display on a page.

=item pagejumps

The maximum number of page jump links to display.

=item params

A hashref of parameters to include in the prev/next/jump URLs, 
e.g. to maintain the state of other controls on the page between jumps.

=back

B<Rendering options:>

=over 4

=item controls_before, controls_after

Additional links to display before/after the page navigation controls.

=item container

A containing XML DOM element for the list of items on the current page.

=item render_result, render_result_params

A custom subroutine for rendering an individual item on the current 
page. The subroutine will be called with $session, $item, and the
parameter specified by the render_result_params option. The
rendered item should be returned.

=item phrase

The phrase to use to render the entire "page". Can make use of the following pins:

=over 4

=item controls

prev/next/jump links

=item searchdesc

description of list e.g. what search parameters produced it

=item matches

total number of items in list, range of items displayed on current page

=item results

list of rendered items

=item controls_if_matches

prev/next/jump links (only if list contains >0 items)

=back

These can be overridden in the "pins" option (below).

=item pins

Named "pins" to render on the page. These may override the default 
"pins" (see above), or specify new "pins" (although you would need 
to define a custom phrase in order to make use of them).

=back

=cut
######################################################################

sub paginate_list
{
	my( $class, $session, $basename, $list, %opts ) = @_;

	my $n_results = $list->count();
	my $offset = $session->param( $basename."_offset" ) + 0;
	#my $offset = $session->param( "_offset" ) + 0;
	my $pagesize = $opts{page_size} || 10; # TODO: get default from somewhere?
	my @results = $list->get_records( $offset , $pagesize );
	my $plast = $offset + $pagesize;
	$plast = $n_results if $n_results< $plast;

	my %pins = ();

	my $matches;	
	if( scalar $n_results > 0 )
	{
		# TODO default phrase for item range
		# TODO override default phrase with opts
		my %numbers = ();
		$numbers{from} = $session->make_element( "span", class=>"ep_search_number" );
		$numbers{from}->appendChild( $session->make_text( $offset+1 ) );
		$numbers{to} = $session->make_element( "span", class=>"ep_search_number" );
		$numbers{to}->appendChild( $session->make_text( $plast ) );
		$numbers{n} = $session->make_element( "span", class=>"ep_search_number" );
		$numbers{n}->appendChild( $session->make_text( $n_results ) );
		$matches = $session->html_phrase( "lib/searchexpression:results", %numbers );
	}
	else
	{
		# TODO default phrase for empty list
		# override default phrase with opts
		$matches = 
			$session->html_phrase( 
				"lib/searchexpression:noresults" );
	}

	if( !defined $pins{searchdesc} )
	{
		$pins{searchdesc} = $list->render_description;
	}

	# Add params to action urls
	my $url = $session->get_uri . "?";
	my @param_list;
	#push @param_list, "_cache=" . $list->get_cache_id; # if cached
	#my $escexp = $list->{encoded}; # serialised search expression
	#$escexp =~ s/ /+/g; # not great way...
	#push @param_list, "_exp=$escexp";
	if( defined $opts{params} )
	{
		my $params = $opts{params};
		foreach my $key ( keys %$params )
		{
			my $value = $params->{$key};
			push @param_list, "$key=$value";
		}
	}
	$url .= join "&", @param_list;

	my @controls; # page controls
	if( defined $opts{controls_before} )
	{
		my $custom_controls = $opts{controls_before};
		foreach my $control ( @$custom_controls )
		{
			my $custom_control = $session->render_link( $control->{url} );
			$custom_control->appendChild( $control->{label} );
			push @controls, $custom_control;
		}
	}

	# Previous page link
	if( $offset > 0 ) 
	{
		my $bk = $offset-$pagesize;
		my $prevurl = "$url&$basename\_offset=".($bk<0?0:$bk);
		my $prevlink = $session->render_link( $prevurl );
		my $pn = $pagesize>$offset?$offset:$pagesize;
		$prevlink->appendChild( 
			$session->html_phrase( 
				"lib/searchexpression:prev",
				n=>$session->make_doc_fragment ) );
				#n=>$session->make_text( $pn ) ) );
		push @controls, $prevlink;
	}

	# Page jumps
	my $pages_to_show = $opts{pagejumps} || 10; # TODO: get default from somewhere?
	my $cur_page = $offset / $pagesize;
	my $num_pages = int( $n_results / $pagesize );
	$num_pages++ if $n_results % $pagesize;
	$num_pages--; # zero based

	my $start_page = $cur_page - ( $pages_to_show / 2 );
	my $end_page = $cur_page + ( $pages_to_show / 2 );

	if( $start_page < 0 )
	{
		$end_page += -$start_page; # end page takes up slack
	}
	if( $end_page > $num_pages )
	{
		$start_page -= $end_page - $num_pages; # start page takes up slack
	}

	$start_page = 0 if $start_page < 0; # normalise
	$end_page = $num_pages if $end_page > $num_pages; # normalise
	unless( $start_page == $end_page ) # only one page, don't need jumps
	{
		for my $page_n ( $start_page..$end_page )
		{
			my $jumplink;
			if( $page_n != $cur_page )
			{
				my $jumpurl = "$url&$basename\_offset=" . $page_n * $pagesize;
				$jumplink = $session->render_link( $jumpurl );
				$jumplink->appendChild( $session->make_text( $page_n + 1 ) );
			}
			else
			{
				$jumplink = $session->make_element( "strong" );
				$jumplink->appendChild( $session->make_text( $page_n + 1 ) );
			}
			push @controls, $jumplink;
		}
	}

	# Next page link
	if( $offset + $pagesize < $n_results )
	{
		my $nexturl="$url&$basename\_offset=".($offset+$pagesize);
		my $nextlink = $session->render_link( $nexturl );
		my $nn = $n_results - $offset - $pagesize;
		$nn = $pagesize if( $pagesize < $nn);
		$nextlink->appendChild( $session->html_phrase( "lib/searchexpression:next",
					n=>$session->make_doc_fragment ) );
					#n=>$session->make_text( $nn ) ) );
		push @controls, $nextlink;
	}

#	if( defined $opts{controls_after} )
#	{
#		my $custom_controls = $opts{controls_after};
#		foreach my $control ( @$custom_controls )
#		{
#			my $custom_control = $session->render_link( $control->{url} );
#			$custom_control->appendChild( $control->{label} );
#			push @controls, $custom_control;
#		}
#	}

	if( scalar @controls )
	{
		$pins{controls} = $session->make_element( "div" );
		$pins{controls}->appendChild( $matches );

		$pins{controls}->appendChild( $session->make_element( "br" ) );

		my $first = 1;
		foreach my $control ( @controls )
		{
			if( $first )
			{
				$first = 0;
			}
			else
			{
				$pins{controls}->appendChild( $session->html_phrase( "lib/searchexpression:seperator" ) );
			}
			my $cspan = $session->make_element( 'span', class=>"ep_search_control" );
			$cspan->appendChild( $control );
			$pins{controls}->appendChild( $cspan );
		}
	}
	else
	{
		$pins{controls} = $session->make_doc_fragment;
	}

	# Container for results (e.g. table, div..)
	if( defined $opts{container} )
	{
		$pins{results} = $opts{container};
	}
	else
	{
		$pins{results} = $session->make_doc_fragment;
	}

	my $n = $offset;
	foreach my $result ( @results )
	{
		$n += 1;
		# Render individual results
		if( defined $opts{render_result} )
		{
			# Custom rendering routine specified
			my $params = $opts{render_result_params};
			my $custom = &{ $opts{render_result} }( $session, $result, $params, $n );
			$pins{results}->appendChild( $custom );
		}
		else
		{
			# Default: render citation
			my $div = $session->make_element( "div", class=>"ep_search_result" );
			$div->appendChild( $result->render_citation_link() ); 
			$pins{results}->appendChild( $div );
		}
	}
	
	if( $n_results > 0 )
	{
		# Only print a second set of controls if there are matches.
		$pins{controls_if_matches} = EPrints::XML::clone_node( $pins{controls}, 1 );
	}
	else
	{
		$pins{controls_if_matches} = $session->make_doc_fragment;
	}

	# Render a page of results
	my $custom_pins = $opts{pins};
	for( keys %$custom_pins )
	{
		$pins{$_} = $custom_pins->{$_} if defined $custom_pins->{$_};
	}
	my $page;
	if( defined $opts{phrase} )
	{
		$page = $session->html_phrase( $opts{phrase}, %pins );
	}
	else
	{
		# Default: use built-in phrase
		$page = $session->html_phrase( "lib/list:page", %pins );
	}
	return $page;
}


######################################################################
=pod

=item $xhtml = EPrints::Paginate->paginate_list_with_columns( $session, $basename, $list, %opts )

Uses paginate_list to render a table layout with columns displaying
specified field values. Each column header contains controls which
can be used to change the order of the list.

%opts has an additional option - columns - which is an array ref of
fields to display.

=cut

######################################################################

sub paginate_list_with_columns
{
	my( $class, $session, $basename, $list, %opts ) = @_;

	my %newopts = %opts;
	
	# Build base URL
	my $url = $session->get_uri . "?";
	my @param_list;
	if( defined $opts{params} )
	{
		my $params = $opts{params};
		foreach my $key ( keys %$params )
		{
			my $value = $params->{$key};
			push @param_list, "$key=$value";
		}
	}
	$url .= join "&", @param_list;

	my $offset = $session->param( "$basename\_offset" ) + 0;
	$url .= "&$basename\_offset=$offset"; # $basename\_offset used by paginate_list

	# Sort param
	my $sort_order = $session->param( $basename."_order" );
	if( defined $sort_order && $sort_order ne "" )
	{
		$newopts{params}{ $basename."_order" } = $sort_order;
		$list = $list->reorder( $sort_order );
	}
	
	# URL for images
	my $imagesurl = $session->get_repository->get_conf( "base_url" )."/style/images";
	my $esec = $session->get_request->dir_config( "EPrints_Secure" );
	if( defined $esec && $esec eq "yes" )
	{
		$imagesurl = $session->get_repository->get_conf( "securepath" )."/style/images";
	}

	# Container for list
	my $table = $session->make_element( "table", border=>0, cellpadding=>4, cellspacing=>0, width=>"100%" );
	my $tr = $session->make_element( "tr", class=>"header_plain" );
	$table->appendChild( $tr );

	foreach my $col ( @{ $opts{columns} } )
	{
		# Column headings
		my $th = $session->make_element( "th" );
		$th->appendChild( $list->get_dataset->get_field( $col )->render_name( $session ) );
		$tr->appendChild( $th );

		# Sort controls
		foreach my $dir ( "up", "down" )
		{
			my( $ctrl, $ctrl_order );

			if( $dir eq "up" )
			{
				$ctrl_order = $col;
			}
			else
			{
				$ctrl_order = "-" . $col;
			}

			if( $sort_order ne $ctrl_order )
			{
				$ctrl = $session->render_link( "$url&$basename\_order=$ctrl_order" );
				$ctrl->appendChild( $session->make_element(
					"img",
					alt=>$dir,
					border=>0,
					src=> "$imagesurl/multi_$dir\.png" ));
			}
			else
			{
				$ctrl = $session->make_element(
					"img",
					alt=>$dir,
					border=>0,
					src=> "$imagesurl/multi_$dir\_dim.png" );
			}
			$th->appendChild( $ctrl );
		}
	}
	
	my $info = {
		row => 1,
		columns => $opts{columns},
	};
	$newopts{container} = $table unless defined $newopts{container};
	$newopts{render_result_params} = $info unless defined $newopts{render_result_params};
	$newopts{render_result} = sub {
		my( $session, $e, $info ) = @_;

		my $tr = $session->make_element( "tr" );

		for( @{ $info->{columns} } )
		{
			my $td = $session->make_element( "td" );
			$tr->appendChild( $td );
			$td->appendChild( $e->render_value( $_ ) );
		}
		return $tr;
	} unless defined $newopts{render_result};
	
	return EPrints::Paginate->paginate_list( $session, $basename, $list, %newopts );
}

1;

######################################################################
=pod

=back

=cut

