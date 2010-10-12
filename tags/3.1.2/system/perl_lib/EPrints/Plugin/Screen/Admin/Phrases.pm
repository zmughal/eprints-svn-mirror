package EPrints::Plugin::Screen::Admin::Phrases;

@ISA = ( 'EPrints::Plugin::Screen' );

use Data::Dumper;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1350, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/edit/phrase" );
}

sub wishes_to_export
{
	my( $self ) = @_;

	my $phrase_id = $self->{session}->param( "phrase_id" );
	return 0 unless defined $phrase_id;
	
	return 1;
}

sub export
{
	my( $self ) = @_;

	my( $message, $error_level ) = $self->write_phrase;

	my $map = $self->get_all_phrases;
	my $phrase_id = $self->{session}->param( "phrase_id" );
	my $phrase = $map->{$phrase_id};
	if( !defined $phrase )
	{
		$phrase = { phrase_id=>$phrase_id, src=>"null", xml=>$self->{session}->make_doc_fragment };
	}

	print EPrints::XML::to_string( 
		EPrints::XML::contents_of(
			$self->render_row( $phrase, $message, $error_level ) ) );
}

sub write_phrase
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $phrases = $self->get_all_phrases;
	my $lang = $session->get_lang;
	my $file = $session->get_repository->get_conf( "config_path" )."/lang/".$lang->{id}."/phrases/zz_webcfg.xml";

	my $phrase_id = $session->param( "phrase_id" );
	my $lib_path = $session->get_repository->get_conf( "lib_path" );
	my $phrase_xml_str = "<?xml version='1.0' encoding='utf-8' standalone='no' ?>
<!DOCTYPE phrases SYSTEM '$lib_path/xhtml-entities.dtd' >
<epp:phrase id='$phrase_id' xmlns='http://www.w3.org/1999/xhtml' xmlns:epp='http://eprints.org/ep3/phrase' xmlns:epc='http://eprints.org/ep3/control'>".$session->param( "phrase" )."</epp:phrase>\n\n";
	my $phrase_xml = eval { 
		my $doc = EPrints::XML::parse_xml_string( $phrase_xml_str );
		if( !defined $doc )
		{
			$@ = "XML parse error";
			return;
		}
		EPrints::XML::contents_of( $doc->getDocumentElement ); 
	};

	if( !defined $phrase_xml )
	{
		my $message_dom = $session->make_element( "div" );
		$message_dom->appendChild( $self->html_phrase( "write_failed" ) );
		my $pre = $session->make_element( "pre" );
		$message_dom->appendChild( $pre );
		$pre->appendChild( $session->make_text( $@ ) );
		return( $message_dom, "error" );
	}

	my $reload = 1;
	if( defined $phrases->{$phrase_id} && $phrases->{$phrase_id}->{src} eq "webcfg" )
	{
		$reload = 0;
	}

	$phrases->{$phrase_id} = { 
		xml => $session->clone_for_me( $phrase_xml, 1 ), 
		src => "webcfg",
		file => $file };

	$lang->{repository_data}->{$phrase_id} = $phrases->{$phrase_id};

	if( !-e $file )
	{
		unless( open( P, ">$file" ) )
		{
			my $message_dom = $session->make_element( "div" );
			$message_dom->appendChild( $session->html_phrase( 
				"problem_writing_file", 
				file => $session->make_text( $file ),
				error => $session->make_text( $! ) ) );
			return( $message_dom, "error" );
		}
		print P <<END;
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<!DOCTYPE phrases SYSTEM "entities.dtd">
<epp:phrases xmlns="http://www.w3.org/1999/xhtml" xmlns:epp="http://eprints.org/ep3/phrase" xmlns:epc='http://eprints.org/ep3/control'>

</epp:phrases>
END
		close P;
	}

	my $doc = $session->get_repository->parse_xml( $file );
	my $remove_el;
	foreach my $phrase_el ( $doc->getElementsByTagNameNS("http://eprints.org/ep3/phrase","phrase" ) )
	{
		my $id = $phrase_el->getAttribute( "id" );
		if( $id eq $phrase_id )
		{
			$remove_el = $phrase_el;
		}	
	}

	my $phrase_el = $doc->createElement( "epp:phrase" );
	$phrase_el->setAttribute( "id", $phrase_id );
	$phrase_el->appendChild( 
		EPrints::XML::clone_and_own( $phrase_xml, $doc, 1 ) );
	if( defined $remove_el )
	{
		$remove_el->getParentNode->insertBefore($phrase_el,$remove_el);
		$remove_el->getParentNode->removeChild( $remove_el );
	}
	else
	{
		$doc->documentElement->appendChild( $doc->createTextNode( "    " ));
		$doc->documentElement->appendChild( $phrase_el );
		$doc->documentElement->appendChild( $doc->createTextNode( "\n\n" ));
	}


	unless( open( P, ">$file" ) )
	{
		my $message_dom = $session->make_element( "div" );
		$message_dom->appendChild( $session->html_phrase( 
				"problem_writing_file", 
				file => $session->make_text( $file ),
				error => $session->make_text( $! ) ) );
		return( $message_dom, "error" );
	}
	print P $doc->toString;
	close P;

	my $message_dom = $session->make_element( "div" );
	$message_dom->appendChild( $self->html_phrase( "save_ok" ) );
	$message_dom->appendChild( $session->make_text( " " ) );

	if( !$reload )
	{
		$message_dom->appendChild( $self->html_phrase( "reload_not_required" ) );
	}
	elsif( !$self->EPrints::Plugin::Screen::Admin::Reload::allow_reload_config )
	{
		$message_dom->appendChild( $self->html_phrase( "reload_required" ) );
	}
	else
	{
		$self->EPrints::Plugin::Screen::Admin::Reload::action_reload_config;
		$message_dom->appendChild( $self->html_phrase( "will_reload" ) );
	}

	return( $message_dom, "message" );
}


