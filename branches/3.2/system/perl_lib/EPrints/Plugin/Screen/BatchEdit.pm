package EPrints::Plugin::Screen::BatchEdit;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

my $JAVASCRIPT = join "", <DATA>;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ edit remove cancel /];

	# is linked to by the BatchEdit export plugin
	$self->{appears} = [];

	return $self;
}

sub allow_edit { $_[0]->can_be_viewed }
sub allow_remove { $_[0]->can_be_viewed }
sub allow_cancel { $_[0]->can_be_viewed }

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/archive/edit" );
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;

	my $cacheid = $self->{processor}->{session}->param( "cache" );

	return $self->SUPER::redirect_to_me_url."&cache=$cacheid";
}

sub render_hidden_bits
{
	my( $self, %extra ) = @_;

	my $xml = $self->{session}->xml;
	my $xhtml = $self->{session}->xhtml;

	my $frag = $xml->create_document_fragment;

	$extra{screen} = exists($extra{screen}) ? $extra{screen} : $self->{processor}->{screenid};
	$extra{cache} = exists($extra{cache}) ? $extra{cache} : $self->get_searchexp->get_cache_id;

	foreach my $key (keys %extra)
	{
		$frag->appendChild( $xhtml->hidden_field( $key => $extra{$key} ) );
	}

	return $frag;
}

sub get_cache
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $cacheid = $session->param( "cache" );

	my $dataset = $session->get_repository->get_dataset( "cachemap" );
	my $cache = $dataset->get_object( $session, $cacheid );

	return $cache;
}

sub get_searchexp
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $cacheid = $session->param( "cache" );

	my $cache = $self->get_cache();

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $session->get_repository->get_dataset( "eprint" ),
		keep_cache => 1,
	);

	if( $searchexp )
	{
		$searchexp->from_string_raw( $cache->get_value( "searchexp" ) );
		$searchexp->{"cache_id"} = $cacheid;
	}

	return $searchexp;
}

sub action_edit { }
sub action_remove { }
sub action_cancel { }

sub wishes_to_export
{
	my( $self ) = @_;

	return defined $self->{session}->param( "ajax" );
}

sub export
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $action = $session->param( "ajax" );
	return unless defined $action;

	if( $action eq "new_field" )
	{
		$self->ajax_new_field(
			$session->param( "field_name" ),
			$session->param( "c" )
		);
	}
	elsif( $action eq "edit" )
	{
		$self->ajax_edit();
	}
	elsif( $action eq "remove" )
	{
		$self->ajax_remove();
	}
	elsif( $action eq "list" )
	{
		$self->ajax_list();
	}
}

sub ajax_list
{
	my( $self ) = @_;

	my $max = 8;

	my $session = $self->{session};

	my $searchexp = $self->get_searchexp;
	return if !defined $searchexp;

	my $list = $searchexp->perform_search;

	$session->send_http_header( content_type => "text/xml; charset=UTF-8" );
	binmode(STDOUT, ":utf8");

	my $div = $session->make_element( "div" );

	my @records = $list->get_records( 0, $max );
	if( !scalar @records )
	{
		$div->appendChild( $session->render_message( "error", $session->html_phrase( "lib/searchexpression:noresults" ) ) );
		print EPrints::XML::to_string( $div, undef, 1 );
		EPrints::XML::dispose( $div );
		return;
	}

	$div->appendChild( $self->html_phrase( "applying_to",
		count => $session->make_text( $list->count ),
		showing => $session->make_text( $max ) ) );

	my $ul = $session->make_element( "ul" );
	$div->appendChild( $ul );

	foreach my $record (@records)
	{
		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );
		$li->appendChild( $record->render_citation_link() );
	}

	print EPrints::XML::to_string( $div, undef, 1 );
	EPrints::XML::dispose( $div );
}

