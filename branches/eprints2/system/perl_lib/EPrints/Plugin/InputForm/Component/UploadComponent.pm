package EPrints::Plugin::InputForm::Component::UploadComponent;

use EPrints;
use EPrints::Plugin::InputForm::Component;
@ISA = ( "EPrints::Plugin::InputForm::Component" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "UploadComponent";
	$self->{visible} = "all";
	return $self;
}

# return an array of problems
sub update_from_form
{
	my( $self ) = @_;

	my @problems = ();

	my %params = $self->params();
	
	# Handle any doc-specific tasks
	
	foreach my $param ( keys %params )
	{
		if( $param =~ /^doc(.+)_upload$/ )
		{
			my $docid = $1;
			
			my $doc = EPrints::DataObj::Document->new(
				$self->{session},
				$docid );
				
			my $success = EPrints::Apache::AnApache::upload_doc_file(
				$self->{session},
				$doc,
				$self->{prefix}.'_doc'.$docid.'_file' );
			
			if( !$success )
			{
				push @problems,
					$self->{session}->html_phrase( "lib/submissionform:upload_prob" );
			}
		}

		if( $param =~ /^doc(.+)_change$/ )
		{
			my $docid = $1;

			my $doc = EPrints::DataObj::Document->new(
				$self->{session},
				$docid );
			
			my $new_format = $self->param( "doc".$docid."_format" );
			my $new_security = $self->param( "doc".$docid."_security" );
		
			$doc->set_format( $new_format );
			$doc->set_value( "security", $new_security );
			$doc->commit();
		}
	}

	if( $self->param( "add_format" ) )
	{
		my $format = $self->param( "select_format" );
		my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
		my $doc = $doc_ds->create_object( $self->{session}, {
			eprintid => $self->{workflow}->{item}->get_id } );
		if( !defined $doc )
		{
			$self->_database_err;
			return( 0 );
		}
		else
		{
			$doc->set_format( $format );
			$doc->commit();
		}
	}

	return @problems;
}


sub _make_heading
{
	#moj lang
	my( $self, $text ) = @_;
	my $th = $self->{session}->make_element( "th" );
	$th->appendChild( $self->{session}->make_text( $text ) );
	return $th;
}

sub render_help
{
	my( $self, $surround ) = @_;
	return $self->{session}->make_text( "Help goes here" );
}

sub _make_format_select
{
	my( $self, $prefix, $name, $selected ) = @_;
	my $session = $self->{session};
	my $format_sel = $session->make_element( "select", name => $prefix."_".$name );
	
	my $doc_ds = $self->{session}->get_repository->get_dataset(
		"document" );
	
	my @formats = $self->{workflow}->{item}->required_formats;
	
	foreach my $format ( @formats )
	{
		my $option = $session->make_element( "option", value => $format );
		if( defined $selected && $format eq $selected )
		{	
			$option->setAttribute( "selected", 1 );
		}
		$option->appendChild( $doc_ds->render_type_name( $session, $format ) );
		$format_sel->appendChild( $option );
	}
	return $format_sel;
}

sub _make_toolbar
{
	my( $self, $document, $curr_format ) = @_;

	my $session = $self->{session};
	my $toolbar = $session->make_element( "div", class => "wf_toolbar" );

	# Create a document-specific prefix
	my $docid = $document->get_id;
	my $prefix = $self->{prefix}."_doc".$docid;

	# Format option
	
	$toolbar->appendChild( $session->make_text( "Format: " ) ); #moj: lang
	$toolbar->appendChild( $self->_make_format_select( $prefix, "format", $curr_format ) );

	$toolbar->appendChild( $session->make_text( " " ) );

	# Security Option
	
	my $security_sel = $session->make_element( "select", name => $prefix."_security" );
	my $sec_ds = $self->{session}->get_repository->get_dataset( "security" );
	
	my $sec_options = $sec_ds->get_types();
	
	foreach my $sec_option ( @$sec_options )
	{
		my $option = $session->make_element( "option", value => $sec_option );
		if( defined $document && $sec_option eq $document->get_value( "security" ) )
		{
			$option->setAttribute( "selected", 1 );
		}
		$option->appendChild( $sec_ds->render_type_name( $session, $sec_option ) );
		$security_sel->appendChild( $option );
	}
	$toolbar->appendChild( $session->make_text( "Files Visible To: " ) ); #moj: lang
	$toolbar->appendChild( $security_sel );

	$toolbar->appendChild( $session->render_nbsp );
	my $se_change_button = $session->make_element( "input", 
		type => "submit", 
		class => "internalbutton",
		value => "Change", 
		name => $prefix."_change" );
	$toolbar->appendChild( $se_change_button );

	return $toolbar;
}

