package EPrints::Plugin::InputForm::UploadMethod::openxml;

use EPrints;
use EPrints::Plugin::InputForm::UploadMethod;

@ISA = ( "EPrints::Plugin::InputForm::UploadMethod" );



use strict;

sub render_tab_title
{
	my( $self ) = @_;

	return $self->{session}->make_text( "From OpenXML" );
}

sub update_from_form
{
	my( $self, $processor ) = @_;
	
	my $doc_data = {
		_parent => $self->{dataobj},
		eprintid => $self->{dataobj}->get_id
		};


# test that file is of type docx, pptx, xlsx or return

	my $repository = $self->{session}->get_repository;
	my $fn = $self->{session}->param( $self->{prefix}."_first_file_openxml" );

	unless( $fn =~ /\.docx|pptx|xlsx$/ )
	{
		$processor->add_message( "error", $self->{session}->make_text( "Upload failed: unsupported file format." ) );
		return;
	}

	$doc_data->{format} = $repository->call( 'guess_doc_type', 
		$self->{session},
		$fn );

	my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
	my $document = $doc_ds->create_object( $self->{session}, $doc_data );
	if( !defined $document )
	{
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}
	my $success = EPrints::Apache::AnApache::upload_doc_file( 
		$self->{session},
		$document,
		$self->{prefix}."_first_file_openxml" );
	if( !$success )
	{
		$document->remove();
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:upload_failed" ) );
		return;
	}

	# here: get params (extract media,metadata,both)
	# here: call Convert/Export doc plugin

	my $plugin = $self->{session}->plugin( "Convert::OpenXML" );
        if( !$plugin )
	{
		$processor->add_message( "error", $self->html_phrase( "plugin_error" ) );
		# should delete the doc?
		return;
	}

	my $convert_type = $self->{session}->param( $self->{prefix}."_first_file_openxml_options" );
	$convert_type = 'both' unless( defined $convert_type );

	my @new_docs = $plugin->convert( $self->{dataobj}, $document, $convert_type );

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$document->get_id} = 1;
}

sub render_add_document
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $f = $self->{session}->make_doc_fragment;

	$f->appendChild( $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:new_document" ) );

	my $ffname = $self->{prefix}."_first_file_openxml";	
	my $file_button = $self->{session}->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $add_format_button = $self->{session}->render_button(
		value => $self->{session}->phrase( "Plugin/InputForm/Component/Upload:add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format_".$self->get_id,
	);
	$f->appendChild( $file_button );
	$f->appendChild( $session->make_text( " " ) );
	$f->appendChild( $self->{session}->make_text( " " ) );
	$f->appendChild( $add_format_button );

	my $script = $self->{session}->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->{session}->phrase("Plugin/InputForm/Component/Upload:really_next"))." ); } return true; } );" );
	$f->appendChild( $script);

	# add the option list now
	
	my $opt_box = $self->{session}->make_element( "div", "style"=>"padding: 15px;" );
	$f->appendChild( $opt_box );

	$opt_box->appendChild( $self->{session}->make_text( "Extract: " ) );

	my $list = $self->{session}->make_element( "select", name=> $self->{prefix}."_first_file_openxml_options", id=> $self->{prefix}."_first_file_openxml_options" );
	$opt_box->appendChild( $list );

	my $opt;
	$opt = $self->{session}->make_element( "option", value=> "both", selected=>"selected" );
	$list->appendChild( $opt );
	$opt->appendChild( $self->{session}->make_text( "metadata and media files" ) );

	$opt = $self->{session}->make_element( "option", value=> "media" );
	$list->appendChild( $opt );
	$opt->appendChild( $self->{session}->make_text( "media files only" ) );

	$opt = $self->{session}->make_element( "option", value=> "metadata" );
	$list->appendChild( $opt );
	$opt->appendChild( $self->{session}->make_text( "metadata only" ) );

	return $f;
}



1;