# generate a new action line
sub ajax_new_field
{
	my( $self, $name, $c ) = @_;

	my $session = $self->{session};

	my $alias = $c . "_" . $name;

	my $searchexp = $self->get_searchexp;
	return if !defined $searchexp;

	my $dataset = $searchexp->get_dataset;
	return if !$dataset->has_field( $name );

	my $field;
	foreach my $f ($self->get_fields( $dataset ))
	{
		$field = $f, last if $f->get_name eq $name;
	}
	return if !defined $field;

	$field = $field->clone;
	my @options;
	if( $field->get_property( "multiple" ) )
	{
		@options = qw( clear delete insert append );
	}
	else
	{
		@options = qw( clear replace );
	}

	my $custom_field = {
		name => $alias,
		type => "compound",
		fields => [{
			name => "batchedit_action",
			sub_name => "action",
			type => "set",
			options => \@options,
		}],
	};

	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		push @{$custom_field->{fields}}, @{$field->{fields}};
	}
	else
	{
		delete $field->{"multiple"};
		$field->{sub_name} = $field->{name};
		push @{$custom_field->{fields}}, $field;
	}

	push @{$custom_field->{fields}}, {
			name => "batchedit_remove",
			sub_name => "remove",
			type => "text",
			render_input => sub {
				my $frag = $session->make_doc_fragment;
				
				# button to remove the action
				$frag->appendChild( $session->make_element( "input",
					type => "image",
					alt => "Remove",
					src => $session->get_url( path => "static", "style/images/action_remove.png" ),
					onclick => "ep_batchedit_remove_action($c)",
				) );

				# hint so we can work out how to retrieve the values
				$frag->appendChild( $session->make_element( "input",
					type => "hidden",
					name => "action_$c",
					value => $name
				) );

				return $frag;
			},
		};

	$custom_field = $self->custom_field_to_field( $dataset, $custom_field );

	my $div = $session->make_element( "div", id => "action_$c" );

	my $title_div = $session->make_element( "div", class => "ep_form_field_name" );
	$div->appendChild( $title_div );
	$title_div->appendChild( $field->render_name( $session ) );

	my $help_div = $session->make_element( "div", class => "ep_form_field_help" );
	$div->appendChild( $help_div );
	$help_div->appendChild( $field->render_help( $session ) );

	my $inputs = $custom_field->render_input_field( $session );
	$div->appendChild( $inputs );
	$inputs->setAttribute( 'id', "action_$c" );

	$session->send_http_header( content_type => "text/xml; charset=UTF-8" );
	binmode(STDOUT, ":utf8");
	print EPrints::XML::to_string( $div, undef, 1 );
	EPrints::XML::dispose( $div );
}

sub ajax_edit
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $searchexp = $self->get_searchexp;
	if( !$searchexp )
	{
		return;
	}

	my $list = $searchexp->perform_search;

	if( $list->count == 0 )
	{
		return;
	}

	select(STDOUT);
	local $| = 1;

	my $request = $session->get_request;

	$request->content_type( "text/plain; charset=UTF-8" );
	$request->rflush;

	my $dataset = $searchexp->get_dataset;

	my @actions = $self->get_changes( $dataset );

	if( !@actions )
	{
		$request->print( "0 " );
		$request->print( "f48f27cb163950bc6a7f1a3c7d87afc7" );
		my $message = $session->render_message( "warning", $self->html_phrase( "no_changes" ) );
		$request->print( EPrints::XML::to_string( $message ) );
		EPrints::XML::dispose( $message );
		return;
	}

	$request->print( $list->count() . " " );
	$request->print( "0 " );

	my $count = 0;
	$list->map(sub {
		my( $session, $dataset, $dataobj ) = @_;

		foreach my $act (@actions)
		{
			my $field = $act->{"field"};
			my $action = $act->{"action"};
			my $value = $act->{"value"};
			my $orig_value = $field->get_value( $dataobj );

			if( $field->get_property( "multiple" ) )
			{
				if( $action eq "clear" )
				{
					$field->set_value( $dataobj, [] );
				}
				elsif( $action eq "delete" )
				{
					my $values = EPrints::Utils::clone( $orig_value );
					@$values = grep { cmp_deeply($value, $_) != 0 } @$values;
					$field->set_value( $dataobj, $values );
				}
				elsif( $action eq "insert" )
				{
					my @values = ($value, @$orig_value);
					$field->set_value( $dataobj, \@values );
				}
				elsif( $action eq "append" )
				{
					my @values = (@$orig_value, $value);
					$field->set_value( $dataobj, \@values );
				}
			}
			else
			{
				if( $action eq "clear" )
				{
					$field->set_value( $dataobj, undef );
				}
				elsif( $action eq "replace" )
				{
					$field->set_value( $dataobj, $value );
				}
			}
		}

		$dataobj->commit;
		$request->print( ++$count." " );
	});

	my $ul = $session->make_element( "ul" );
	foreach my $act (@actions)
	{
		my $field = $act->{"field"};
		my $action = $act->{"action"};
		my $value = $act->{"value"};
		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );
		$value = defined($value) ?
			$field->render_single_value( $session, $value ) :
			$session->html_phrase( "lib/metafield:unspecified" );
		$li->appendChild( $self->html_phrase( "applied_$action",
			value => $session->make_text( EPrints::Utils::tree_to_utf8( $value ) ),
			fieldname => $field->render_name,
		) );
		EPrints::XML::dispose( $value );
	}
	$request->print( "f48f27cb163950bc6a7f1a3c7d87afc7" );
	my $message = $session->render_message( "message", $self->html_phrase( "applied",
		changes => $ul,
	) );
	$request->print( EPrints::XML::to_string( $message ) );
	EPrints::XML::dispose( $message );
}