sub _make_addbar
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $toolbar = $session->make_element( "div", class => "wf_add_format" );
	$toolbar->appendChild( $session->make_text( "Add New Format: " ) );
	$toolbar->appendChild( $self->_make_format_select( $self->{prefix}, "select_format" ) );
	
	my $add_format_button = $session->make_element( "input", 
		type => "submit", 
		class => "internalbutton",
		value => "Add", 
		name => $self->{prefix}."_add_format" );
	$toolbar->appendChild( $add_format_button );
	
	return $toolbar; 
}

sub _make_uploadbar
{
	my( $self, $document ) = @_;

	my $session = $self->{session};
	
	# Create a document-specific prefix
	my $docid = $document->get_id;
	my $prefix = $self->{prefix}."_doc".$docid."_";

	my $toolbar = $session->make_element( "div", class => "wf_toolbar" );
	my $file_button = $session->make_element( "input",
		name => $prefix."file",
		id => "filename",
		type => "file",
		);
	my $upload_button = $session->make_element( "input",
		name => $prefix."upload",
		value => "Upload",
		type => "submit",
		class => "internalbutton",
		);
	
	$toolbar->appendChild( $file_button );
	$toolbar->appendChild( $upload_button );
	return $toolbar; 
}

sub _make_placeholder
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $placeholder = $session->make_element( "tr", id => "placeholder" );
	my $td = $session->make_element( "td", colspan => "3" );
	$td->appendChild( $session->make_text( "Please upload some files." ) );
	$placeholder->appendChild( $td );
	return $placeholder;
}