sub export_mimetype
{
	my( $self ) = @_;

	return "text/html";
}


sub get_all_phrases
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $lang = $session->get_lang;

	my $map = {};
	if( defined $lang->{fallback} )
	{
		$self->add_map( $map, "systemfallback", $lang->{fallback}->_get_data );
	}
	$self->add_map( $map, "system", $lang->{data} ); 
	if( defined $lang->{fallback} )
	{
		$self->add_map( $map, "repofallback", $lang->{fallback}->_get_repositorydata );
	}
	$self->add_map( $map, "repo", $lang->{repository_data} ); 

	return $map;
}

sub add_map
{
	my( $self, $map, $src, $phrases  ) = @_;

	foreach my $phrase_id ( keys %{$phrases} )
	{
		$map->{$phrase_id} = $phrases->{$phrase_id};
		$map->{$phrase_id}->{src} = $src;
		$map->{$phrase_id}->{phrase_id} = $phrase_id;
		if( $map->{$phrase_id}->{file} =~ m/zz_webcfg.xml$/ )
		{
			$map->{$phrase_id}->{src} = "webcfg";
		}
	}
}

sub render_style
{
	my( $self ) = @_;

	my $style = $self->{session}->make_element( "style", type=>"text/css" );
	my $base_url = $self->{session}->get_repository->get_conf('base_url');
	$style->appendChild( $self->{session}->make_text( <<END ) );
.ep_phraseedit_table {
	width: 100%;
	border-collapse: collapse;
	margin-top: 1em;
}
.ep_phraseedit_cell {
	border: solid 1px black;
	padding: 3px;
	background-color: #ccc;
}
th.ep_phraseedit_cell {
	text-align: right;
}
.ep_phraseedit_cell_null {
	background-color: #ccf;
}
.ep_phraseedit_cell_webcfg {
	background-color: #99f;
}
.ep_phraseedit_table td input {
	font-size: 90%;
}
.ep_phraseedit_table td textarea {
	display: block;
	background-color: white;
	border: solid 1px #66c;
	width: 98%;
	overflow: hidden;
}
.ep_phraseedit_view {
	display: block;
	padding: 2px;
	border: solid 1px transparent;
}
.ep_phraseedit_view:hover {
	background-color: white;
	border: solid 1px #66c;
}
.ep_phraseedit_addbar
{
	border: 1px solid #88c;
	background: #e7e9f5 url($base_url/style/images/toolbox.png) repeat-x;
	padding: 8px;
	margin-bottom: 0.75em;
	margin-top: 0.25em;
}
END
	return $style;
}



