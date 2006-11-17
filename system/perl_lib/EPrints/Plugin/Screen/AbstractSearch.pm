package EPrints::Plugin::Screen::AbstractSearch;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ update search newsearch export_redir export /]; 

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0;
}

sub allow_export_redir { return 0; }

sub action_export_redir
{
	my( $self ) = @_;

	my $exp = $self->{session}->param( "_exp" );
	my $cacheid = $self->{session}->param( "_cache" );
	my $format = $self->{session}->param( "_output" );
	my $plugin = $self->{session}->plugin( "Export::".$format );

	my $url = $self->{session}->get_uri();
	#cjg escape URL'ify urls in this bit... (4 of them?)
	my $escexp = $exp;
	$escexp =~ s/ /+/g; # not great way...
	my $fullurl = "$url/export_".$self->{session}->get_repository->get_id."_".$format.$plugin->param("suffix")."?_exp=$escexp&_output=$format&_action_export=1&_cache=$cacheid&screen=".$self->{processor}->{screenid};

	$self->{processor}->{redirect} = $fullurl;
}

sub allow_export { return 0; }

sub action_export
{
	my( $self ) = @_;

	$self->run_search;

	$self->{processor}->{search_subscreen} = "export";

	return;
}

sub allow_search { return 1; }

sub action_search
{
	my( $self ) = @_;

	$self->{processor}->{search_subscreen} = "results";

	$self->run_search;
}

sub allow_update { return 1; }

sub action_update
{
	my( $self ) = @_;

	$self->{processor}->{search_subscreen} = "form";
}

sub allow_newsearch { return 1; }

sub action_newsearch
{
	my( $self ) = @_;

	$self->{processor}->{search}->clear;

	$self->{processor}->{search_subscreen} = "form";
}

sub run_search
{
	my( $self ) = @_;

	my $list = $self->{processor}->{search}->perform_search();

	my $error = $self->{processor}->{search}->{error};
	if( defined $error )
	{	
		$self->{processor}->add_message( "error", $error );
		$self->{processor}->{search_subscreen} = "form";
	}

	if( $list->count == 0 )
	{
		$self->{processor}->add_message( "warning",
			$self->{session}->html_phrase(
				"lib/searchexpression:noresults") );
		$self->{processor}->{search_subscreen} = "form";
	}

	$self->{processor}->{results} = $list;
}	

sub search_dataset
{
	my( $self ) = @_;

	return undef;
}

sub search_filters
{
	my( $self ) = @_;

	return;
}


sub from
{
	my( $self ) = @_;

	$self->{processor}->{search} = new EPrints::Search(
		keep_cache => 1,
		session => $self->{session},
		filters => [$self->search_filters],
		dataset => $self->search_dataset,
		%{$self->{processor}->{sconf}} );


	$self->{actions} = [qw/ update search newsearch export_redir export /]; 
	if( 	$self->{processor}->{action} eq "search" || 
	 	$self->{processor}->{action} eq "update" || 
	 	$self->{processor}->{action} eq "export" || 
	 	$self->{processor}->{action} eq "export_redir"  )
	{
		my $loaded = 0;
		my $id = $self->{session}->param( "_cache" );
		if( defined $id )
		{
			$loaded = $self->{processor}->{search}->from_cache( $id );
		}
	
		if( !$loaded )
		{
			my $exp = $self->{session}->param( "_exp" );
			if( defined $exp )
			{
				$self->{processor}->{search}->from_string( $exp );
				# cache expired...
				$loaded = 1;
			}
		}
	
		my @problems;
		if( !$loaded )
		{
			foreach my $sf ( $self->{processor}->{search}->get_non_filter_searchfields )
			{
				my $prob = $sf->from_form();
				if( defined $prob )
				{
					$self->{processor}->add_message( "warning", $prob );
				}
			}
		}
	}
	my $anyall = $self->{session}->param( "_satisfyall" );

	if( defined $anyall )
	{
		$self->{processor}->{search}->{satisfy_all} = ( $anyall eq "ALL" );
	}

	my $order_opt = $self->{session}->param( $self->{prefix}."_order" );

	$self->{processor}->{search}->{custom_order} = $self->{processor}->{sconf}->{order_methods}->{$order_opt};
	if( !defined $self->{processor}->{search}->{custom_order} )
	{
		$self->{processor}->{search}->{custom_order} = 
			 $self->{processor}->{sconf}->{order_methods}->{$self->{processor}->{sconf}->{default_order}};
	}

	# do actions
	$self->SUPER::from;

	if( $self->{processor}->{search}->is_blank && ! $self->{processor}->{search}->{allow_blank} )
	{
		if( $self->{processor}->{action} eq "search" )
		{
			$self->{processor}->add_message( "warning",
				$self->{session}->html_phrase( 
					"lib/searchexpression:least_one" ) );
			$self->{processor}->{search_subscreen} = "form";
		}
	}

}

