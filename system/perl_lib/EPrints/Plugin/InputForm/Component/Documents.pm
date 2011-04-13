=head1 NAME

EPrints::Plugin::InputForm::Component::Documents

=cut

package EPrints::Plugin::InputForm::Component::Documents;

use EPrints::Plugin::InputForm::Component;
@ISA = ( "EPrints::Plugin::InputForm::Component" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Documents";
	$self->{visible} = "all";
	$self->{surround} = "None" unless defined $self->{surround};
	# a list of documents to unroll when rendering, 
	# this is used by the POST processing, not GET

	if( defined $self->{session} )
	{
		$self->{imagesurl} = $self->{session}->get_url( path => "static" );
	}

	return $self;
}

sub wishes_to_export
{
	my( $self ) = @_;

	return $self->{session}->param( $self->{prefix} . "_export" );
}

# only returns a value if it belongs to this component
sub update_from_form
{
	my( $self, $processor ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{workflow}->{item};
	# cache documents
	$eprint->set_value( "documents", $eprint->value( "documents" ) );
	my @eprint_docs = $eprint->get_all_documents;

	my %update = map { $_ => 1 } $session->param( $self->{prefix} . "_update_doc" );

	# update the metadata for any documents that have metadata
	foreach my $doc ( @eprint_docs )
	{
		# check the page we're coming from included this document
		next if !$update{$doc->id};

		my $doc_prefix = $self->{prefix}."_doc".$doc->id;

		my @fields = $self->doc_fields( $doc );
		# "main" is pseudo-hidden on the files tab
		push @fields, $doc->dataset->field( "main" );

		foreach my $field ( @fields )
		{
			my $value = $field->form_value( 
				$session, 
				$eprint,
				$doc_prefix );
			$doc->set_value( $field->{name}, $value );
		}

		$doc->commit;
	}
	
	if( $session->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;
		if( $internal =~ m/^doc(\d+)_(.+)$/ )
		{
			my( $docid, $doc_action ) = ($1, $2);
			my $doc = $session->dataset( "document" )->dataobj( $docid );
			if( !defined $doc || $doc->value( "eprintid" ) ne $eprint->id )
			{
				$processor->add_message( "error", $self->html_phrase( "no_document", docid => $session->make_text($docid) ) );
				return;
			}
			$self->_doc_update( $processor, $doc, $doc_action, \@eprint_docs );
			return;
		}
		elsif( $internal eq "reorder" )
		{
			$self->_reorder( $processor );
		}
	}

	return;
}

sub get_state_params
{
	my( $self, $processor ) = @_;

	my $params = "";

	my $to_unroll = $processor->{notes}->{upload_plugin}->{to_unroll};
	$to_unroll = {} if !defined $to_unroll;

	my %update = map { $_ => 1 } $self->{session}->param( $self->{prefix} . "_update_doc" );

	my $eprint = $self->{workflow}->{item};
	my @eprint_docs = $eprint->get_all_documents;
	foreach my $doc ( @eprint_docs )
	{
		my $doc_prefix = $self->{prefix}."_doc".$doc->id;

		# check the page we're coming from included this document
		next if !$update{$doc->id};

		my @fields = $self->doc_fields( $doc );
		foreach my $field ( @fields )
		{
			$params .= $field->get_state_params( $self->{session}, $doc_prefix );
			if( $field->has_internal_action( $doc_prefix ) )
			{
				$to_unroll->{$doc->id} = 1;
			}
		}
	}

	foreach my $docid (keys %$to_unroll)
	{
		$params .= "&$self->{prefix}_view=$docid";
	}

	return $params;
}

sub get_state_fragment
{
	my( $self, $processor ) = @_;

	my $to_unroll = $processor->{notes}->{upload_plugin}->{to_unroll};
	$to_unroll = {} if !defined $to_unroll;

	my %update = map { $_ => 1 } $self->{session}->param( $self->{prefix} . "_update_doc" );

	my $eprint = $self->{workflow}->{item};
	foreach my $doc ( $eprint->get_all_documents )
	{
		my $doc_prefix = $self->{prefix}."_doc".$doc->id;
		return $doc_prefix if $to_unroll->{$doc->id};

		# check the page we're coming from included this document
		next if !$update{$doc->id};

		my @fields = $self->doc_fields( $doc );
		foreach my $field ( @fields )
		{
			if( $field->has_internal_action( $doc_prefix ) )
			{
				return $doc_prefix;
			}
		}
	}

	return "";
}

sub _doc_update
{
	my( $self, $processor, $doc, $doc_internal, $eprint_docs ) = @_;

	local $processor->{document} = $doc;
	my $plugin;
	foreach my $params ($processor->screen->action_list( "document_item_actions" ))
	{
		$plugin = $params->{screen}, last
			if $params->{screen}->get_subtype eq $doc_internal;
	}
	return if !defined $plugin;

	my $uri = URI->new( $self->{session}->current_url( host => 1 ) );
	$uri->query_form(
		$processor->screen->hidden_bits
	);
	my $return_to = $uri->query;

	if( $plugin->param( "ajax" ) && $self->wishes_to_export )
	{
		$self->set_note( "document", $doc );
		$self->set_note( "action", $plugin );
		$self->set_note( "return_to", $return_to );
		return;
	}

	$uri->query_form(
		screen => $plugin->get_subtype,
		eprintid => $self->{workflow}->{item}->id,
		documentid => $doc->id,
		return_to => $return_to,
	);
	$processor->{redirect} = $uri;
}

sub _reorder
{
	my( $self, $processor ) = @_;

	my @order = $self->{session}->param( join('_',$self->{prefix},'order') );
	return if !@order;

	my @docs = $self->{workflow}->{item}->get_all_documents;
	my %docids = map { $_->id => 1 } @docs;

	@order = grep { $docids{$_} } @order;
	return if !@order;

	my $i = 1;
	my %order = map { $_ => $i++ } @order;

	foreach my $doc (@docs)
	{
		$doc->set_value( "placement", $order{$doc->id} || $i++ );
		$doc->commit;
	}
}

sub has_help
{
	my( $self, $surround ) = @_;
	return $self->{session}->get_lang->has_phrase( $self->html_phrase_id( "help" ) );
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
	return 0;
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
	my $eprint = $self->{workflow}->{item};
	# cache documents
	$eprint->set_value( "documents", $eprint->value( "documents" ) );

	my $f = $session->make_doc_fragment;
	
	my $script = $f->appendChild( $self->{session}->make_element(
		"script",
		type => "text/javascript",
	) );
	$script->appendChild( $self->{session}->make_text(
		"Event.observe(window, 'load', function() { new Component_Documents('".$self->{prefix}."') });"
	) );

	@{$self->{docs}} = $eprint->get_all_documents;

	my %unroll = map { $_ => 1 } $session->param( $self->{prefix}."_view" );

	# this overrides the prefix-dependent view. It's used when
	# we're coming in from outside the form and is, to be honest,
	# a dirty little hack.
	if( defined(my $docid = $session->param( "docid" ) ) )
	{
		$unroll{$docid} = 1;
	}

	my $panel = $session->make_element( "div",
		id=>$self->{prefix}."_panels",
		class=>"Component_Documents",
	);
	$f->appendChild( $panel );

	foreach my $doc ( @{$self->{docs}} )
	{
		my $hide = 1;
		if( @{$self->{docs}} == 1 || $unroll{$doc->id} )
		{
			$hide = 0;
		}

		$panel->appendChild( $self->_render_doc_div( $doc, $hide ));
	}

	return $f;
}

sub export_mimetype
{
	my( $self ) = @_;

	my $plugin = $self->note( "action" );
	if( defined($plugin) && $plugin->param( "ajax" ) eq "automatic" )
	{
		return $plugin->export_mimetype;
	}

	binmode(STDOUT, ":utf8");

	# always text/html because we only do AJAX
	return "text/html; charset=UTF-8";
}

sub export
{
	my( $self ) = @_;

	my $frag;

	if( defined(my $plugin = $self->note( "action" )) )
	{
		local $self->{processor}->{document} = $self->note( "document" );
		if( $plugin->param( "ajax" ) eq "automatic" )
		{
			$plugin->from; # call actions
			delete $self->{processor}->{redirect}; # exports don't redirect
			return $plugin->export; # generate the export
		}
		local $self->{processor}->{return_to} = $self->note( "return_to" );
		$frag = $plugin->render;
	}
	else
	{
		my $docid = $self->{session}->param( $self->{prefix} . '_export' );
		return unless $docid;

		my $doc = $self->{session}->dataset( "document" )->dataobj( $docid );
		return $self->{session}->not_found if !defined $doc;

		return if $doc->value( "eprintid" ) != $self->{workflow}->{item}->id;

		$frag = $self->_render_doc_div( $doc, 1 ); # hide
	}

	print $self->{session}->xhtml->to_xhtml( $frag );
	$self->{session}->xml->dispose( $frag );
}

sub _render_doc_div 
{
	my( $self, $doc, $hide ) = @_;

	my $session = $self->{session};
	my $eprint_docs = $self->{docs};

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $files = $doc->get_value( "files" );
	do {
		my %idx = map { $_ => $_->value( "filename" ) } @$files;
		@$files = sort { $idx{$a} cmp $idx{$b} } @$files;
	};

	my $doc_div = $self->{session}->make_element( "div", class=>"ep_upload_doc", id=>$doc_prefix."_block" );

	# provide <a> link to this document
	$doc_div->appendChild( $session->make_element( "a", name=>$doc_prefix ) );

	# note which documents should be updated
	$doc_div->appendChild( $session->render_hidden_field( $self->{prefix}."_update_doc", $docid ) );

	# note the document placement
	$doc_div->appendChild( $session->render_hidden_field( $self->{prefix}."_doc_placement", $doc->value( "placement" ) ) );

	my $doc_title_bar = $session->make_element( "div", class=>"ep_upload_doc_title_bar" );
	$doc_div->appendChild( $doc_title_bar );

	my $doc_expansion_bar = $session->make_element( "div", class=>"ep_upload_doc_expansion_bar ep_only_js" );
	$doc_div->appendChild( $doc_expansion_bar );

	my $content = $session->make_element( "div", id=>$doc_prefix."_opts", class=>"ep_upload_doc_content ".($hide?"ep_no_js":"") );
	$doc_div->appendChild( $content );


	my $table = $session->make_element( "table", width=>"100%", border=>0 );
	my $tr = $session->make_element( "tr" );
	$doc_title_bar->appendChild( $table );
	$table->appendChild( $tr );
	my $td_left = $session->make_element( "td", align=>"left", valign=>"middle", width=>"40%" );
	$tr->appendChild( $td_left );

	$td_left->appendChild( $self->_render_doc_icon_info( $doc, $files ) );

	my $td_right = $session->make_element( "td", align=>"right", valign=>"middle", class => "ep_upload_doc_actions" );
	$tr->appendChild( $td_right );

	$td_right->appendChild( $self->_render_doc_actions( $doc ) );

	my $opts_toggle = $session->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${doc_prefix}_opts',".($hide?"false":"true").",'${doc_prefix}_block');EPJS_toggle('${doc_prefix}_opts_hide',".($hide?"false":"true").",'block');EPJS_toggle('${doc_prefix}_opts_show',".($hide?"true":"false").",'block');return false" );
	$doc_expansion_bar->appendChild( $opts_toggle );

	my $s_options = $session->make_element( "div", id=>$doc_prefix."_opts_show", class=>"ep_update_doc_options ".($hide?"":"ep_hide") );
	$s_options->appendChild( $self->html_phrase( "show_options" ) );
	$s_options->appendChild( $session->make_text( " " ) );
	$s_options->appendChild( 
			$session->make_element( "img",
				src=>"$self->{imagesurl}/style/images/plus.png",
				) );
	$opts_toggle->appendChild( $s_options );

	my $h_options = $session->make_element( "div", id=>$doc_prefix."_opts_hide", class=>"ep_update_doc_options ".($hide?"ep_hide":"") );
	$h_options->appendChild( $self->html_phrase( "hide_options" ) );
	$h_options->appendChild( $session->make_text( " " ) );
	$h_options->appendChild( 
			$session->make_element( "img",
				src=>"$self->{imagesurl}/style/images/minus.png",
				) );
	$opts_toggle->appendChild( $h_options );


	my $content_inner = $self->{session}->make_element( "div", id=>$doc_prefix."_opts_inner" );
	$content->appendChild( $content_inner );

	my $id_prefix = "doc.".$doc->get_id;

	my @tabs;
	
	push @tabs, $self->_render_doc_metadata( $doc );
	push @tabs, $self->_render_doc_files( $doc, $files );
	push @tabs, $self->_render_related_docs( $doc );

	# render the tab menu
	$content_inner->appendChild( $session->render_tabs(
				id_prefix => $id_prefix,
				current => $tabs[0]->{id},
				tabs => [map { $_->{id} } @tabs],
				labels => {map { $_->{id} => $_->{title} } @tabs},
				links => {map { $_->{id} => "" } @tabs},
				) );

	# panel that all the tab content sits in
	my $panel = $session->make_element( "div",
			id => "${id_prefix}_panels",
			class => "ep_tab_panel",
			style => "min-height: 250px",
			);
	$content_inner->appendChild( $panel );

	foreach my $tab (@tabs)
	{
		my $view_div = $session->make_element( "div",
				id => "${id_prefix}_panel_".$tab->{id},
				);
		if( $tab ne $tabs[0] )
		{
			$view_div->setAttribute( "style", "display: none" );
		}
		$view_div->appendChild( $tab->{content} );

		$panel->appendChild( $view_div );
	}

	return $doc_div;
}

sub _render_doc_icon_info
{
	my( $self, $doc, $files ) = @_;

	my $session = $self->{session};

	my $table = $session->make_element( "table", border=>0 );
	my $tr = $session->make_element( "tr" );
	my $td_left = $session->make_element( "td", align=>"center" );
	my $td_right = $session->make_element( "td", align=>"left", class=>"ep_upload_doc_title" );
	$table->appendChild( $tr );
	$tr->appendChild( $td_left );
	$tr->appendChild( $td_right );

	$td_left->appendChild( $doc->render_icon_link( new_window=>1, preview=>1, public=>0 ) );

	$td_right->appendChild( $doc->render_citation );
	my $size = 0;
	foreach my $file (@$files)
	{
		$size += $file->value( "filesize" );
	}
	if( $size > 0 )
	{
		$td_right->appendChild( $session->make_element( 'br' ) );
		$td_right->appendChild( $session->make_text( EPrints::Utils::human_filesize($size) ));
	}

	return $table;
}

sub _render_doc_actions
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};

	my $doc_prefix = $self->{prefix}."_doc".$doc->id;

	my $table = $session->make_element( "table" );

	my( $tr, $td );

	$tr = $session->make_element( "tr" );
	$table->appendChild( $tr );

	my $screen = $self->{processor}->screen;
	my $uri = URI->new( 'http:' );
	$uri->query_form( $screen->hidden_bits );

	# allow document actions to test the document for viewing
	local $self->{processor}->{document} = $doc;

	foreach my $params ($screen->action_list( "document_item_actions" ))
	{
		$td = $session->make_element( "td" );
		$tr->appendChild( $td );

		my $aux = $params->{screen};
		my $action = $params->{action};
		my $name = "_internal_".$doc_prefix."_".$aux->get_subtype;
		my $title = $action ? $aux->phrase( "action:$action:title" ) : $aux->phrase( "title" );
		my $icon = $action ? $aux->action_icon_url( $action ) : $aux->icon_url;
		my $input = $td->appendChild(
			$session->make_element( "input",
				type => "image",
				class => "ep_form_action_icon",
				name => $name,
				src => $icon,
				title => $title,
				alt => $title,
				value => $title,
				rel => ($aux->param( "ajax" ) ? $aux->param( "ajax" ) : "") ) );
	}

	return $table;
}