# stop post requests redirecting to GETs
sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $map = $self->get_all_phrases;

	my $f = $session->make_doc_fragment;
	
	$f->appendChild( $self->render_style );

	$f->appendChild( $self->html_phrase( "intro" ) );

	if( !defined $self->{phrase_ids} )
	{
		# add new phrase only shown on actual plugin page.
		my $add_div = $session->make_element( "div", class=>"ep_phraseedit_addbar" );
		my $form = $session->render_form( "get",
			$session->get_repository->get_conf( "rel_cgipath" )."/users/home" );
		$form->appendChild( $self->render_hidden_bits );
		$form->appendChild(
			$session->render_noenter_input_field( 
				size => "50",
				name => "ep_phraseedit_newid",
				style => "border: solid 1px #88c",
				id => "ep_phraseedit_newid" ));
		$form->appendChild(
			$session->make_text( " " ) );	
		$form->appendChild(
			$session->make_element( 
				"input", 
				class => "ep_form_action_button",
				type => "submit", 
				value => $self->phrase( "new_phrase" ),
				id => "ep_phraseedit_add",
				onclick => "return ep_phraseedit_addphrase(event,\$F('ep_phraseedit_newid'))" ));
		$f->appendChild( $add_div );
		$add_div->appendChild( $form );
	}

	my @ids;
	if( defined $self->{phrase_ids} )
	{
		@ids = @{$self->{phrase_ids}};
	}
	else
	{
		@ids = sort keys %{$map};	
	}

	my $script = $session->make_element( "script", type=>"text/javascript" );
	$script->appendChild( $session->make_text( "window.first_row = 'ep_phrase_row_$ids[0]'" ) );
	$f->appendChild( $script );	

	my $table = $session->make_element( "table", width=>'100%', class=>'ep_phraseedit_table', id=>"ep_phraseedit_table" );
	foreach my $phrase_id ( @ids )
	{
		next if defined $map->{$phrase_id};
		$table->appendChild( $self->render_row( 
			{ phrase_id=>$phrase_id, src=>"null", xml=>$session->make_doc_fragment }, 
			$self->html_phrase( "phrase_not_defined" ),
			"warning" ) );
		$table->appendChild( $session->make_text( "\n\n\n\n" ) );
	}	
	foreach my $phrase_id ( @ids )
	{
		my $phrase = $map->{$phrase_id};
		next if !defined $phrase;
		$table->appendChild( $self->render_row( $phrase ) );
		$table->appendChild( $session->make_text( "\n\n\n\n" ) );
	}
	$f->appendChild( $table );	

	return $f;
}