sub ajax_remove
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $searchexp = $self->get_searchexp;
	if( !$searchexp )
	{
		return;
	}

	my $list = $searchexp->perform_search;

	if( $list->count == 0 )
	{
		return;
	}

	select(STDOUT);
	local $| = 1;

	my $request = $session->get_request;

	$request->content_type( "text/plain; charset=UTF-8" );
	$request->rflush;

	my $dataset = $searchexp->get_dataset;

	$request->print( $list->count() . " " );
	$request->print( "0 " );

	my $count = 0;
	$list->map(sub {
		my( $session, $dataset, $dataobj ) = @_;

		$dataobj->remove;

		$request->print( ++$count." " );
	});

	$request->print( "f48f27cb163950bc6a7f1a3c7d87afc7" );
	my $message = $session->render_message( "message", $self->html_phrase( "removed" ) );
	$request->print( EPrints::XML::to_string( $message ) );
	EPrints::XML::dispose( $message );
}

sub render
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	my $searchexp = $self->get_searchexp;
	if( !defined $searchexp )
	{
		$processor->add_message( "error", $self->html_phrase( "invalid_cache" ) );
		return $page;
	}

	my $list = $searchexp->perform_search;
	if( $list->count == 0 || !$list->slice(0,1) )
	{
		$processor->add_message( "error", $session->html_phrase( "lib/searchexpression:noresults" ) );
		return $page;
	}

	my $iframe = $session->make_element( "iframe",
			id => "ep_batchedit_iframe",
			name => "ep_batchedit_iframe",
			width => "0px",
			height => "0px",
			style => "border: 0px;",
	);
	$page->appendChild( $iframe );

	$page->appendChild( $session->make_javascript ( $JAVASCRIPT ) );

	$page->appendChild( $self->render_cancel_form( $searchexp ) );

	$p = $session->make_element( "p" );
	$page->appendChild( $p );
	$p->appendChild( $searchexp->render_description );

	$p = $session->make_element( "div", id => "ep_batchedit_sample" );
	$page->appendChild( $p );

	$div = $session->make_element( "div", id => "ep_progress_container" );
	$page->appendChild( $div );

	$div = $session->make_element( "div", id => "ep_batchedit_inputs" );
	$page->appendChild( $div );

	$div->appendChild( $session->xhtml->tabs(
		[
			$self->html_phrase( "edit_title" ),
			$self->html_phrase( "remove_title" )
		],
		[
			$self->render_changes_form( $searchexp ),
			$self->render_remove_form( $searchexp ),
		],
	) );

	return $page;
}