sub _render_related_docs
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{workflow}->{item};

	my $div = $session->make_element( "div", id=>$self->{prefix}."_panels" );

	$doc->search_related( "isVolatileVersionOf" )->map(sub {
			my( undef, undef, $dataobj ) = @_;

			# in the future we might get other objects coming back
			next if !$dataobj->isa( "EPrints::DataObj::Document" );

			$div->appendChild( $self->_render_volatile_div( $dataobj ) );
		});

	if( !$div->hasChildNodes )
	{
		return ();
	}

	return {
		id => "related_".$doc->id,
		   title => $self->html_phrase("related_files"),
		   content => $div,
	};
}

sub _render_volatile_div
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};

	my $doc_prefix = $self->{prefix}."_doc".$doc->id;

	my $doc_div = $self->{session}->make_element( "div", class=>"ep_upload_doc", id=>$doc_prefix."_block" );

	my $doc_title_bar = $session->make_element( "div", class=>"ep_upload_doc_title_bar" );

	my $table = $session->make_element( "table", width=>"100%", border=>0 );
	my $tr = $session->make_element( "tr" );
	$doc_title_bar->appendChild( $table );
	$table->appendChild( $tr );
	my $td_left = $session->make_element( "td", valign=>"middle" );
	$tr->appendChild( $td_left );

	$td_left->appendChild( $self->_render_doc_icon_info(
			$doc,
			[] # $doc->value( "files" )
		) );

	my $td_right = $session->make_element( "td", align=>"right", valign=>"middle", width=>"20%" );
	$tr->appendChild( $td_right );
	my $msg = $self->phrase( "unlink_document_confirm" );
	my $unlink_button = $session->render_button(
			name => "_internal_".$doc_prefix."_unlink_doc",
			value => $self->phrase( "unlink_document" ),
			class => "ep_form_internal_button",
			onclick => "if( window.event ) { window.event.cancelBubble = true; } return confirm(".EPrints::Utils::js_string($msg).");",
			);
	$td_right->appendChild($unlink_button);
	$doc_div->appendChild( $doc_title_bar );

	return $doc_div;
}

