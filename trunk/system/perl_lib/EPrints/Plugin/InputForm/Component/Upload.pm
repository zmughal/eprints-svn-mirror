package EPrints::Plugin::InputForm::Component::Upload;

use EPrints;
use EPrints::Plugin::InputForm::Component;
@ISA = ( "EPrints::Plugin::InputForm::Component" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Upload";
	$self->{visible} = "all";
	$self->{surround} = "None" unless defined $self->{surround};
	# a list of documents to unroll when rendering, 
	# this is used by the POST processing, not GET

	return $self;
}

# only returns a value if it belongs to this component
sub update_from_form
{
	my( $self, $processor ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{workflow}->{item};
	my @eprint_docs = $eprint->get_all_documents;

	foreach my $doc ( @eprint_docs )
	{	
		my @fields = $self->doc_fields( $doc );
		my $docid = $doc->get_id;
		my $doc_prefix = $self->{prefix}."_doc".$docid;
		foreach my $field ( @fields )
		{
			my $value = $field->form_value( 
				$session, 
				$self->{dataobj}, 
				$doc_prefix );
			$doc->set_value( $field->{name}, $value );
		}
		$doc->commit;
	}

	if( $session->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;
		if( $internal =~ m/^add_format_(.+)$/ )
		{
			my $method = $1;
			my @plugins = $self->_get_upload_plugins(
					prefix => $self->{prefix},
					dataobj => $self->{dataobj},
				);
			foreach my $plugin (@plugins)
			{
				if( $plugin->get_id eq $method )
				{
					$plugin->update_from_form( $processor );
					return;
				}
			}
			EPrints::abort( "'$method' is not a supported upload method" );
		}
		if( $internal =~ m/^doc(\d+)_(.+)$/ )
		{
			my( $docid, $doc_action ) = ($1, $2);
			my $doc;
			for(@eprint_docs)
			{
				$doc = $_, last if $_->get_id == $docid;
			}
			if( !defined $doc )
			{
				$processor->add_message( "error", $self->html_phrase( "no_document", docid => $session->make_text($docid) ) );
				return;
			}
			$self->doc_update( $doc, $doc_action, \@eprint_docs, $processor );
			return;
		}

		$processor->add_message( "error",$self->html_phrase( "bad_button", button => $self->{session}->make_text($internal) ));
		return;
	}

	return;
}

sub get_state_params
{
	my( $self, $processor ) = @_;

	my $params = "";

	my $tounroll = {};
	if( $processor->{notes}->{upload_plugin}->{to_unroll} )
	{
		$tounroll = $processor->{notes}->{upload_plugin}->{to_unroll};
	}
	if( $self->{session}->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;
		# modifying existing document
		if( $internal =~ m/^doc(\d+)_(.*)$/ )
		{
			$tounroll->{$1} = 1;
		}
	}
	if( scalar keys %{$tounroll} )
	{
		$params .= "&".$self->{prefix}."_view=".join( ",", keys %{$tounroll} );
	}

	return $params;
}

sub _swap_placements
{
	my( $docs, $l, $r ) = @_;

	my( $left, $right ) = @$docs[$l,$r];

	my $t = $left->get_value( "placement" );
	$left->set_value( "placement", $right->get_value( "placement" ) );
	$right->set_value( "placement", $t );

	$t = $docs->[$l];
	$docs->[$l] = $docs->[$r];
	$docs->[$r] = $t;
}

sub doc_update
{
	my( $self, $doc, $doc_internal, $eprint_docs, $processor ) = @_;

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;
	$processor->{notes}->{upload_plugin}->{to_unroll}->{$docid} = 1;
	
	if( $doc_internal eq "up" or $doc_internal eq "down" )
	{
		return if scalar @$eprint_docs < 2;
		foreach my $eprint_doc (@$eprint_docs)
		{
			next if $eprint_doc->is_set( "placement" );
			$eprint_doc->set_value( "placement", $eprint_doc->get_value( "pos" ) );
		}
		my $loc;
		for($loc = 0; $loc < @$eprint_docs; ++$loc)
		{
			last if $eprint_docs->[$loc]->get_id == $doc->get_id;
		}
		if( $doc_internal eq "up" )
		{
			if( $loc == 0 )
			{
				for(my $i = 0; $i < $#$eprint_docs; ++$i)
				{
					_swap_placements( $eprint_docs, $i, $i+1 );
				}
			}
			else
			{
				_swap_placements( $eprint_docs, $loc, $loc-1 );
			}
		}
		if( $doc_internal eq "down" )
		{
			if( $loc == $#$eprint_docs )
			{
				for(my $i = $#$eprint_docs; $i > 0; --$i)
				{
					_swap_placements( $eprint_docs, $i, $i-1 );
				}
			}
			else
			{
				_swap_placements( $eprint_docs, $loc, $loc+1 );
			}
		}
		# We don't need to create lots of commits on the parent eprint
		my $eprint = $eprint_docs->[0]->get_parent;
		$eprint->set_under_construction( 1 );
		$_->commit() for @$eprint_docs;
		$eprint->set_under_construction( 0 );
		$eprint->commit(1);
		return;
	}

	if( $doc_internal eq "update_doc" )
	{
		return;
	}

	if( $doc_internal eq "delete_doc" )
	{
		$doc->remove();
		return;
	}

	if( $doc_internal eq "add_file" )
	{
		my $success = EPrints::Apache::AnApache::upload_doc_file( 
			$self->{session},
			$doc,
			$doc_prefix."_file" );
		if( !$success )
		{
			$processor->add_message( "error", $self->html_phrase( "upload_failed" ) );
			return;
		}
		return;
	}

	if( $doc_internal =~ m/^delete_(\d+)$/ )
	{
		my $fileid = $1;
		
		my %files_unsorted = $doc->files();
		my @files = sort keys %files_unsorted;

		if( !defined $files[$fileid] )
		{
			$processor->add_message( "error", $self->html_phrase( "no_file" ) );
			return;
		}
		
		$doc->remove_file( $files[$fileid] );
		return;
	}

	if( $doc_internal eq "convert_document" )
	{
		my $eprint = $self->{workflow}->{item};
		my $target = $self->{session}->param( $doc_prefix . "_convert_to" );
		$target ||= '-';
		my( $plugin_id, $type ) = split /-/, $target, 2;
		my $plugin = $self->{session}->plugin( $plugin_id );
		if( !$plugin )
		{
			$processor->add_message( "error", $self->html_phrase( "plugin_error" ) );
			return;
		}
		my $new_doc = $plugin->convert( $eprint, $doc, $type );
		if( !$new_doc )
		{
			$processor->add_message( "error", $self->html_phrase( "conversion_failed" ) );
			return;
		}
		$doc->remove_object_relations(
				$new_doc,
				EPrints::Utils::make_relation( "hasVolatileVersion" ) =>
				EPrints::Utils::make_relation( "isVolatileVersionOf" )
			);
		$new_doc->make_thumbnails();
		$doc->commit();
		$new_doc->commit();
		return;
	}

	if( $doc_internal =~ m/^main_(\d+)$/ )
	{
		my $fileid = $1;

		my %files_unsorted = $doc->files();
		my @files = sort keys %files_unsorted;

		if( !defined $files[$fileid] )
		{
			$processor->add_message( "error", $self->html_phrase( "no_file" ) );
			return;
		}
		
		# Pressed "Show First" button for this file
		$doc->set_main( $files[$fileid] );
		$doc->commit;
		return ();
	}
			
	$processor->add_message( "error", $self->html_phrase( "bad_doc_button", button => $self->{session}->make_text($doc_internal) ) );
}
	
sub render_help
{
	my( $self, $surround ) = @_;
	return $self->html_phrase( "help" );
}

sub render_title
{
	my( $self, $surround ) = @_;
	return $self->html_phrase( "title" );
}

# hmmm. May not be true!
sub is_required
{
	my( $self ) = @_;
	return 1;
}

sub get_fields_handled
{
	my( $self ) = @_;

	return ( "documents" );
}

sub render_content
{
	my( $self, $surround ) = @_;
	
	my $session = $self->{session};
	my $f = $session->make_doc_fragment;
	
	$f->appendChild( $self->_render_add_document );	

	my $eprint = $self->{workflow}->{item};
	my @eprint_docs = $eprint->get_all_documents;

	if( ! scalar @eprint_docs )
	{
		return $f;
	}

	my $tounroll = {};
	my $tounrollparam = $self->{session}->param( $self->{prefix}."_view" );
	if( EPrints::Utils::is_set( $tounrollparam ) )
	{
		foreach my $docid ( split( ",", $tounrollparam ) )
		{
			$tounroll->{$docid} = 1;
		}
	}

	# this overrides the prefix-dependent view. It's used when
	# we're coming in from outside the form and is, to be honest,
	# a dirty little hack.
	if( defined $session->param( "docid" ) )
	{
		$tounroll->{$session->param( "docid" )} = 1;
	}

	my $panel = $self->{session}->make_element( "div", id=>$self->{prefix}."_panels" );
	$f->appendChild( $panel );

	my $imagesurl = $session->get_repository->get_conf( "rel_path" );

	# sort by doc id?	
	foreach my $doc ( @eprint_docs )
	{	
		my $view_id = $doc->get_id;
		my $doc_prefix = $self->{prefix}."_doc".$view_id;
		my $hide = 1;
		if( scalar @eprint_docs == 1 ) { $hide = 0; } 
		if( $tounroll->{$view_id} ) { $hide = 0; }
		my $doc_div = $self->{session}->make_element( "div", class=>"ep_upload_doc", id=>$doc_prefix."_block" );
		$panel->appendChild( $doc_div );
		my $doc_title_bar = $session->make_element( "div", class=>"ep_upload_doc_title_bar" );


		my $table = $session->make_element( "table", width=>"100%", border=>0 );
		my $tr = $session->make_element( "tr" );
		$doc_title_bar->appendChild( $table );
		$table->appendChild( $tr );
		my $td_left = $session->make_element( "td", align=>"left", valign=>"middle", width=>"40%" );
		$tr->appendChild( $td_left );

		my $table_left = $session->make_element( "table", border=>0 );
		$td_left->appendChild( $table_left );
		my $table_left_tr = $session->make_element( "tr" );
		my $table_left_td_left = $session->make_element( "td", align=>"center" );
		my $table_left_td_right = $session->make_element( "td", align=>"left", class=>"ep_upload_doc_title" );
		$table_left->appendChild( $table_left_tr );
		$table_left_tr->appendChild( $table_left_td_left );
		$table_left_tr->appendChild( $table_left_td_right );
		
		$table_left_td_left->appendChild( $doc->render_icon_link( new_window=>1, preview=>1, public=>0 ) );

		$table_left_td_right->appendChild( $doc->render_citation);
		my %files = $doc->files;
		if( defined $files{$doc->get_main} )
		{
			my $size = $files{$doc->get_main};
			$table_left_td_right->appendChild( $session->make_element( 'br' ) );
			$table_left_td_right->appendChild( $session->make_text( EPrints::Utils::human_filesize($size) ));
		}

		my $td_centre = $session->make_element( "td", align=>"center", valign=>"middle", width=>"40%" );
		$tr->appendChild( $td_centre );
		$td_centre->appendChild( $self->_render_doc_placement( $doc, \@eprint_docs ) );

		my $td_right = $session->make_element( "td", align=>"right", valign=>"middle", width=>"20%" );
		$tr->appendChild( $td_right );

		my $options = $session->make_element( "div", class=>"ep_update_doc_options ep_only_js" );
		my $opts_toggle = $session->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${doc_prefix}_opts',".($hide?"false":"true").",'${doc_prefix}_block');EPJS_toggle('${doc_prefix}_opts_hide',".($hide?"false":"true").",'block');EPJS_toggle('${doc_prefix}_opts_show',".($hide?"true":"false").",'block');return false", href=>"#" );
		$options->appendChild( $opts_toggle );
		$td_right->appendChild( $options );

		my $s_options = $session->make_element( "span", id=>$doc_prefix."_opts_show", class=>"ep_update_doc_options ".($hide?"":"ep_hide") );
		$s_options->appendChild( $self->html_phrase( "show_options" ) );
		$s_options->appendChild( $session->make_text( " " ) );
		$s_options->appendChild( 
			$session->make_element( "img",
				src=>"$imagesurl/style/images/plus.png",
				) );
		$opts_toggle->appendChild( $s_options );

		my $h_options = $session->make_element( "span", id=>$doc_prefix."_opts_hide", class=>"ep_update_doc_options ".($hide?"ep_hide":"") );
		$h_options->appendChild( $self->html_phrase( "hide_options" ) );
		$h_options->appendChild( $session->make_text( " " ) );
		$h_options->appendChild( 
			$session->make_element( "img",
				src=>"$imagesurl/style/images/minus.png",
				) );
		$opts_toggle->appendChild( $h_options );


		#$doc_title->appendChild( $doc->render_description );
		$doc_div->appendChild( $doc_title_bar );
	
		my $content = $session->make_element( "div", id=>$doc_prefix."_opts", class=>"ep_upload_doc_content ".($hide?"ep_no_js":"") );
		my $content_inner = $self->{session}->make_element( "div", id=>$doc_prefix."_opts_inner" );
		$content_inner->appendChild( $self->_render_doc( $doc ) );
		$content->appendChild( $content_inner );
		$doc_div->appendChild( $content );
	}
	
	return $f;
}

sub doc_fields
{
	my( $self, $document ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset('document');
	my @fields = @{$self->{config}->{doc_fields}};

	my %files = $document->files;
	if( scalar keys %files > 1 )
	{
		push @fields, $ds->get_field( "main" );
	}
	
	return @fields;
}

sub _render_doc_placement
{
	my( $self, $doc, $eprint_docs ) = @_;

	my $session = $self->{session};	

	my $frag = $session->make_doc_fragment;

	return $frag unless scalar @$eprint_docs > 1;

	my $prefix = $self->{prefix};

	if( $doc->get_id != $eprint_docs->[0]->get_id )
	{
		my $up_button = $session->render_button(
			name => "_internal_".$prefix."_doc".$doc->get_id."_up",
			value => $self->phrase( "move_up" ), 
			class => "ep_form_internal_button",
			);
		$frag->appendChild( $up_button );
	}
	if( $doc->get_id != $eprint_docs->[$#$eprint_docs]->get_id )
	{
		my $down_button = $session->render_button(
			name => "_internal_".$prefix."_doc".$doc->get_id."_down",
			value => $self->phrase( "move_down" ), 
			class => "ep_form_internal_button",
			);
		$frag->appendChild( $down_button );
	}

	return $frag;
}

sub _render_doc
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};	

	my $doc_cont = $session->make_element( "div" );


	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my @fields = $self->doc_fields( $doc );

	if( scalar @fields )
	{
		my $table = $session->make_element( "table", class=>"ep_upload_fields ep_multi" );
		$doc_cont->appendChild( $table );
		my $first = 1;
		foreach my $field ( @fields )
		{
			my $label = $field->render_name($session);
			if( $field->{required} ) # moj: Handle for_archive
			{
				$label = $self->{session}->html_phrase( 
					"sys:ep_form_required",
					label=>$label );
			}
 
			$table->appendChild( $session->render_row_with_help(
				class=>($first?"ep_first":""),
				label=>$label,
				field=>$field->render_input_field(
                                	$session,
                                	$doc->get_value( $field->get_name ),
                                	undef,
                                	0,
                                	undef,
                                	$doc,
                                	$doc_prefix ),
				help=>$field->render_help($session),
				help_prefix=>$doc_prefix."_".$field->get_name."_help",
			));
			$first = 0;
		}
	}

	my $tool_div = $session->make_element( "div", class=>"ep_upload_doc_toolbar" );

	my $update_button = $session->render_button(
		name => "_internal_".$doc_prefix."_update_doc",
		value => $self->phrase( "update" ), 
		class => "ep_form_internal_button",
		);
	$tool_div->appendChild( $update_button );

	my $msg = $self->phrase( "delete_document_confirm" );
	my $delete_fmt_button = $session->render_button(
		name => "_internal_".$doc_prefix."_delete_doc",
		value => $self->phrase( "delete_document" ), 
		class => "ep_form_internal_button",
		onclick => "if( window.event ) { window.event.cancelBubble = true; } return confirm(".EPrints::Utils::js_string($msg).");",
		);
	$tool_div->appendChild( $delete_fmt_button );

	$doc_cont->appendChild( $tool_div );



	my $files = $session->make_element( "div", class=>"ep_upload_files" );
	$doc_cont->appendChild( $files );
	$files->appendChild( $self->_render_filelist( $doc ) );
	my $block = $session->make_element( "div", class=>"ep_block" );
	$block->appendChild( $self->_render_add_file( $doc ) );
	$doc_cont->appendChild( $block );
	$block = $session->make_element( "div", class=>"ep_block" );
	$block->appendChild( $self->_render_convert_document( $doc ) );
	$doc_cont->appendChild( $block );

	return $doc_cont;
}
			

sub _render_add_document
{
	my( $self ) = @_;

	my $session = $self->{session};

	my @methods = $self->_get_upload_plugins(
			prefix => $self->{prefix},
			dataobj => $self->{dataobj}
		);

	my $add = $session->make_doc_fragment;

	# no upload methods so don't do anything
	return $add if @methods == 0;

	my $tabs = [];
	my $labels = {};
	my $links = {};
	foreach my $plugin ( @methods )
	{
		my $name = $plugin->get_id;
		push @$tabs, $name;
		$labels->{$name} = $plugin->render_tab_title();
		$links->{$name} = "";
	}

	my $newdoc = $self->{session}->make_element( 
			"div", 
			class => "ep_upload_newdoc" );
	$add->appendChild( $newdoc );
	my $tab_block = $session->make_element( "div", class=>"ep_only_js" );	
	$tab_block->appendChild( 
		$self->{session}->render_tabs( 
			id_prefix => $self->{prefix}."_upload",
			current => $tabs->[0],
			tabs => $tabs,
			labels => $labels,
			links => $links,
		));
	$newdoc->appendChild( $tab_block );
		
	my $panel = $self->{session}->make_element( 
			"div", 
			id => $self->{prefix}."_upload_panels", 
			class => "ep_tab_panel" );
	$newdoc->appendChild( $panel );

	my $first = 1;
	foreach my $plugin ( @methods )
	{
		my $inner_panel;
		if( $first )
		{
			$inner_panel = $self->{session}->make_element( 
				"div", 
				id => $self->{prefix}."_upload_panel_".$plugin->get_id );
		}
		else
		{
			# padding for non-javascript enabled browsers
			$panel->appendChild( 
				$session->make_element( "div", style=>"height: 1em", class=>"ep_no_js" ) );
			$inner_panel = $self->{session}->make_element( 
				"div", 
				class => "ep_no_js",
				id => $self->{prefix}."_upload_panel_".$plugin->get_id );	
		}
		$panel->appendChild( $inner_panel );

		$inner_panel->appendChild( $plugin->render_add_document() );
		$first = 0;
	}

	return $add;
}


sub _render_add_file
{
	my( $self, $document ) = @_;

	my $session = $self->{session};
	
	# Create a document-specific prefix
	my $docid = $document->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $hide = 0;
	my %files = $document->files;
	$hide = 1 if( scalar keys %files == 1 );

	my $f = $session->make_doc_fragment;	
	if( $hide )
	{
		my $hide_add_files = $session->make_element( "div", id=>$doc_prefix."_af1" );
		my $show = $self->{session}->make_element( "a", class=>"ep_only_js", href=>"#", onclick => "EPJS_blur(event); if(!confirm(".EPrints::Utils::js_string($self->phrase("really_add")).")) { return false; } EPJS_toggle('${doc_prefix}_af1',true);EPJS_toggle('${doc_prefix}_af2',false);return false", );
		$hide_add_files->appendChild( $self->html_phrase( 
			"add_files",
			link=>$show ));
		$f->appendChild( $hide_add_files );
	}

	my %l = ( id=>$doc_prefix."_af2", class=>"ep_upload_add_file_toolbar" );
	$l{class} .= " ep_no_js" if( $hide );
	my $toolbar = $session->make_element( "div", %l );
	my $file_button = $session->make_element( "input",
		name => $doc_prefix."_file",
		id => "filename",
		type => "file",
		);
	my $upload_button = $session->render_button(
		name => "_internal_".$doc_prefix."_add_file",
		class => "ep_form_internal_button",
		value => $self->phrase( "add_file" ),
		);
	$toolbar->appendChild( $file_button );
	$toolbar->appendChild( $session->make_text( " " ) );
	$toolbar->appendChild( $upload_button );
	$f->appendChild( $toolbar );

	return $f; 
}

sub _render_convert_document
{
	my( $self, $document ) = @_;

	my $session = $self->{session};
	
	# Create a document-specific prefix
	my $docid = $document->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $convert_plugin = $session->plugin( 'Convert' );

	my $dataset = $document->get_dataset();
	my $field = $dataset->get_field( 'format' );
	my %document_formats = map { ($_ => 1) } $field->tags( $session );

	my %available = $convert_plugin->can_convert( $document );

	# Only provide conversion for plugins that
	#  1) Provide a phrase (i.e. are public-facing)
	#  2) Provide a conversion to a format in document_types
	foreach my $type (keys %available)
	{
		unless( exists($available{$type}->{'phraseid'}) and
				exists($document_formats{$type}) )
		{
			delete $available{$type}
		}
	}

	my $f = $session->make_doc_fragment;	

	unless( scalar(%available) )
	{
		return $f;
	}

	my $select_button = $session->make_element( "select",
		name => $doc_prefix."_convert_to",
		id => "format",
		);
	my $option = $session->make_element( "option" );
	$select_button->appendChild( $option );
	# Use $available{$a}->{preference} for ordering?
	foreach my $type (keys %available)
	{
		my $plugin_id = $available{$type}->{ "plugin" }->get_id();
		my $phrase_id = $available{$type}->{ "phraseid" };
		my $option = $session->make_element( "option",
			value => $plugin_id . '-' . $type
		);
		$option->appendChild( $session->html_phrase( $phrase_id ));
		$select_button->appendChild( $option );
	}
	my $upload_button = $session->render_button(
		name => "_internal_".$doc_prefix."_convert_document",
		class => "ep_form_internal_button",
		value => $self->phrase( "convert_document_button" ),
		);

	my $table = $session->make_element( "table", class=>"ep_multi" );
	$f->appendChild( $table );

	my %l = ( id=>$doc_prefix."_af2", class=>"ep_convert_document_toolbar" );
	my $toolbar = $session->make_element( "div", %l );

	$toolbar->appendChild( $select_button );
	$toolbar->appendChild( $session->make_text( " " ) );
	$toolbar->appendChild( $upload_button );

	$table->appendChild( $session->render_row_with_help(
				label=>$self->html_phrase( "convert_document" ),
				field=>$toolbar,
				help=>$self->html_phrase( "convert_document_help" ),
				help_prefix=>$doc_prefix."_convert_document_help",
				));

	return $f; 
}



sub _render_filelist
{
	my( $self, $document ) = @_;

	my $session = $self->{session};
	
	if( !defined $document )
	{
		EPrints::abort( "No document for file upload component" );
	}
	
	my %files = $document->files;
	my $main_file = $document->get_main;
	my $num_files = scalar keys %files;
	
	my $docid = $document->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $table = $session->make_element( "table", class => "ep_upload_file_table" );
	my $tbody = $session->make_element( "tbody" );
	$table->appendChild( $tbody );

	if( !defined $document || $num_files == 0 ) 
	{
		$tbody->appendChild( $self->_render_placeholder );
		return $table;
	}

	my $imagesurl = $session->get_repository->get_conf( "rel_path" );

	my $i = 0;
	foreach my $filename ( sort keys %files )
	{
		my $tr = $session->make_element( "tr" );
	
		my $td_filename = $session->make_element( "td" );
		my $a = $session->render_link( $document->get_url( $filename ), "_blank" );
		$a->appendChild( $session->make_text( $filename ) );
		
		$td_filename->appendChild( $a );
		$tr->appendChild( $td_filename );
		
		my $td_filesize = $session->make_element( "td" );
		my $size = EPrints::Utils::human_filesize( $files{$filename} );
		$size =~ m/^([0-9]+)([^0-9]*)$/;
		my( $n, $units ) = ( $1, $2 );
		$td_filesize->appendChild( $session->make_text( $n ) );
		$td_filesize->appendChild( $session->make_text( $units ) );
		$tr->appendChild( $td_filesize );
		
		my $td_delete = $session->make_element( "td" );
		my $del_btn_text = $session->html_phrase( "lib/submissionform:delete" );
		my $del_btn = $session->make_element( "input", 
			type => "image", 
			src => "$imagesurl/style/images/delete.png",
			name => "_internal_".$doc_prefix."_delete_$i",
			onclick => "EPJS_blur(event); return confirm( ".EPrints::Utils::js_string($self->phrase( "delete_file_confirm", filename => $filename ))." );",
			value => $self->phrase( "delete_file" ) );
			
		$td_delete->appendChild( $del_btn );
		$tr->appendChild( $td_delete );
		
#		my $td_filetype = $session->make_element( "td" );
#		$td_filetype->appendChild( $session->make_text( "" ) );
#		$tr->appendChild( $td_filetype );
			
		$tbody->appendChild( $tr );
		$i++;
	}
	
	return $table;
}

sub _render_placeholder
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $placeholder = $session->make_element( "tr", id => "placeholder" );
	my $td = $session->make_element( "td", colspan => "3" );
	$td->appendChild( $self->html_phrase( "upload_blurb" ) );
	$placeholder->appendChild( $td );
	return $placeholder;
}

sub validate
{
	my( $self ) = @_;
	
	my @problems = ();

	my $for_archive = $self->{workflow}->{for_archive};

	my $eprint = $self->{workflow}->{item};
	my $session = $self->{session};
	
        my @req_formats = $eprint->required_formats;
	my @docs = $eprint->get_all_documents;

	my $ok = 0;
	$ok = 1 if( scalar @req_formats == 0 );

	my $doc;
	foreach $doc ( @docs )
        {
		my $docformat = $doc->get_value( "format" );
		foreach( @req_formats )
		{
                	$ok = 1 if( $docformat eq $_ );
		}
        }

	if( !$ok )
	{
		my $doc_ds = $eprint->{session}->get_repository->get_dataset( 
			"document" );
		my $fieldname = $eprint->{session}->make_element( "span", class=>"ep_problem_field:documents" );
		my $prob = $eprint->{session}->make_doc_fragment;
		$prob->appendChild( $eprint->{session}->html_phrase( 
			"lib/eprint:need_a_format",
			fieldname=>$fieldname ) );
		my $ul = $eprint->{session}->make_element( "ul" );
		$prob->appendChild( $ul );
		
		foreach( @req_formats )
		{
			my $li = $eprint->{session}->make_element( "li" );
			$ul->appendChild( $li );
			$li->appendChild( $eprint->{session}->render_type_name( "document", $_ ) );
		}
			
		push @problems, $prob;

	}

	foreach $doc (@docs)
	{
		my $probs = $doc->validate( $for_archive );

		foreach my $field ( @{$self->{config}->{doc_fields}} )
		{
			my $for_archive = 0;
			
			if( $field->{required} eq "for_archive" )
			{
				$for_archive = 1;
			}

			# cjg bug - not handling for_archive here.
			if( $field->{required} && !$doc->is_set( $field->{name} ) )
			{
				my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:documents" );
				$fieldname->appendChild( $field->render_name( $self->{session} ) );
				my $problem = $self->{session}->html_phrase(
					"lib/eprint:not_done_field" ,
					fieldname=>$fieldname );
				push @{$probs}, $problem;
			}
			
			push @{$probs}, $doc->validate_field( $field->{name} );
		}

		foreach my $doc_problem (@$probs)
		{
			my $prob = $self->html_phrase( "document_problem",
					document => $doc->render_description,
					problem =>$doc_problem );
			push @problems, $prob;
		}
	}

	return @problems;
}

sub _get_upload_plugins
{
	my( $self, %opts ) = @_;

	my %plugins;

	my @plugins;
	if( defined $self->{config}->{methods} )
	{
		METHOD: foreach my $method (@{$self->{config}->{methods}})
		{
			my $plugin = $self->{session}->plugin( "InputForm::UploadMethod::$method", %opts );
			if( !defined $plugin )
			{
				$self->{session}->get_repository->log( "Unknown upload method in Component::Upload: '$method'" );
				next METHOD;
			}
			push @plugins, $plugin;
		}
	}
	else
	{
		METHOD: foreach my $plugin ( $self->{session}->plugin_list( type => 'InputForm' ) )
		{
			$plugin = $self->{session}->plugin( $plugin, %opts );
			next METHOD if !$plugin->isa( "EPrints::Plugin::InputForm::UploadMethod" );
			next METHOD if ref($plugin) eq "EPrints::Plugin::InputForm::UploadMethod";
			push @plugins, $plugin;
		}
	}

	foreach my $plugin ( @plugins )
	{
		foreach my $appearance ( @{$plugin->{appears}} )
		{
			$plugins{ref($plugin)} = [$appearance->{position},$plugin];
		}
	}

	return
		map { $plugins{$_}->[1] }
		sort { $plugins{$a}->[0] <=> $plugins{$b}->[0] || $a cmp $b }
		keys %plugins;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;

	$self->{config}->{doc_fields} = [];

# moj: We need some default phrases for when these aren't specified.
#	$self->{config}->{title} = ""; 
#	$self->{config}->{help} = ""; 

	my @fields = $config_dom->getElementsByTagName( "field" );

	my $doc_ds = $self->{session}->get_repository->get_dataset( "document" );

	foreach my $field_tag ( @fields )
	{
		my $field = $self->xml_to_metafield( $field_tag, $doc_ds );
		push @{$self->{config}->{doc_fields}}, $field;
	}

	my @uploadmethods = $config_dom->getElementsByTagName( "upload-methods" );
	if( defined $uploadmethods[0] )
	{
		$self->{config}->{methods} = [];

		my @methods = $uploadmethods[0]->getElementsByTagName( "method" );
	
		foreach my $method_tag ( @methods )
		{	
			my $method = EPrints::XML::to_string( EPrints::XML::contents_of( $method_tag ) );
			push @{$self->{config}->{methods}}, $method;
		}
	}

}


1;