sub _make_filelist
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
	my $show_radios = ( $num_files > 1 ); 

	
	my $table = $session->make_element( "table", class => "wf_file_table" );
	my $tbody = $session->make_element( "tbody" );
	my $headings = $session->make_element( "tr" );
	if( $show_radios )
	{
		$headings->appendChild( $self->_make_heading( "Primary" ) );
	}
	$headings->appendChild( $self->_make_heading( "Filename" ) );
	$headings->appendChild( $self->_make_heading( "Size" ) );
	$headings->appendChild( $self->_make_heading( "Type" ) );
	$tbody->appendChild( $headings );

	if( !defined $document || $num_files == 0 ) 
	{
		$tbody->appendChild( $self->_make_placeholder );
	}
	else
	{
			foreach my $filename ( keys %files )
			{
				my $tr = $session->make_element( "tr" );
				
				if( $show_radios )
				{
					my $prefix = $session->{prefix};
					$prefix .= $document->get_id()."_";
					my $td_primary = $session->make_element( "td" );
					my $radio = $session->make_element( 
						"input",
						type => "radio",
						name => $prefix."_primary",
						value => "" );
					if( $main_file eq $filename )
					{
						$radio->setAttribute( "checked", "1" );
					}
					
					$td_primary->appendChild( $radio );
					$tr->appendChild( $td_primary );
				}
				
				my $td_filename = $session->make_element( "td" );
				$td_filename->appendChild( $session->make_text( $filename ) );
				$tr->appendChild( $td_filename );
				
				my $td_filesize = $session->make_element( "td" );
				$td_filesize->appendChild( $session->make_text( $files{$filename} ) );
				$tr->appendChild( $td_filesize );
				
				my $td_filetype = $session->make_element( "td" );
				$td_filetype->appendChild( $session->make_text( "" ) );
				$tr->appendChild( $td_filetype );
				
				$tbody->appendChild( $tr );
			}
	}
	
	$table->appendChild( $tbody );
	
	return $table;
}
sub render_content
{
	my( $self, $surround ) = @_;
	
	my $session = $self->{session};
	my $out = $self->{session}->make_element( "div", class => "wf_uploadcomponent" );
	$out->appendChild( $self->_make_addbar );	

	my $eprint = $self->{workflow}->{item};

	my @formats = $eprint->required_formats;
	my @eprint_docs = $eprint->get_all_documents;

	
	# Collate the documents by type to make ordering easier.
	
	my %doc_formats = ();

	foreach my $doc ( @eprint_docs )
	{
		my $format = $doc->get_value( "format" );
		if( !$doc_formats{$format} )
		{
			$doc_formats{$format} = [];
		}
		push @{$doc_formats{$format}}, $doc;
	}
	
	# Build tab list

	my $script = $session->make_element( "script", type=>"text/javascript" );
	$out->appendChild( $script );
	$script->appendChild( $session->make_text( '
window.ep_showTab = function( baseid, tabid )
{

	panels = document.getElementById( baseid+"_panels" );
	for( i=0; ep_lt(i,panels.childNodes.length); i++ ) 
	{
		child = panels.childNodes[i];
		child.style.display = "none";
	}

	tabs = document.getElementById( baseid+"_tabs" );
	for( i=0; ep_lt(i,tabs.childNodes.length); i++ ) 
	{
		child = tabs.childNodes[i];
		if( child.className == "ep_tab_selected" )
		{
			child.className = "ep_tab";
		}
	}

	panel = document.getElementById( baseid+"_panel_"+tabid );
	panel.style.display = "block";

	tab = document.getElementById( baseid+"_tab_"+tabid );
	tab.style.font_size = "30px";
	tab.className = "ep_tab_selected";

	current = document.getElementById( baseid+"_current" );
	current.value = tabid;
};

' ) );


	my $tab_table = $session->make_element( "table", class=>"ep_tabs", cellspacing=>0 );
	my $tab_tr = $session->make_element( "tr", id=> $self->{prefix}."_tabs" );
	$tab_table->appendChild( $tab_tr );

	my $spacer = $session->make_element( "td", class=>"ep_tab_spacer" );
	$spacer->appendChild( $session->render_nbsp );
	$tab_tr->appendChild( $spacer );


	my $format_block = $session->make_element( "div", id => $self->{prefix}."_panels", class=>"ep_tab_panel" );
	my $first = undef;

	if( $self->param( "current" ) )
	{
		$first = $self->param( "current" );
	}
	
	foreach my $format ( @formats )
	{
		my $doc_ds = $self->{session}->get_repository->get_dataset(
		            "document" );
	
		foreach my $document ( @{$doc_formats{$format}} )
		{

			my $base = $self->{prefix};
			my $tabid = $document->get_id;
			
			if( !defined $first )
			{
				$first = $tabid;
			}
			
			my $id = $base."_tab_".$tabid;
			my %td_opts = ( id => $id, class=>"ep_tab" );
			if( $tabid eq $first ) { $td_opts{class} = "ep_tab_selected"; }
			my %a_opts = ( 
				onClick => "ep_showTab('$base','$tabid' ); return false;", 
				href    => "#", 
			);
			my $a = $session->make_element( "a", %a_opts );
			my $td = $session->make_element( "td", %td_opts );
			my $label = $doc_ds->render_type_name( $session, $format );
			$a->appendChild( $label );
			#my %files = $document->files;
			#my $main_file = $document->get_main;
			#my $num_files = scalar keys %files;
			#$a->appendChild( $session->make_text( " ($num_files)" ) ); # html phrase 
			$td->appendChild( $a );
			$tab_tr->appendChild( $td );
		
			my $spacer = $session->make_element( "td", class=>"ep_tab_spacer" );
			$spacer->appendChild( $session->render_nbsp );
			$tab_tr->appendChild( $spacer );
				
			my %format_opts = ( class => "wf_format", id => $base."_panel_".$tabid );
			if( $tabid ne $first )
			{
				$format_opts{style} = "display: none";
			}

			my $format_div = $session->make_element( "div", %format_opts ); 

			
			my $format_name_div = $session->make_element( "div", class => "wf_format_name" );
			$format_name_div->appendChild( $doc_ds->render_type_name( $session, $format ) );
			
			$format_div->appendChild( $format_name_div );
			$format_div->appendChild( $self->_make_toolbar( $document, $format ) );
			$format_div->appendChild( $self->_make_filelist( $document ) );
			$format_div->appendChild( $self->_make_uploadbar( $document ) );
			$format_block->appendChild( $format_div );	
		}
	}
	my $current = $session->make_element( "input", type => "hidden", name => $self->{prefix}."_current", id => $self->{prefix}."_current", value => $first );
	$out->appendChild( $current );
	$out->appendChild( $tab_table );
	$out->appendChild( $format_block );
	return $out;
}

sub render_title
{
	my( $self, $surround ) = @_;
	return $self->{session}->html_phrase( "lib/submissionform:title_fileview" );	
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


1;