sub render
{
	my( $self ) = @_;

	my $subscreen = $self->{processor}->{search_subscreen};
	if( !defined $subscreen || $subscreen eq "form" )
	{
		return $self->render_search_form;	
	}
	if( $subscreen eq "results" )
	{
		return $self->render_results;	
	}

	$self->{processor}->add_message(
		"error",
		$self->{session}->make_text( "Bad search subscreen: $subscreen" ) );
	return $self->render_search_form;	
}

sub _get_export_plugins
{
	my( $self ) = @_;

	return $self->{session}->plugin_list( 
			type=>"Export",
			can_accept=>"list/".$self->{processor}->{search}->{dataset}->confid, 
			is_visible=>$self->_vis_level );
}

sub _vis_level
{
	my( $self ) = @_;

	return "all";
}

sub render_title
{
	my( $self ) = @_;

	my $phraseid = $self->{processor}->{sconf}->{"title_phrase"};
	if( defined $phraseid )
	{
		return $self->{"session"}->html_phrase( $phraseid );
	}
	return $self->SUPER::render_title;
}

sub render_links
{
	my( $self ) = @_;

	if( $self->{processor}->{search_subscreen} ne "results" )
	{
		return $self->SUPER::render_links;
	}

	my @plugins = $self->_get_export_plugins;
	my $links = $self->{session}->make_doc_fragment();

	my $escexp = $self->{processor}->{search}->serialise;
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $plugin = $self->{session}->plugin( $plugin_id );
		my $link = $self->{session}->make_element( 
			"link", 
			rel=>"alternate",
			href=>"?_cache=".$self->{cache_id}."&_exp=".$escexp."&_action_export_redir=1&_output=$id",
			type=>$plugin->param("mimetype"),
			title=>EPrints::XML::to_string( $plugin->render_name ), );
		$links->appendChild( $link );
	}

	$links->appendChild( $self->SUPER::render_links );

	return $links;
}

sub render_export_select
{
	my( $self ) = @_;
	my @plugins = $self->_get_export_plugins;
	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $escexp = $self->{processor}->{search}->serialise;
	if( scalar @plugins == 0 ) 
	{
		return $self->{session}->make_doc_fragment;
	}

	my $select = $self->{session}->make_element( "select", name=>"_output" );
	my $options = {};
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $option = $self->{session}->make_element( "option", value=>$id );
		my $plugin = $self->{session}->plugin( $plugin_id );
		my $dom_name = $plugin->render_name;
		$option->appendChild( $dom_name );
		$options->{EPrints::XML::to_string($dom_name)} = $option;
	}
	foreach my $optname ( sort keys %{$options} )
	{
		$select->appendChild( $options->{$optname} );
	}
	my $button = $self->{session}->make_doc_fragment;
	$button->appendChild( $self->{session}->render_button(
			name=>"_action_export_redir", 
			value=>$self->{session}->phrase( "lib/searchexpression:export_button" ) ) );
	$button->appendChild( 
		$self->{session}->render_hidden_field( "screen", $self->{processor}->{screenid} ) ); 
	$button->appendChild( 
		$self->{session}->render_hidden_field( "_cache", $cacheid ) ); 
	$button->appendChild( 
		$self->{session}->render_hidden_field( "_exp", $escexp, ) );

	return $self->{session}->html_phrase( "lib/searchexpression:export_section",
					menu => $select,
					button => $button );
}