sub doc_fields
{
	my( $self, $document ) = @_;

	return @{$self->{config}->{doc_fields}};
}

sub _render_doc_metadata
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};	

	my @fields = $self->doc_fields( $doc );

	return () if !scalar @fields;

	my $doc_cont = $session->make_element( "div" );

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

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

	my $tool_div = $session->make_element( "div", class=>"ep_upload_doc_toolbar" );

	my $update_button = $session->render_button(
		name => "_internal_".$doc_prefix."_update_doc",
		value => $self->phrase( "update" ), 
		class => "ep_form_internal_button",
		);
	$tool_div->appendChild( $update_button );

	$doc_cont->appendChild( $tool_div );
	
	return ({
		id => "metadata_".$doc->get_id,
		   title => $self->html_phrase("Metadata"),
		   content => $doc_cont,
	});
}

sub _render_doc_files
{
	my( $self, $doc, $files ) = @_;

	my $session = $self->{session};	

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $doc_cont = $session->make_element( "div" );

	$doc_cont->appendChild( $self->_render_filelist( $doc, $files ) );

	my $block;

	$block = $session->make_element( "div", class=>"ep_block" );
	$block->appendChild( $session->render_button(
		name => "_internal_".$doc_prefix."_update_doc",
		value => $self->phrase( "update" ), 
		class => "ep_form_internal_button",
		) );
	$doc_cont->appendChild( $block );

	return ({
		id => "files_".$doc->get_id,
		title => $self->html_phrase( "Files" ),
		content => $doc_cont,
	});
}