sub render_row
{
	my( $self , $phrase , $message, $error_level ) = @_;

	$error_level = "message" unless defined $error_level;

	my $session = $self->{session};
	my $phrase_id = $phrase->{phrase_id};

	my $tr = $session->make_element( "tr", id=>"ep_phrase_row_$phrase_id" );

	my $td1 = $session->make_element( "th", class=>"ep_phraseedit_cell ep_phraseedit_cell_".$phrase->{src} );
	$td1->appendChild( $session->make_text( $phrase_id ));
	$tr->appendChild( $td1 );

	my $string = EPrints::XML::to_string( 
			EPrints::XML::contents_of( 
				$session->clone_for_me( $phrase->{xml}, 1 )));
	my $td3 = $session->make_element( "td", class=>"ep_phraseedit_cell ep_phraseedit_cell_".$phrase->{src}, id=>"ep_phrase_$phrase_id" );
	if( defined $message )
	{
		my $mbox = $session->make_element( "div", id=>"ep_phrase_message_$phrase_id" );
		$mbox->appendChild( $session->render_message( $error_level, $message, 0 ));
		$td3->appendChild( $mbox );
		my $script = $session->make_element( "script", type=>"text/javascript" );
		$td3->appendChild( $script );
		if( $error_level ne "message" && $string ne "" )
		{
			my $p = $session->param( "phrase" );
			$p =~ s/([^a-z0-9 ])/'\\x'.sprintf( "%02X", ord( $1 ) )/egi;
			$script->appendChild( $session->make_text( "ep_phraseedit_show_text( '$phrase_id', '$p' );"));
		}
	}
	my $view_div = $session->make_element( 
		"a", 
		class => "ep_phraseedit_view", 
		style => "display: ".($error_level eq "message"?"block":"none"),
		id => "ep_phrase_view_$phrase_id", 
		onclick => "ep_phraseedit_show('$phrase_id')" );
	$view_div->appendChild( $session->make_text( $string ) );
	$td3->appendChild( $view_div );
	my $edit_div = $session->make_element( 
		"div", 
		id => "ep_phrase_edit_$phrase_id", 
		style => "display: ".($error_level eq "message"?"none":"block") );
	my $form = $session->render_form( "get",
		$session->get_repository->get_conf( "rel_cgipath" )."/users/home" );
	$form->appendChild( $self->render_hidden_bits );
	my $textarea = $session->make_element( 
		"textarea", 
		onkeyup => "ep_phraseedit_adjust_textarea( this )",
		id => "ep_phrase_textarea_$phrase_id", 
		name => "ep_phrase_textarea_$phrase_id" );
#	$textarea->appendChild( $session->make_text( " " ) );
	$form->appendChild( $textarea );
	$edit_div->appendChild( $form );
	my $ok_button = $session->make_element( 
		"input", 
		type => "submit", 
		value => $self->phrase( "save" ),
		id => "ep_phrase_save_$phrase_id", 
		onclick => "return ep_phraseedit_save(event,'$phrase_id')" );
	$form->appendChild( $ok_button );
	$form->appendChild( $session->make_text( " " ) );
	my $reset_button = $session->make_element( 
		"input", 
		type => "submit", 
		value => $self->phrase( "reset" ),
		id => "ep_phrase_reset_$phrase_id", 
		onclick => "return ep_phraseedit_reset(event,'$phrase_id')" );
	$form->appendChild( $session->make_text( " " ) );
	$form->appendChild( $reset_button );
	# hide this if cancel makes no sense, but keep it in the DOM so javascript
	# doesn't get uppity.
	my $style = "";
	$style = "display: none" if( $error_level eq "warning" && $string eq "" );
	$form->appendChild( $session->make_text( " " ) );
	my $cancel_button = $session->make_element( 
		"input", 
		type => "submit", 
		style => $style,
		value => $self->phrase( "cancel" ),
		id => "ep_phrase_cancel_$phrase_id", 
		onclick => "return ep_phraseedit_cancel(event,'$phrase_id')" );
	$form->appendChild( $cancel_button );
	$td3->appendChild( $edit_div );
	$tr->appendChild( $td3 );

	my $td2 = $session->make_element( "td",  class=>"ep_phraseedit_cell ep_phraseedit_cell_".$phrase->{src} );
	$td2->appendChild( $session->make_text( $phrase->{src} ));
	$tr->appendChild( $td2 );

	return $tr;
}

######################################################################
=pod