sub get_basic_controls_before
{
	my( $self ) = @_;
	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $escexp = $self->{processor}->{search}->serialise;

	my $baseurl = $self->{session}->get_uri . "?_cache=$cacheid&_exp=$escexp&screen=".$self->{processor}->{screenid};
	my @controls_before = (
		{
			url => "$baseurl&_action_update=1",
			label => $self->{session}->html_phrase( "lib/searchexpression:refine" ),
		},
		{
			url => $self->{session}->get_uri . "?screen=".$self->{processor}->{screenid},
			label => $self->{session}->html_phrase( "lib/searchexpression:new" ),
		}
	);

	return @controls_before;
}

sub get_controls_before
{
	my( $self ) = @_;

	return $self->get_basic_controls_before;
}

sub paginate_opts
{
	my( $self ) = @_;

	my %bits = ();

	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $escexp = $self->{processor}->{search}->serialise;

	my @controls_before = $self->get_controls_before;
	
	my $export_div = $self->{session}->make_element( "div", class=>"ep_search_export" );
	$export_div->appendChild( $self->render_export_select );

	my $type = $self->{session}->get_citation_type( 
			$self->{processor}->{results}->get_dataset, 
			$self->get_citation_id );
	my $container;
	if( $type eq "table_row" )
	{
		$container = $self->{session}->make_element( 
				"table", 
				class=>"ep_paginate_list" );
	}
	else
	{
		$container = $self->{session}->make_element( 
				"div", 
				class=>"ep_paginate_list" );
	}

	return (
		pins => \%bits,
		controls_before => \@controls_before,
		above_results => $export_div,
		params => { 
			screen => $self->{processor}->{screenid},
			_action_search => 1,
			_cache => $cacheid,
			_exp => $escexp,
		},
		render_result => sub { return $self->render_result_row( @_ ); },
		render_result_params => $self,
		page_size => $self->{processor}->{sconf}->{page_size},
		container => $container,
	);
}

sub render_results_intro
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub render_results
{
	my( $self ) = @_;

	my %opts = $self->paginate_opts;

	my $page = $self->{session}->render_form( "GET" );
	$page->appendChild( $self->render_results_intro );
	$page->appendChild( 
		EPrints::Paginate->paginate_list( 
			$self->{session}, 
			"_search", 
			$self->{processor}->{results}, 
			%opts ) );

	return $page;
}

sub render_result_row
{
	my( $self, $session, $result, $searchexp, $n ) = @_;

	my $type = $session->get_citation_type( 
			$self->{processor}->{results}->get_dataset, 
			$self->get_citation_id );

	if( $type eq "table_row" )
	{
		return $result->render_citation_link;
	}

	my $div = $session->make_element( "div", class=>"ep_search_result" );
	$div->appendChild( $result->render_citation_link( "default" ) );
	return $div;
}

sub get_citation_id 
{
	my( $self ) = @_;

	return $self->{processor}->{sconf}->{citation} || "default";
}

sub render_search_form
{
	my( $self ) = @_;

	my $form = $self->{session}->render_form( "get" );
	$form->appendChild( 
		$self->{session}->render_hidden_field ( "screen", $self->{processor}->{screenid} ) );		

	my $pphrase = $self->{processor}->{sconf}->{"preamble_phrase"};
	if( defined $pphrase )
	{
		$form->appendChild( $self->{"session"}->html_phrase( $pphrase ));
	}

	$form->appendChild( $self->render_controls );

	my $table = $self->{session}->make_element( "table", class=>"ep_search_fields" );
	$form->appendChild( $table );

	$table->appendChild( $self->render_search_fields );

	$table->appendChild( $self->render_anyall_field );

	$table->appendChild( $self->render_order_field );

	$form->appendChild( $self->render_controls );

	return( $form );
}