sub get_fields
{
	my( $self, $dataset ) = @_;

	my @fields;

	my %fieldnames;

	foreach my $field ($dataset->get_fields)
	{
		next if defined $field->{sub_name};
		next if $field->get_name eq $dataset->get_key_field->get_name;
		next if
			!$field->isa( "EPrints::MetaField::Compound" ) &&
			!$field->get_property( "show_in_fieldlist" );

		push @fields, $field;
		my $name = $field->render_name( $self->{session} );
		$fieldnames{$field} = lc(EPrints::Utils::tree_to_utf8( $name ) );
		EPrints::XML::dispose( $name );
	}

	@fields = sort { $fieldnames{$a} cmp $fieldnames{$b} } @fields;

	return @fields;
}

sub get_changes
{
	my( $self, $dataset ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my @actions;

	my @idx = map { /_(\d+)$/; $1 } grep { /^action_\d+$/ } $session->param;

	my %fields = map { $_->get_name => $_ } $self->get_fields( $dataset );

	foreach my $i (@idx)
	{
		my $name = $session->param( "action_$i" );
		next if !EPrints::Utils::is_set( $name );
		my $action = $session->param( $i . "_" . $name . "_action" );
		next if !EPrints::Utils::is_set( $action );
		my $field = $fields{$name};
		next if !defined $field;
		do {
			local $field->{multiple} = 0;
			my $value;
			if( $field->isa( "EPrints::MetaField::Compound" ) )
			{
				$value = $field->form_value( $session, undef, $i );
			}
			else
			{
				$value = $field->form_value( $session, undef, $i."_".$name );
			}
			push @actions, {
				action => $action,
				field => $field,
				value => $value,
			};
		};
	}

	return @actions;
}

sub render_changes_form
{
	my( $self, $searchexp ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $dataset = $searchexp->get_dataset;

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	my %buttons = (
		edit => $self->phrase( "action:edit" ),
	);

	my $form = $session->render_input_form(
		dataset => $dataset,
#		fields => \@input_fields,
		show_help => 0,
		show_names => 1,
#		top_buttons => \%buttons,
		buttons => \%buttons,
		hidden_fields => {
			screen => $processor->{screenid},
			cache => $searchexp->get_cache_id,
			max_action => 0,
			ajax => "edit",
		},
	);
	$page->appendChild( $form );
	$form->setAttribute( target => "ep_batchedit_iframe" );
	$form->setAttribute( onsubmit => "return ep_batchedit_submitted();" );

	my $container = $session->make_element( "div" );
	# urg, fragile!
	for($form->childNodes)
	{
		if( $_->nodeName eq "input" && $_->getAttribute( "type" ) eq "hidden" )
		{
			$form->insertBefore( $container, $_ );
			last;
		}
	}

	$div = $session->make_element( "div", id => "ep_batchedit_actions" );
	$container->appendChild( $div );

	my $select = $session->make_element( "select", id => "ep_batchedit_field_name" );
	$container->appendChild( $select );

	foreach my $field ($self->get_fields( $dataset ))
	{
		my $option = $session->make_element( "option", value => $field->get_name );
		$select->appendChild( $option );

		$option->appendChild( $field->render_name( $session ) );
	}

	my $add_button = $session->make_element( "button", class => "ep_form_action_button", onclick => "ep_batchedit_add_action(); return false" );
	$container->appendChild( $add_button );

	$add_button->appendChild( $self->html_phrase( "add_action" ) );

	return $page;
}

sub render_cancel_form
{
	my( $self, $searchexp ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $dataset = $searchexp->get_dataset;

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	my $form = $session->render_input_form(
		dataset => $dataset,
		show_help => 0,
		show_names => 1,
		buttons => {},
		hidden_fields => {
			screen => $processor->{screenid},
			cache => $searchexp->get_cache_id,
		},
	);
	$form->setAttribute( id => "ep_batchedit_cancel_form" );
	$page->appendChild( $form );

	return $page;
}

sub render_remove_form
{
	my( $self, $searchexp ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $dataset = $searchexp->get_dataset;

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	$div = $session->make_element( "div", class => "ep_block" );
	$page->appendChild( $div );

	$div->appendChild( $self->html_phrase( "remove_help" ) );

	$div = $session->make_element( "div", class => "ep_block" );
	$page->appendChild( $div );

	my %buttons = (
		remove => $session->phrase( "lib/submissionform:action_remove" ),
	);

	my $form = $session->render_input_form(
		dataset => $dataset,
		show_help => 0,
		show_names => 1,
		buttons => \%buttons,
		hidden_fields => {
			screen => $processor->{screenid},
			cache => $searchexp->get_cache_id,
			ajax => "remove",
		},
	);
	$form->setAttribute( target => "ep_batchedit_iframe" );
	my $message = EPrints::Utils::js_string( $self->phrase( "confirm_remove" ) );
	$form->setAttribute( onsubmit => "return ep_batchedit_remove_submitted( $message );" );
	$div->appendChild( $form );
	$form->setAttribute( id => "ep_batchremove_form" );

	return $page;
}

sub custom_field_to_field
{
	my( $self, $dataset, $data ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	$data->{fields_cache} = [];

	foreach my $inner_field (@{$data->{fields}})
	{
		my $field = EPrints::MetaField->new(
			dataset => $dataset,
			parent_name => $data->{name},
			show_in_html => 0,
			%{$inner_field},
		);
		push @{$data->{fields_cache}}, $field;
	}

	my $field = EPrints::MetaField->new(
		dataset => $dataset,
		%{$data},
	);

	return $field;
}

sub cmp_deeply
{
	my( $var_a, $var_b ) = @_;

	if( !EPrints::Utils::is_set($var_a) )
	{
		return 0;
	}
	elsif( !EPrints::Utils::is_set($var_b) )
	{
		return -1;
	}

	my $rc = 0;

	$rc ||= ref($var_a) cmp ref($var_b);
	$rc ||= _cmp_hash($var_a, $var_b) if( ref($var_a) eq "HASH" );
	$rc ||= $var_a cmp $var_b if( ref($var_a) eq "" );

	return $rc;
}

sub _cmp_hash
{
	my( $var_a, $var_b ) = @_;

	my $rc = 0;

	for(keys %$var_a)
	{
		$rc ||= cmp_deeply( $var_a->{$_}, $var_b->{$_} );
	}

	return $rc;
}

1;

__DATA__

Event.observe(window, 'load', ep_batchedit_update_list);

function ep_batchedit_update_list()
{
	var container = $('ep_batchedit_sample');
	if( !container )
		return;

	container.update( '<img src="' + eprints_http_root + '/style/images/lightbox/loading.gif" />' );

	var ajax_parameters = {};
	ajax_parameters['screen'] = $F('screen');
	ajax_parameters['cache'] = $F('cache');
	ajax_parameters['ajax'] = 'list';

	new Ajax.Updater(
		container,
		eprints_http_cgiroot+'/users/home',
		{
			method: "get",
			onFailure: function() { 
				alert( "AJAX request failed..." );
			},
			onException: function(req, e) { 
				alert( "AJAX Exception " + e );
			},
			parameters: ajax_parameters
		} 
	);
}

var ep_batchedit_c = 1;

/* the user clicked to add an action */
function ep_batchedit_add_action()
{
	var name = $('ep_batchedit_field_name').value;

	var form = $('ep_batchedit_form');
	Element.extend(form);

	var ajax_parameters = {};
	ajax_parameters['screen'] = $F('screen');
	ajax_parameters['cache'] = $F('cache');
	ajax_parameters['ajax'] = 'new_field';
	ajax_parameters['field_name'] = name;
	ajax_parameters['c'] = ep_batchedit_c++;

	$('max_action').value = ep_batchedit_c;

	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "get",
			onFailure: function() { 
				alert( "AJAX request failed..." );
			},
			onException: function(req, e) { 
				alert( "AJAX Exception " + e );
			},
			onSuccess: function(response){ 
				var xml = response.responseText;
				if( !xml )
				{
					alert( "No response from server: "+response.responseText );
				}
				else
				{
					$('ep_batchedit_actions').insert( xml );
				}
			},
			parameters: ajax_parameters
		} 
	);
}

/* the user clicked to remove an action */
function ep_batchedit_remove_action(idx)
{
	var action = $('action_' + idx);
	if( action != null )
		action.parentNode.removeChild( action );
}

/* the user submitted the changes form */
function ep_batchedit_submitted()
{
	var iframe = $('ep_batchedit_iframe');
	var container = $('ep_progress_container');

	$('ep_batchedit_inputs').hide();

	/* under !Firefox the form submission doesn't happen straight away, so we
	 * have to delay removing form elements until after this method has
	 * finished */
	new PeriodicalExecuter(function(pe) {
		pe.stop();
		var max_action = $F('max_action');
		for(var i = 0; i < max_action; ++i)
			ep_batchedit_remove_action( i );
	}, 1);

	while(container.hasChildNodes())
		container.removeChild( container.firstChild );

	var progress = new EPrintsProgressBar({bar: 'progress_bar_orange.png'}, container);

	var pe = new PeriodicalExecuter(function(pe) {
		var parts = ep_batchedit_iframe_contents( iframe );
		var content = parts[0];
		if( content == null )
			return;
		var nums = content.split( ' ' );
		var total = nums[0];
		if( !total )
			return;
		nums.pop();
		var current = nums[nums.length-1];

		var percent = current / total;
		progress.update( percent, Math.round(percent*100) + '%' );
	}, .2);

	Event.observe(iframe, 'load', function() {
		Event.stopObserving( iframe, 'load' );
		pe.stop();

		progress.update( 1, '100%' );

		// reduce UI flicker by adding a short delay before we refresh
		new PeriodicalExecuter(function(pe_f) {
			pe_f.stop();

			ep_batchedit_finished();
		}, .5);
	});

	return true;
}

function ep_batchedit_iframe_contents( iframe )
{
	if(
		iframe.contentWindow.document == null ||
		iframe.contentWindow.document.body.firstChild == null
	  )
		return [];

	var content = iframe.contentWindow.document.body.firstChild.firstChild.nodeValue;

	return content.split( "f48f27cb163950bc6a7f1a3c7d87afc7" );
}

function ep_batchedit_finished()
{
	var iframe = $('ep_batchedit_iframe');
	var container = $('ep_progress_container');

	while(container.hasChildNodes())
		container.removeChild( container.firstChild );

	var parts = ep_batchedit_iframe_contents( iframe );

	container.innerHTML = parts[1];

	iframe.contentWindow.document.body.removeChild(
		iframe.contentWindow.document.body.firstChild
	);

	ep_batchedit_update_list();

	$('ep_batchedit_inputs').show();
}

function ep_batchedit_remove_submitted( message )
{
	var form = $('ep_batchedit_form');
	var iframe = $('ep_batchedit_iframe');
	var container = $('ep_progress_container');

	if( confirm( message ) != true )
		return false;

	$('ep_batchedit_inputs').hide();

	var progress = new EPrintsProgressBar({bar: 'progress_bar_orange.png'}, container);

	var pe = new PeriodicalExecuter(function(pe) {
		var parts = ep_batchedit_iframe_contents( iframe );
		var content = parts[0];
		if( content == null )
			return;
		var nums = content.split( ' ' );
		var total = nums[0];
		if( !total )
			return;
		nums.pop();
		var current = nums[nums.length-1];

		var percent = current / total;
		progress.update( percent, Math.round(percent*100) + '%' );
	}, .2);

	Event.observe(iframe, 'load', function() {
		Event.stopObserving( iframe, 'load' );
		pe.stop();

		progress.update( 1, '100%' );

		// reduce UI flicker by adding a short delay before we refresh
		new PeriodicalExecuter(function(pe_f) {
			pe_f.stop();

			ep_batchedit_finished();
		}, .5);
	});

	return true;
}
