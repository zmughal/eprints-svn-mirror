package EPrints::Plugin::InputForm::Component::Upload;

use EPrints;
use EPrints::Plugin::InputForm::Component;
@ISA = ( "EPrints::Plugin::InputForm::Component" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Upload";
	$self->{visible} = "all";
	return $self;
}

# only returns a value if it belongs to this component
sub update_from_form
{
	my( $self ) = @_;

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
				$self->{session}, 
				$self->{dataobj}, 
				$doc_prefix );
			$doc->set_value( $field->{name}, $value );
		}
		$doc->commit;
	}

	if( $self->{session}->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;

		if( $internal eq "add_format" )
		{
			my $doc_data = { eprintid => $self->{dataobj}->get_id };

        		my @formats = $self->{session}->get_repository->get_types( "document" );
			# make a very loose stab at the file format
			my $filename = $self->{session}->param( $self->{prefix}."_first_file" );
			if( $filename=~m/\.([^.]+)$/ )
			{
				my $suffix = $1;
				foreach my $format ( @formats ) 
				{ 
					if( $suffix eq $format )
					{
						$doc_data->{format} = $suffix;
						last;
					}
					# some hacks
					if( $suffix eq "htm" && $format eq "html" ) { $doc_data->{format} = $format; }
					if( $suffix eq "txt" && $format eq "ascii" ) { $doc_data->{format} = $format; }
					if( $suffix eq "jpg" && $format eq "image" ) { $doc_data->{format} = $format; }
					if( $suffix eq "gif" && $format eq "image" ) { $doc_data->{format} = $format; }
					if( $suffix eq "png" && $format eq "image" ) { $doc_data->{format} = $format; }
				}
			}

			my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
			my $document = $doc_ds->create_object( $self->{session}, $doc_data );
			if( !defined $document )
			{
				return $self->{session}->make_text( "Create document failed." );
			}
			my $success = EPrints::Apache::AnApache::upload_doc_file( 
				$self->{session},
				$document,
				$self->{prefix}."_first_file" );
			if( !$success )
			{
				$document->remove();
				return $self->{session}->make_text( "File upload failed." );
			}
			return ();
		}

		if( $internal =~ m/^doc(\d+-\d+)_(.*)$/ )
		{
			my $doc = EPrints::DataObj::Document->new(
				$self->{session},
				$1 );
			if( !defined $doc )
			{
				return $self->{session}->make_text( "Attempted action on non-existant document: $1." );
			}
			if( $doc->get_value( "eprintid" ) != $self->{dataobj}->get_id )
			{
				return $self->{session}->make_text( "Specified document does not belong to current item." );
			}
			return $self->doc_update( $doc, $2 );
		}

		return $self->{session}->make_text( "Unknown internal button: $internal" );
	}

	return ();
}

sub doc_update
{
	my( $self, $doc, $doc_internal ) = @_;

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;
	
	# for now a null op. Could maybe validate.
	if( $doc_internal eq "change" )
	{
		return ();
	}
			
	if( $doc_internal eq "delete_doc" )
	{
		$doc->remove();
		return ();
	}

	if( $doc_internal eq "add_file" )
	{
		my $success = EPrints::Apache::AnApache::upload_doc_file( 
			$self->{session},
			$doc,
			$doc_prefix."_file" );
		if( !$success )
		{
			return $self->{session}->make_text( "File upload failed." );
		}
		return ();
	}

	if( $doc_internal =~ m/^delete_(\d+)$/ )
	{
		my $fileid = $1;
		
		my %files_unsorted = $doc->files();
		my @files = sort keys %files_unsorted;

		if( !defined $files[$fileid] )
		{
			return $self->{session}->make_text( "File does not exist." );
		}
		
		$doc->remove_file( $files[$fileid] );
		return ();
	}

	if( $doc_internal =~ m/^main_(\d+)$/ )
	{
		my $fileid = $1;

		my %files_unsorted = $doc->files();
		my @files = sort keys %files_unsorted;

		if( !defined $files[$fileid] )
		{
			return $self->{session}->make_text( "File does not exist." );
		}
		
		# Pressed "Show First" button for this file
		$doc->set_main( $files[$fileid] );
		$doc->commit;
		return ();
	}
			
	return $self->{session}->make_text( "Unknown internal document button: $doc_internal" );
}
	
sub render_help
{
	my( $self, $surround ) = @_;
	return $self->{session}->make_text( "Help goes here" );
}