sub _render_add_file
{
	my( $self, $document, $files ) = @_;

	my $session = $self->{session};
	
	# Create a document-specific prefix
	my $docid = $document->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $hide = @$files == 1;

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

sub _render_filelist
{
	my( $self, $doc, $files ) = @_;

	my $session = $self->{session};
	
	my $doc_prefix = $self->{prefix}."_doc".$doc->id;

	my $main_file = $doc->get_main;
	
	my $div = $session->make_element( "div", class=>"ep_upload_files" );

	my $table = $session->make_element( "table", class => "ep_upload_file_table" );
	$div->appendChild( $table );

	my $tr = $session->make_element( "tr", class => "ep_row" );
	$table->appendChild( $tr );
	my @fields;
	for(qw( filename filesize mime_type hash_type hash ))
	{
		push @fields, $session->dataset( "file" )->field( $_ );
	}
	push @fields, $session->dataset( "document" )->field( "main" );
	foreach my $field (@fields)
	{
		my $td = $session->make_element( "th" );
		$tr->appendChild( $td );
		$td->appendChild( $field->render_name( $session ) );
	}
	do { # actions
		my $td = $session->make_element( "th" );
		$tr->appendChild( $td );
	};

	foreach my $file (@$files)
	{
		$table->appendChild( $self->_render_file( $doc, $file ) );
	}
	
	my $block = $session->make_element( "div", class=>"ep_block" );
	$block->appendChild( $self->_render_add_file( $doc, $files ) );
	$div->appendChild( $block );

	return $div;
}

sub _render_file
{
	my( $self, $doc, $file ) = @_;

	my $session = $self->{session};

	my $doc_prefix = $self->{prefix}."_doc".$doc->id;
	my $filename = $file->value( "filename" );
	my $is_main = $filename eq $doc->get_main;

	my @values;

	my $link = $session->render_link( $doc->get_url( $filename ), "_blank" );
	$link->appendChild( $session->make_text( $filename ) );
	push @values, $link;
	
	push @values, $session->make_text( EPrints::Utils::human_filesize( $file->value( "filesize" ) ) );
	
	push @values, $session->make_text( $file->value( "mime_type" ) );
	
	push @values, $session->make_text( $file->value( "hash_type" ) );
	
	push @values, $session->make_text( $file->value( "hash" ) );
	
	push @values, $session->make_element( "input",
		type => "radio",
		name => $doc_prefix."_main",
		value => $filename,
		($is_main ? (checked => "checked") : ()) );

	my $button_title = $self->phrase( "delete_file" );
	push @values, $session->make_element( "input", 
		type => "image", 
		src => $self->{imagesurl}."/style/images/delete.png",
		name => "_internal_".$doc_prefix."_delete_".$file->id,
		onclick => "EPJS_blur(event); return confirm( ".EPrints::Utils::js_string($self->phrase( "delete_file_confirm", filename => $filename ))." );",
		value => $button_title,
		title => $button_title );

	return $session->render_row( @values );
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
		my $doc_ds = $session->get_repository->get_dataset( "document" );
		my $fieldname = $session->make_element( "span", class=>"ep_problem_field:documents" );
		my $prob = $session->make_doc_fragment;
		$prob->appendChild( $session->html_phrase( 
			"lib/eprint:need_a_format",
			fieldname=>$fieldname ) );
		my $ul = $session->make_element( "ul" );
		$prob->appendChild( $ul );
		
		foreach( @req_formats )
		{
			my $li = $session->make_element( "li" );
			$ul->appendChild( $li );
			$li->appendChild( $session->render_type_name( "document", $_ ) );
		}
			
		push @problems, $prob;
	}

	foreach $doc (@docs)
	{
		my $probs = $doc->validate( $for_archive );

		foreach my $field ( @{$self->{config}->{doc_fields}} )
		{
			my $for_archive = defined($field->{required}) &&
				$field->{required} eq "for_archive";

			# cjg bug - not handling for_archive here.
			if( $field->{required} && !$doc->is_set( $field->{name} ) )
			{
				my $fieldname = $session->make_element( "span", class=>"ep_problem_field:documents" );
				$fieldname->appendChild( $field->render_name( $self->{session} ) );
				my $problem = $session->html_phrase(
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

sub parse_config
{
	my( $self, $config_dom ) = @_;

	$self->{config}->{doc_fields} = [];

	my @fields = $config_dom->getElementsByTagName( "field" );

	my $doc_ds = $self->{session}->get_repository->get_dataset( "document" );

	foreach my $field_tag ( @fields )
	{
		my $field = $self->xml_to_metafield( $field_tag, $doc_ds );
		push @{$self->{config}->{doc_fields}}, $field;
	}
}


1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