sub render_search_fields
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	foreach my $sf ( $self->{processor}->{search}->get_non_filter_searchfields )
	{
		my $div = $self->{session}->make_element( 
				"div" , 
				class => "ep_search_field_name" );
		$div->appendChild( $sf->render_name );

#		$div = $self->{session}->make_element( 
#			"div" , 
#			class => "ep_search_field_help" );
#		$div->appendChild( $sf->render_help );
#		$frag->appendChild( $div );

		$frag->appendChild( 
			$self->{session}->render_row( 
				$sf->render_name,
				$sf->render ) );
	}

	return $frag;
}


sub render_anyall_field
{
	my( $self ) = @_;

	my @sfields = $self->{processor}->{search}->get_non_filter_searchfields;
	if( (scalar @sfields) < 2 )
	{
		return $self->{session}->make_doc_fragment;
	}

	my $menu = $self->{session}->render_option_list(
			name=>"_satisfyall",
			values=>[ "ALL", "ANY" ],
			default=>( defined $self->{processor}->{search}->{satisfy_all} && $self->{processor}->{search}->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			labels=>{ "ALL" => $self->{session}->phrase( 
						"lib/searchexpression:all" ),
				  "ANY" => $self->{session}->phrase( 
						"lib/searchexpression:any" )} );

	return $self->{session}->render_row(
			$self->{session}->html_phrase( 
				"lib/searchexpression:must_fulfill" ),  
			$menu );
}

sub render_controls
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( 
		"div" , 
		class => "ep_search_buttons" );
	$div->appendChild( $self->{session}->render_action_buttons( 
		_order => [ "search", "newsearch" ],
		newsearch => $self->{session}->phrase( "lib/searchexpression:action_reset" ),
		search => $self->{session}->phrase( "lib/searchexpression:action_search" ) )
 	);
	return $div;
}



sub render_order_field
{
	my( $self ) = @_;

	my $raworder = $self->{processor}->{search}->{order};

	my $order = $self->{processor}->{sconf}->{default_order};

	my $methods = $self->{processor}->{sconf}->{order_methods};

	my %labels = ();
	foreach( keys %$methods )
	{
		$order = $_ if( $methods->{$_} eq $raworder );
                $labels{$methods->{$_}} = $self->{session}->phrase(
                	"ordername_".$self->{processor}->{search}->{dataset}->confid() . "_" . $_ );
        }

	my $menu = $self->{session}->render_option_list(
		name=>"_order",
		values=>[values %{$methods}],
		default=>$order,
		labels=>\%labels );

	return $self->{session}->render_row(
			$self->{session}->html_phrase( "lib/searchexpression:order_results" ),
			$menu );
}

# $method_map = $searche->order_methods

sub wishes_to_export
{
	my( $self ) = @_;

	return 0 unless $self->{processor}->{search_subscreen} eq "export";

	my $format = $self->{session}->param( "_output" );

	my @plugins = $self->{session}->plugin_list(
		type=>"Export",
		can_accept=>"list/eprint",
		is_visible=>$self->_vis_level );
		
	my $ok = 0;
	foreach( @plugins ) { if( $_ eq "Export::$format" ) { $ok = 1; last; } }
	unless( $ok ) 
	{
		$self->{session}->build_page(
			$self->{session}->html_phrase( "lib/searchexpression:export_error_title" ),
			$self->{session}->html_phrase( "lib/searchexpression:export_error_format" ),
			"export_error" );
		$self->{session}->send_page;
		return;
	}
	
	$self->{processor}->{export_plugin} = $self->{session}->plugin( "Export::$format" );
	$self->{processor}->{export_format} = $format;
	
	return 1;
}


sub export
{
	my( $self ) = @_;

	print $self->{processor}->{results}->export( $self->{processor}->{export_format} );
}

sub export_mimetype
{
	my( $self ) = @_;

	return $self->{processor}->{export_plugin}->param("mimetype") 
}






1;