sub render_title
{
	my( $self, $surround ) = @_;
	return $self->{session}->make_text( "Document upload" );
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

	my $view = $session->param( $self->{prefix}."_view" );

	my $internal = $self->get_internal_button;
	my $affected_doc_id = undef;
	if( $internal =~ m/^doc(\d+-\d+)_(.*)$/ )
	{
		$affected_doc_id = $1;
	}
	my $tabs = [];
	my $labels = {};
	my $links = {};
	my @docids  = ();
	foreach my $doc ( @eprint_docs )
	{	
		push @docids, $doc->get_id;
		$labels->{$doc->get_id} = $doc->render_description;
	}

	@docids = sort @docids;

	foreach my $view_id ( @docids )
	{
		$view = $view_id if !defined $view;

		# so it's on or next to the last affected doc 
		if( defined $affected_doc_id && !( $view_id gt $affected_doc_id ) )
		{
			$view = $view_id;
		}
			
		push @{$tabs}, $view_id;
		#$labels->{$view_id} = $self->{session}->make_text( $view_id );
		$links->{$view_id} = "#"; # javascript only tabs
	}

	if( defined $internal && $internal eq "add_format" )
	{
		# id of last doc if we just added one.
		$view = $docids[-1];
	}

	my $tab_bar = $session->make_element( "div", class=>"ep_only_js" );
	$f->appendChild( $tab_bar );
	$tab_bar->appendChild( 
		$self->{session}->render_tabs( 
			$self->{prefix},
			$view,
			$tabs,
			$labels,
			$links ) );

	my $panel = $self->{session}->make_element( "div", id=>$self->{prefix}."_panels" );
	$f->appendChild( $panel );
	
	foreach my $doc ( @eprint_docs )
	{	
		my $view_id = $doc->get_id;
		my $hide = "";
		if( $view_id ne $view )
		{
			$hide = 'ep_no_js';
		}
		my $doc_div = $self->{session}->make_element( "div", id=>$self->{prefix}."_panel_$view_id",  class=>"ep_upload_doc $hide" );
		$panel->appendChild( $doc_div );
		my $doc_title = $session->make_element( "div", class=>"ep_upload_doc_title ep_no_js" );
		$doc_title->appendChild( $doc->render_description );
		$doc_div->appendChild( $doc_title );

		$doc_div->appendChild( $self->_render_doc( $doc ) );
	}

	return $f;
}

sub doc_fields
{
	my( $self, $document ) = @_;

	my @fields = ();
	my $ds = $self->{session}->get_repository->get_dataset('document');
	foreach( "format", "formatdesc", "language", "security", "license" )
	{
		next if( $self->{session}->get_repository->get_conf(
			"submission_hide_".$_ ) );
		push @fields, $ds->get_field( $_ );
	}

	my %files = $document->files;
	if( scalar keys %files > 1 )
	{
		push @fields, $ds->get_field( "main" );
	}
	
	return @fields;
}


sub _render_doc
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};	

	my $doc_cont = $session->make_element( "div", class=>"ep_tab_panel" );

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my @fields = $self->doc_fields( $doc );

	if( scalar @fields )
	{
		my $table = $session->make_element( "table" );
		$doc_cont->appendChild( $table );
		foreach my $field ( @fields )
		{
			my $tr = $session->make_element( "tr" );
			$table->appendChild( $tr );
			my $th = $session->make_element( "th" );
			$tr->appendChild( $th );
			$th->appendChild( $field->render_name($session) );
			my $td = $session->make_element( "td" );
			$tr->appendChild( $td );
			$td->appendChild( $field->render_input_field( 
				$session, 
				$doc->get_value( $field->get_name ),
				undef,
				undef,
				0,
				undef,
				$doc,
				$doc_prefix ) );
		}
	}

	my $tool_div = $session->make_element( "div" );
	my $delete_fmt_button = $session->make_element( "input",
		name => "_internal_".$doc_prefix."_delete_doc",
		value => "Delete document",
		class => "ep_form_internal_button",
		type => "submit",
		onClick => "if( !confirm( 'Delete entire document: are you sure?' ) ) { return false; }",
		);
	my $update_fmt_button = $session->make_element( "input",
		name => "_internal_".$doc_prefix."_change",
		value => "Change",
		class => "ep_form_internal_button",
		type => "submit",
		);

	$tool_div->appendChild( $update_fmt_button );
	$tool_div->appendChild( $session->make_text( " " ) );
	$tool_div->appendChild( $delete_fmt_button );

	$doc_cont->appendChild( $tool_div );



	my $files = $session->make_element( "div", class=>"ep_upload_files" );
	$doc_cont->appendChild( $files );
	$files->appendChild( $self->_render_filelist( $doc ) );
	$files->appendChild( $self->_render_add_file( $doc ) );

	return $doc_cont;
}
			

sub _render_add_document
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $toolbar = $session->make_element( "div", class=>"ep_toolbox_content ep_upload_newdoc" );
	$toolbar->appendChild( $session->make_text( "New document: " ) );
	
	my $file_button = $session->make_element( "input",
		name => $self->{prefix}."_first_file",
		type => "file",
		);
	my $add_format_button = $session->make_element( "input", 
		type => "submit", 
		value => "Add", 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format" );
	$toolbar->appendChild( $file_button );
	$toolbar->appendChild( $session->make_text( " " ) );
	$toolbar->appendChild( $add_format_button );
	
	return $toolbar; 
}

sub _render_add_file
{
	my( $self, $document ) = @_;

	my $session = $self->{session};
	
	# Create a document-specific prefix
	my $docid = $document->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $toolbar = $session->make_element( "div" );
	my $file_button = $session->make_element( "input",
		name => $doc_prefix."_file",
		id => "filename",
		type => "file",
		);
	my $upload_button = $session->make_element( "input",
		name => "_internal_".$doc_prefix."_add_file",
		class => "ep_form_internal_button",
		value => "Add file",
		type => "submit",
		);
	
	
	$toolbar->appendChild( $file_button );
	$toolbar->appendChild( $session->make_text( " " ) );
	$toolbar->appendChild( $upload_button );
	return $toolbar; 
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
			src => "/images/style/delete.png",
			name => "_internal_".$doc_prefix."_delete_$i",
			onClick => "if( !confirm( 'Delete file $filename: are you sure?' ) ) { return false; }",
			value => "Delete" );
			
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
	$td->appendChild( $session->make_text( "Please upload some files." ) );
	$placeholder->appendChild( $td );
	return $placeholder;
}

1;
