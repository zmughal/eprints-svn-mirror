######################################################################
#
# EPrints::SubmissionForm
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

B<EPrints::SubmissionForm> - undocumented

=head1 DESCRIPTION

undocumented

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

######################################################################
#
#  EPrints Submission uploading/editing forms
#
######################################################################
#
#  __LICENSE__
#
######################################################################

package EPrints::SubmissionForm;

use EPrints::EPrint;
use EPrints::Session;
use EPrints::Document;

use Unicode::String qw(utf8 latin1);
use strict;

# Stages of upload

#cjg bug pruning very new doc?

my $STAGES = {
	home => { next => "type" },
	type => { prev => "return", next => "linking" },
	linking => { prev => "type", next => "meta" },
	meta => { prev => "linking", next => "files" },
	files => { prev => "meta", next => "verify" },
	docmeta => {},
	fileview => {},
	upload => {},
	verify => { prev => "files", next => "done" },
	quickverify => { prev => "return", next => "done" },
	done => {},
	return => {},
	confirmdel => { prev => "return", next => "return" }
};


######################################################################
=pod

=item $thing = EPrints::SubmissionForm->new( $redirect, $staff, $dataset, $formtarget )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $redirect, $staff, $dataset, $formtarget, $autosend ) = trim_params(@_);
	
	my $self = {};
	bless $self, $class;

	$self->{redirect} = $redirect;
	$self->{staff} = $staff;
	$self->{dataset} = $dataset;
	$self->{formtarget} = $formtarget;
	$self->{for_archive} = $staff;
	$self->{autosend} = $autosend;
	unless( defined $self->{autosend} ) { $self->{autosend} = 1; }
	
	# Use user configured order for stages or...
	$self->{stages} = &ARCHIVE->get_conf( "submission_stages" );

	$self->{stages} = $STAGES if( !defined $self->{stages} );

	return( $self );
}


######################################################################
#
# process()
#
#  Process everything from the previous form, and render the next.
#
######################################################################


######################################################################
=pod

=item $foo = $thing->process

undocumented

=cut
######################################################################

sub process
{
	my( $self ) = @_;
	
	$self->{action}    = &SESSION->get_action_button();
	$self->{stage}     = &SESSION->param( "stage" );
	$self->{eprintid}  = &SESSION->param( "eprintid" );
	$self->{user}      = &SESSION->current_user();

	# If we have an EPrint ID, retrieve its entry from the database
	if( defined $self->{eprintid} )
	{
		if( $self->{staff} )
		{
			if( defined &SESSION->param( "dataset" ) )
			{
				$self->{dataset} = &ARCHIVE->get_dataset( 
					&SESSION->param( "dataset" ) );
			}
		}
		$self->{eprint} = EPrints::EPrint->new( 
			$self->{eprintid},
			$self->{dataset} );

		# Check it was retrieved OK
		if( !defined $self->{eprint} )
		{
			my $db_error = &DATABASE->error;
			&ARCHIVE->log( "Database Error: $db_error" );
			$self->_database_err;
			return( 0 );
		}

		# check that we got the record we wanted - if we didn't
		# then something is heap big bad. ( This is being a bit
		# over paranoid, but what the hell )
		if( &SESSION->param( "eprintid" ) ne
	    		$self->{eprint}->get_value( "eprintid" ) )
		{
			my $form_id = &SESSION->param( "eprintid" );
			&ARCHIVE->log( 
				"Form error: EPrint ID in form ".
				&SESSION->param( "eprintid" ).
				" doesn't match object id ".
				$self->{eprint}->get_value( "eprintid" ) );
			$self->_corrupt_err;
			return( 0 );
		}

		# Check it's owned by the current user
		if( !$self->{staff} && !$self->{user}->is_owner( $self->{eprint} ) )
		{
			&ARCHIVE->log( 
				"Illegal attempt to edit record ".
				$self->{eprint}->get_value( "eprintid" ).
				" by user with id ".
				$self->{user}->get_value( "userid" ) );
			$self->_corrupt_err;
			return( 0 );
		}
	}

	$self->{problems} = [];
	my $ok = 1;
	# Process data from previous stage

	if( !defined $self->{stage} )
	{
		$self->{stage} = "home";
	}
	else
	{
		# For stages other than home, 
		# if we don't have an eprint then something's
		# gone wrong.
		if( !defined $self->{eprint} )
		{
			$self->_corrupt_err;
			return( 0 );
		}
	}

	if( !defined $self->{stages}->{$self->{stage}} )
	{
		# It's not a valid stage. 
		if( !defined $self->{eprint} )
		{
			$self->_corrupt_err;
			return( 0 );
		}
	}

	# Process the results of that stage - done 
	# by calling the function &_from_stage_<stage>
	my $function_name = "_from_stage_".$self->{stage};
	{
		no strict 'refs';
		$ok = $self->$function_name();
	}

	if( $ok )
	{
		# Render stuff for next stage

		my $stage = $self->{new_stage};

		my $page;
		my $function_name = "_do_stage_".$stage;
		{
			no strict 'refs';
			$page = $self->$function_name();
		}

		if( $self->{autosend} )
		{	
			my $title_phraseid = "lib/submissionform:title_".$stage;
			if( defined $self->{title_phrase} && 
				&SESSION->get_lang->has_phrase( 
						$self->{title_phrase} ) )
			{
				$title_phraseid = $self->{title_phrase};
			}
				
			&SESSION->build_page(
				&SESSION->html_phrase( 
					$title_phraseid,
					type => $self->{eprint}->render_value( "type" ),
					eprintid => $self->{eprint}->render_value( "eprintid" ),
					desc => $self->{eprint}->render_description ),
				$page,
				"submission_".$stage );
			&SESSION->send_page();
		}
		else
		{
			$self->{page} = $page;
		}
	}
	return( 1 );
}

#cjg notdoc
sub get_page
{
	my( $self ) = @_;

	return $self->{page};
}
#cjg notdoc
sub get_stage
{
	my( $self ) = @_;

	return $self->{new_stage};
}

######################################################################
# 
# $foo = $thing->_corrupt_err
#
# undocumented
#
######################################################################

sub _corrupt_err
{
	my( $self ) = @_;

	&SESSION->render_error( 
		&SESSION->html_phrase( 
			"lib/submissionform:corrupt_err",
			line_no => 
				&SESSION->make_text( (caller())[2] ) ),
		&ARCHIVE->get_conf( "userhome" ) );

}

######################################################################
# 
# $foo = $thing->_database_err
#
# undocumented
#
######################################################################

sub _database_err
{
	my( $self ) = @_;

	&SESSION->render_error( 
		&SESSION->html_phrase( 
			"lib/submissionform:database_err",
			line_no => 
				&SESSION->make_text( (caller())[2] ) ),
		&ARCHIVE->get_conf( "userhome" ) );
}

######################################################################
#
#  Stage from functions:
#
# $self->{eprint} is the EPrint currently being edited, or undef if
# there isn't one. This may change. $self->{new_stage} should be the
# stage to render next. $self->{problems} should contain any problems
# with uploaded data (fieldname => problem). Some stages may also pass
# any miscellaneous extra info to the next stage.
#
######################################################################


######################################################################
#
#  Came from an external page (usually author or staff home,
#  or bookmarked)
#
######################################################################

######################################################################
# 
# $foo = $thing->_from_stage_home
#
# undocumented
#
######################################################################

sub _from_stage_home
{
	my( $self ) = @_;

	# Create a new EPrint
	if( $self->{action} eq "new" )
	{
		if( $self->{staff} )
		{
			&SESSION->render_error( 
				&SESSION->html_phrase(
		        		"lib/submissionform:use_auth_area" ),
				&ARCHIVE->get_conf( "userhome" ) );
			return( 0 );
		}
		$self->{eprint} = EPrints::EPrint::create( $self->{dataset} );
		$self->{eprint}->set_value( 
			"userid", 
			$self->{user}->get_value( "userid" ) );
		$self->{eprint}->commit();

		if( !defined $self->{eprint} )
		{
			my $db_error = &DATABASE->error();
			&ARCHIVE->log( "Database Error: $db_error" );
			$self->_database_err;
			return( 0 );
		}

		$self->_set_stage_next();
		return( 1 );
	}

	if( $self->{action} eq "edit" )
	{
		if( !defined $self->{eprint} )
		{
			&SESSION->render_error( 
				&SESSION->html_phrase( 
					"lib/submissionform:nosel_err" ),
				&ARCHIVE->get_conf( "userhome" ) );
			return( 0 );
		}

		$self->_set_stage_next;
		return( 1 );
	}


	if( $self->{action} eq "clone" )
	{
		if( !defined $self->{eprint} )
		{
			&SESSION->render_error( 
				&SESSION->html_phrase( 
					"lib/submissionform:nosel_err" ),
				&ARCHIVE->get_conf( "userhome" ) );
			return( 0 );
		}
		
		my $new_eprint = $self->{eprint}->clone( $self->{dataset}, 1 );

		if( defined $new_eprint )
		{
			$self->{new_stage} = "return";
			return( 1 );
		}
		else
		{
			my $error = &DATABASE->error();
			&ARCHIVE->log( "SubmissionForm error: Error cloning EPrint ".$self->{eprint}->get_value( "eprintid" ).": ".$error );
			$self->_database_err;
			return( 0 );
		}
	}

	if( $self->{action} eq "delete" )
	{
		if( !defined $self->{eprint} )
		{
			&SESSION->render_error( 
				&SESSION->html_phrase( 
					"lib/submissionform:nosel_err" ),
				&ARCHIVE->get_conf( "userhome" ) );
			return( 0 );
		}
		$self->{new_stage} = "confirmdel";
		return( 1 );
	}

	if( $self->{action} eq "submit" )
	{
		if( !defined $self->{eprint} )
		{
			&SESSION->render_error( 
				&SESSION->html_phrase( 
					"lib/submissionform:nosel_err" ),
				&ARCHIVE->get_conf( "userhome" ) );
			return( 0 );
		}
		$self->{new_stage} = "quickverify";
		return( 1 );
	}

	if( $self->{action} eq "cancel" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}

	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
}


######################################################################
#
# Come from type form
#
######################################################################

######################################################################
# 
# $foo = $thing->_from_stage_type
#
# undocumented
#
######################################################################

sub _from_stage_type
{
	my( $self ) = @_;

	## Process uploaded data
	$self->_update_from_form( "type" );
	$self->{eprint}->commit();

	if( $self->{action} eq "save" )
	{
		# Saved, return to user home
		$self->{new_stage} = "return";
		return( 1 );
	}

	## Process the action

	if( $self->{action} eq "next" )
	{
		$self->{problems} = $self->{eprint}->validate_type( $self->{for_archive} );
		if( scalar @{$self->{problems}} > 0 )
		{
			# There were problems with the uploaded type, 
			# don't move further
			$self->_set_stage_this();
			return( 1 );
		}

		# No problems, onto the next stage
		$self->_set_stage_next();
		return( 1 );
	}

	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
}

######################################################################
#
#  From sucession/commentary stage
#
######################################################################

######################################################################
# 
# $foo = $thing->_from_stage_linking
#
# undocumented
#
######################################################################

sub _from_stage_linking
{
	my( $self ) = @_;
	
	## Process uploaded data

	$self->_update_from_form( "succeeds" );
	$self->_update_from_form( "commentary" );
	$self->{eprint}->commit();

	## What's the next stage?

	if( $self->{action} eq "save" )
	{
		# Saved, return to user home
		$self->{new_stage} = "return";
		return( 1 );
	}

	if( $self->{action} eq "next" )
	{
		$self->{problems} = $self->{eprint}->validate_linking( $self->{for_archive} );

		if( scalar @{$self->{problems}} > 0 )
		{
			# There were problems with the uploaded type, 
			# don't move further
			$self->_set_stage_this;
			return( 1 );
		}

		# No problems, onto the next stage
		$self->_set_stage_next;
		return( 1 );
	}

	if( $self->{action} eq "prev" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}

	if( $self->{action} eq "verify" )
	{
		# Just stick with this... want to verify ID's
		$self->_set_stage_this;
		return( 1 );
	}
	
	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
}	


######################################################################
#
# Come from metadata entry form
#
######################################################################

######################################################################
# 
# $foo = $thing->_from_stage_meta
#
# undocumented
#
######################################################################

sub _from_stage_meta
{
	my( $self ) = @_;

	# Process uploaded data

	my @pages = $self->{dataset}->get_type_pages(
                                        $self->{eprint}->get_value( "type" ) );

	$self->{pageid} = &SESSION->param( "pageid" );
	my $ok = 0;
	my $nextpage;
	my $prevpage;
	foreach( @pages )
	{
		if( $ok )
		{
			$nextpage = $_;
			last;
		}
		$ok = 1 if( $_ eq $self->{pageid} );
		if( !$ok ) 
		{
			$prevpage = $_;
		}
	}

	if( !$ok )
	{
		$self->_corrupt_err;
		return( 0 );
	}

	my @fields = $self->{dataset}->get_page_fields( 
		$self->{eprint}->get_value( "type" ), 
		$self->{pageid},
		$self->{staff} );

	my $field;
	foreach $field (@fields)
	{
		$self->_update_from_form( $field->get_name() );
	}
	$self->{eprint}->commit();

	# What stage now?

	if( &SESSION->internal_button_pressed() )
	{
		# Leave the form as is
		$self->_set_stage_this;
		return( 1 );
	}

	if( $self->{action} eq "save" )
	{
		# Saved, return to user home
		$self->{new_stage} = "return";
		return( 1 );
	}

	if( $self->{action} eq "next" )
	{
		if( defined $nextpage )
		{
			# check for problems in this page only
			$self->{problems} = 
				$self->{eprint}->validate_meta_page( 
					$self->{pageid},
					$self->{for_archive} );
			if( scalar @{$self->{problems}} > 0 )
			{
				$self->_set_stage_this;
				return( 1 );
			}

			$self->_set_stage_this;
			$self->{pageid} = $nextpage;
			return( 1 );
		} 
	
		# validation checks
		$self->{problems} = 
			$self->{eprint}->validate_meta( $self->{for_archive} );

		if( scalar @{$self->{problems}} > 0 )
		{
			# There were problems with the uploaded type, 
			# don't move further

			$self->{pageid} = $pages[0];
			$self->_set_stage_this;
			return( 1 );
		}

		# No problems, onto the next stage
		$self->_set_stage_next;
		return( 1 );
	}

	if( $self->{action} eq "prev" )
	{
		if( defined $prevpage )
		{
			$self->_set_stage_this;
			$self->{pageid} = $prevpage;
			return( 1 );
		}
		$self->_set_stage_prev;
		return( 1 );
	}
	
	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
}


######################################################################
#
#  From "select files" page
#
######################################################################

######################################################################
# 
# $foo = $thing->_from_stage_files
#
# undocumented
#
######################################################################

sub _from_stage_files
{
	my( $self ) = @_;

	# update an automatics which may relate to documents
	$self->{eprint}->commit();

	if( $self->{action} eq "save" )
	{
		# Saved, return to user home
		$self->{new_stage} = "return";
		return( 1 );
	}

	if( $self->{action} eq "prev" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}
		
	if( $self->{action} eq "newdoc" )
	{
		$self->{document} = EPrints::Document::create( 
			$self->{eprint} );
		if( !defined $self->{document} )
		{
			$self->_database_err;
			return( 0 );
		}

		$self->{new_stage} = "docmeta";
		return( 1 );
	}

	if( $self->{action} eq "next" )
	{
		$self->{problems} = $self->{eprint}->validate_documents( $self->{for_archive} );

		if( $#{$self->{problems}} >= 0 )
		{
			# Problems, don't advance a stage
			$self->_set_stage_this;
			return( 1 )
		}

		$self->_set_stage_next;
		return( 1 );
	}

	#### The other actions ( edit & remove ) have a doc
	#### Attached to their action id.

	unless( $self->{action} =~ m/^([a-z]+)_(.*)$/ )
	{
		$self->_corrupt_err;
		return( 0 );
	}
	my( $doc_action, $docid ) = ( $1, $2 );
		
	# Find relevant document object
	$self->{document} = EPrints::Document->new( $docid );

	if( !defined $self->{document} )
	{
		$self->_corrupt_err;
		return( 0 );
	}

	if( $doc_action eq "remove" )
	{
		# Remove the offending document
		if( !$self->{document}->remove() )
		{
			$self->_corrupt_err;
			return( 0 );
		}

		$self->{new_stage} = "files";
		return( 1 );
	}

	if( $doc_action eq "edit" )
	{
		$self->{new_stage} = "docmeta";
		return( 1 );
	}

	$self->_corrupt_err;
	return( 0 );
}

######################################################################
#
#  From docmeta page
#
######################################################################

######################################################################
# 
# $foo = $thing->_from_stage_docmeta
#
# undocumented
#
######################################################################

sub _from_stage_docmeta
{
	my( $self ) = @_;

	# Check the document is OK, and that it is associated with the current
	# eprint
	$self->{document} = EPrints::Document->new(
		&SESSION->param( "docid" ) );

	if( !defined $self->{document} ||
	    $self->{document}->get_value( "eprintid" ) ne $self->{eprint}->get_value( "eprintid" ) )
	{
		$self->_corrupt_err;
		return( 0 );
	}

	if( $self->{action} eq "cancel" )
	{
		$self->{new_stage} = "files";
		return( 1 );
	}

	if( $self->{action} eq "next" )
	{
		# Update the description if appropriate
		foreach( "formatdesc", "format", "language", "security" )
		{
			next if( &ARCHIVE->get_conf( "submission_hide_".$_ ) );
			$self->{document}->set_value( $_,
				&SESSION->param( $_ ) );
		}
		$self->{document}->commit();

		$self->{problems} = $self->{document}->validate_meta( $self->{for_archive} );
			
		if( $#{$self->{problems}} >= 0 )
		{
			$self->{new_stage} = "docmeta";
			return( 1 );
		}

		$self->{new_stage} = "fileview";
		return( 1 );
	}
	
	# Erk! Unknown action.
	$self->_corrupt_err;
	return( 0 );
}

######################################################################
#
#  From fileview page
#
######################################################################

######################################################################
# 
# $foo = $thing->_from_stage_fileview
#
# undocumented
#
######################################################################

sub _from_stage_fileview
{
	my( $self ) = @_;

	# Check the document is OK, and that it is associated with the current
	# eprint
	$self->{document} = EPrints::Document->new(
		&SESSION->param( "docid" ) );

	if( !defined $self->{document} ||
	    $self->{document}->get_value( "eprintid" ) ne $self->{eprint}->get_value( "eprintid" ) )
	{
		$self->_corrupt_err;
		return( 0 );
	}

	my %files_unsorted = $self->{document}->files();
	my @files = sort keys %files_unsorted;
	my $i;
	my $consumed = 0;
	
	# Determine which button was pressed
	if( $self->{action} eq "deleteall" )
	{
		# Delete all button
		$self->{document}->remove_all_files();
		$consumed = 1;
	}

	if( $self->{action} =~ m/^main_(\d+)/ )
	{
		if( !defined $files[$1] )
		{
			# Not a valid filenumber
			$self->_corrupt_err;
			return( 0 );
		}
		# Pressed "Show First" button for this file
		$self->{document}->set_main( $files[$1] );
		$consumed = 1;
	}

	if( $self->{action} =~ m/^delete_(\d+)/ )
	{
		if( !defined $files[$1] )
		{
			# Not a valid filenumber
			$self->_corrupt_err;
			return( 0 );
		}
		# Pressed "Delete" button for this file
		$self->{document}->remove_file( $files[$1] );
		$consumed = 1;
	}


	if( $self->{action} eq "upload" )
	{
		my $arc_format = &SESSION->param( "arc_format" );
		my $success = 0;

		if( $arc_format eq "plain" )
		{
			$success = EPrints::AnApache::upload_doc_file( 
				$self->{document},
				'file' );
		}
		elsif( $arc_format eq "graburl" )
		{
			my $url = &SESSION->param( "url" );
			$success = $self->{document}->upload_url( $url );
		}
		else
		{
			$success = EPrints::AnApache::upload_doc_archive( 
				$self->{document},
				'file',
				$arc_format );
		}
		
		if( !$success )
		{
			$self->{problems} = [
				&SESSION->html_phrase( "lib/submissionform:upload_prob" ) ];
		}
		elsif( !defined $self->{document}->get_main() )
		{
			my %files = $self->{document}->files();
			if( scalar keys %files == 1 )
			{
				# There's a single uploaded file, make it the main one.
				my @filenames = keys %files;
				$self->{document}->set_main( $filenames[0] );
			}
		}

		$self->{document}->commit();

		$consumed = 1;
	}

	
	# Check to see if a fileview button was pressed, process it if necessary
	if( $consumed )
	{
		# Doc object will have updated as appropriate, commit changes
		unless( $self->{document}->commit() )
		{
			$self->_database_err;
			return( 0 );
		}
		
		$self->{new_stage} = "fileview";
		return( 1 );
	}

	if( $self->{action} eq "prev" )
	{
		$self->{new_stage} = "docmeta";
		return( 1 );
	}

	if( $self->{action} eq "cancel" )
	{
		$self->{new_stage} = "files";
		return( 1 );
	}

#	if( $self->{action} eq "upload" )
#	{
#		# Set up info for next stage
#		$self->{arc_format} = &SESSION->param( "arc_format" );
#		$self->{num_files} = &SESSION->param( "num_files" );
#		$self->{new_stage} = "upload";
#		return( 1 );
#	}

	if( $self->{action} eq "finished" )
	{
		# Finished uploading apparently. Validate.
		$self->{problems} = $self->{document}->validate( $self->{for_archive} );
			
		if( $#{$self->{problems}} >= 0 )
		{
			$self->{new_stage} = "fileview";
			return( 1 );
		}

		$self->{new_stage} = "files";
		return( 1 );
	}
	
	# Erk! Unknown action.
	$self->_corrupt_err;
	return( 0 );
}



######################################################################
#
#  Come from verify page
#
######################################################################

######################################################################
# 
# EPrints::SubmissionForm::_from_stage_quickverify { return $_[0]->_from_stage_verify; }( _from_stage_quickverify { return $_[0]->_from_stage_verify; } )
#
# undocumented
#
######################################################################

sub _from_stage_quickverify { return $_[0]->_from_stage_verify; }

sub _from_stage_verify
{
	my( $self ) = @_;

	if( $self->{action} eq "prev" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}

	if( $self->{action} eq "later" )
	{
		$self->{new_stage} = "return";
		return( 1 );
	}

	if( $self->{action} eq "submit" )
	{
		# Do the commit to the archive thang. One last check...
		my $problems = $self->{eprint}->validate_full( $self->{for_archive} );
		
		if( scalar @{$problems} == 0 )
		{
			# OK, no problems, submit it to the archive

			my $sb = &ARCHIVE->get_conf( "skip_buffer" );	
			if( defined $sb && $sb == 1 )
			{
				if( $self->{eprint}->move_to_archive() )
				{
					$self->_set_stage_next;
					return( 1 );
				}
			}	
			else
			{
				if( $self->{eprint}->move_to_buffer() )
				{
					$self->_set_stage_next;
					return( 1 );
				}
			}
	
			$self->_database_err;
			return( 0 );
		}
		
		# Have problems, back to verify
		$self->_set_stage_this;
		return( 1 );
	}

	$self->_corrupt_err;
	return( 0 );
}



######################################################################
#
#  Come from confirm deletion page
#
######################################################################

######################################################################
# 
# $foo = $thing->_from_stage_confirmdel
#
# undocumented
#
######################################################################

sub _from_stage_confirmdel
{
	my( $self ) = @_;

	if( $self->{action} eq "confirm" )
	{
		if( !$self->{eprint}->remove() )
		{
			my $db_error = &DATABASE->error();
			&ARCHIVE->log( "DB error removing EPrint ".$self->{eprint}->get_value( "eprintid" ).": $db_error" );
			$self->_database_err;
			return( 0 );
		}

		$self->_set_stage_next;
		return( 1 );
	}

	if( $self->{action} eq "cancel" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}
	
	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
}





######################################################################
#
#  Functions to render the form for each stage.
#
######################################################################


######################################################################
#
#  Select type form
#
######################################################################

######################################################################
# 
# $foo = $thing->_do_stage_type
#
# undocumented
#
######################################################################

sub _do_stage_type
{
	my( $self ) = @_;

	my( $page, $p );

	$page = &SESSION->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	# should this be done with "help?" cjg

	my $submit_buttons = {
		_order => [ "save","next" ],
		_class => "submission_buttons",
		save => &SESSION->phrase(
				"lib/submissionform:action_save" ),
		next => &SESSION->phrase( 
				"lib/submissionform:action_next" ) };

	$page->appendChild( &SESSION->render_input_form( 
		staff=>$self->{staff},
		fields=>[ $self->{dataset}->get_field( "type" ) ],
	        values=>$self->{eprint}->get_data(),
	        show_names=>1,
	        show_help=>1,
		default_action=>"next",
	        buttons=>$submit_buttons,
	        top_buttons=>$submit_buttons,
	        hidden_fields=>
		{ 
			stage => "type", 
			dataset => $self->{dataset}->id(),
			eprintid => $self->{eprint}->get_value( "eprintid" ) 
		},
		dest=>$self->{formtarget}."#t"
	) );

	return( $page );
}

######################################################################
#
#  Succession/Commentary form
#
######################################################################

######################################################################
# 
# $foo = $thing->_do_stage_linking
#
# undocumented
#
######################################################################

sub _do_stage_linking
{
	my( $self ) = @_;
	
	my( $page, $p );

	$page = &SESSION->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	my $archive_ds = &ARCHIVE->get_dataset( "archive" );
	my $comment = {};
	my $field_id;
	foreach $field_id ( "succeeds", "commentary" )
	{
		next unless( defined $self->{eprint}->get_value( $field_id ) );

		my $older_eprint = new EPrints::EPrint( 
		        $self->{eprint}->get_value( $field_id ),
		        $archive_ds );
	
		$comment->{$field_id} = &SESSION->make_doc_fragment();	

		if( defined $older_eprint )
		{
			my $citation = $older_eprint->render_citation();
			$comment->{$field_id}->appendChild( 
				&SESSION->html_phrase( 
					"lib/submissionform:verify",
					citation => $citation ) );
		}
		else
		{
			my $idtext = &SESSION->make_text(
					$self->{eprint}->get_value($field_id));

			$comment->{$field_id}->appendChild( 
				&SESSION->html_phrase( 
					"lib/submissionform:invalid_eprint",
					eprintid => $idtext ) );
		}
	}
			

	my $submit_buttons = {
		_order => [ "prev", "verify", "save", "next" ],
		_class => "submission_buttons",
		prev => &SESSION->phrase(
				"lib/submissionform:action_prev" ),
		verify => &SESSION->phrase(
				"lib/submissionform:action_verify" ),
		save => &SESSION->phrase(
				"lib/submissionform:action_save" ),
		next => &SESSION->phrase( 
				"lib/submissionform:action_next" ) };

	$page->appendChild( &SESSION->render_input_form( 
		staff=>$self->{staff},
		fields=>[ 
			$self->{dataset}->get_field( "succeeds" ),
			$self->{dataset}->get_field( "commentary" ) 
		],
	        values=>$self->{eprint}->get_data(),
	        show_names=>1,
	        show_help=>1,
	        buttons=>$submit_buttons,
	        top_buttons=>$submit_buttons,
		default_action=>"next",
	        hidden_fields=>
		{ 
			stage => "linking", 
			dataset => $self->{dataset}->id(),
			eprintid => $self->{eprint}->get_value( "eprintid" ) 
		},
		comments=>$comment,
		dest=>$self->{formtarget}."#t"
	) );

	return( $page );

}
	



######################################################################
#
#  Enter metadata fields form
#
######################################################################

######################################################################
# 
# $foo = $thing->_do_stage_meta
#
# undocumented
#
######################################################################

sub _do_stage_meta
{
	my( $self ) = @_;
	
	my( $page, $p );

	$page = &SESSION->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	if( !defined $self->{pageid} ) 
	{ 
		my @pages = $self->{dataset}->get_type_pages( 
					$self->{eprint}->get_value( "type" ) );
		if( $self->{action} eq "prev" )
		{
			$self->{pageid} = pop @pages;
		}
		else
		{
			$self->{pageid} = $pages[0];
		}
	}

	$page->appendChild( &SESSION->html_phrase( 
		"lib/submissionform:bib_info" ) );
	
	my @edit_fields = $self->{dataset}->get_page_fields( 
		$self->{eprint}->get_value( "type" ), 
		$self->{pageid}, 
		$self->{staff} );

	my $hidden_fields = {	
			stage => "meta", 
			dataset => $self->{dataset}->id(),
			eprintid => $self->{eprint}->get_value( "eprintid" ),
			pageid => $self->{pageid} 
		};

	my $submit_buttons = {
		_order => [ "prev", "save", "next" ],
		_class => "submission_buttons",
		prev => &SESSION->phrase(
				"lib/submissionform:action_prev" ),
		save => &SESSION->phrase(
				"lib/submissionform:action_save" ),
		next => &SESSION->phrase( 
				"lib/submissionform:action_next" ) };

	$page->appendChild( 
		&SESSION->render_input_form( 
			staff=>$self->{staff},
			dataset=>$self->{dataset},
			type=>$self->{eprint}->get_value( "type" ),
			fields=>\@edit_fields,
			values=>$self->{eprint}->get_data(),
			show_names=>1,
			show_help=>1,
			buttons=>$submit_buttons,
	        	top_buttons=>$submit_buttons,
			default_action=>"next",
			hidden_fields=>$hidden_fields,
			dest=>$self->{formtarget}."#t" ) );

	$self->{title_phrase} = "metapage_title_".$self->{pageid};

	return( $page );
}



######################################################################
#
#  Select an upload format
#
######################################################################

######################################################################
# 
# $foo = $thing->_do_stage_files
#
# undocumented
#
######################################################################

sub _do_stage_files
{
	my( $self ) = @_;

	my( $page, $p, $form, $table, $tr, $td, $th  );

	$page = &SESSION->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	# Validate again, so we know what buttons to put up and how 
	# to state stuff
	$self->{eprint}->prune_documents(); 
	my $probs = $self->{eprint}->validate_documents( $self->{for_archive} );

	$form = &SESSION->render_form( "post", $self->{formtarget}."#t" );
	$page->appendChild( $form );

	my %buttons;
	$buttons{prev} = &SESSION->phrase( "lib/submissionform:action_prev" );
	$buttons{save} = &SESSION->phrase( "lib/submissionform:action_save" ),
	$buttons{_order} = [ "prev", "save" ];
	$buttons{_class} = "submission_buttons";
	if( scalar @{$probs} == 0 )
	{
		# docs validated ok
		$buttons{next} = &SESSION->phrase( "lib/submissionform:action_next" ); 
		$buttons{_order} = [ "prev", "save", "next" ];
	}

	# buttons at top.
	$form->appendChild( &SESSION->render_action_buttons( %buttons ) );

	my @docs = $self->{eprint}->get_all_documents();

	if( scalar @docs > 0 )
	{
		$form->appendChild(
			&SESSION->html_phrase(
				"lib/submissionform:current_docs") );

		$table = &SESSION->make_element( "table", border=>1 );
		$form->appendChild( $table );
		$tr = &SESSION->make_element( "tr" );
		$table->appendChild( $tr );
		$th = &SESSION->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild( 
			&SESSION->html_phrase("lib/submissionform:format") );
		$th = &SESSION->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild( 
			&SESSION->html_phrase("lib/submissionform:files_uploaded") );
		
		my $docds = &ARCHIVE->get_dataset( "document" );
		my $doc;
		foreach $doc ( @docs )
		{
			$tr = &SESSION->make_element( "tr" );
			$table->appendChild( $tr );
			$td = &SESSION->make_element( "td" );
			$tr->appendChild( $td );
			$td->appendChild( $doc->render_description() );
			$td = &SESSION->make_element( "td", align=>"center" );
			$tr->appendChild( $td );
			my %files = $doc->files();
			my $nfiles = scalar(keys %files);
			$td->appendChild( &SESSION->make_text( $nfiles ) );
			$td = &SESSION->make_element( "td" );
			$tr->appendChild( $td );
			my $edit_id = "edit_".$doc->get_value( "docid" );
			my $remove_id = "remove_".$doc->get_value( "docid" );
			$td->appendChild( 
				&SESSION->render_action_buttons(
					_order => [ $edit_id, $remove_id ],
					$edit_id => &SESSION->phrase( 
						"lib/submissionform:action_edit" ) ,
					$remove_id => &SESSION->phrase( 
						"lib/submissionform:action_remove" ) 
			) );
		}
		$form->appendChild( &SESSION->make_element( "br" ) );
	}

	$form->appendChild( &SESSION->render_hidden_field(
		"stage",
		"files" ) );
	$form->appendChild( &SESSION->render_hidden_field(
		"eprintid",
		$self->{eprint}->get_value( "eprintid" ) ) );
	$form->appendChild( &SESSION->render_hidden_field(
		"dataset",
		$self->{eprint}->get_dataset()->id() ) );

	my @reqformats = @{&ARCHIVE->get_conf( "required_formats" )};	
	if( scalar @reqformats == 0 )
	{
		$form->appendChild(
			&SESSION->html_phrase(
				"lib/submissionform:none_required" ) );
	}
	else
	{
 		my $doc_ds = &ARCHIVE->get_dataset( "document" );
		my $list = &SESSION->make_doc_fragment();
		my $c = scalar @reqformats;
		foreach( @reqformats )
		{
			--$c;
                	$list->appendChild( $doc_ds->render_type_name( $_ ) );
			if( $c > 0 )
			{
                		$list->appendChild( 
					&SESSION->make_text( ", " ) );
			}
		}
		$form->appendChild(
			&SESSION->html_phrase(
				"lib/submissionform:least_one",
				list=>$list ) );
	}

	$form->appendChild( &SESSION->render_action_buttons(
		newdoc => &SESSION->phrase( 
				"lib/submissionform:action_newdoc" ) ) );
	$form->appendChild( &SESSION->make_element( "br" ) );
	$form->appendChild( &SESSION->render_action_buttons( %buttons ) );

	return( $page );
}

######################################################################
#
#  Document metadata
#
######################################################################

######################################################################
# 
# $foo = $thing->_do_stage_docmeta
#
# undocumented
#
######################################################################

sub _do_stage_docmeta
{
	my( $self ) = @_;

	my $page = &SESSION->make_doc_fragment();

	$page->appendChild( $self->_render_problems(
		&SESSION->html_phrase("lib/submissionform:fix_upload"),
		&SESSION->html_phrase("lib/submissionform:please_fix") ) );

	# The hidden fields, used by all forms.
	my $hidden_fields = {	
		docid => $self->{document}->get_value( "docid" ),
		dataset => $self->{eprint}->get_dataset()->id(),
		eprintid => $self->{eprint}->get_value( "eprintid" ),
		stage => "docmeta" };

	my $docds = &ARCHIVE->get_dataset( "document" );

	my $submit_buttons = 
	{	
		next => &SESSION->phrase( "lib/submissionform:action_next" ),
		cancel => &SESSION->phrase( "lib/submissionform:action_doc_cancel" ),
		_class => "submission_buttons",
		_order => [ "cancel", "next" ] 
	};

	my $fields = [];
	foreach( "format", "formatdesc", "language", "security" )
	{
		unless( &ARCHIVE->get_conf( "submission_hide_".$_ ) )
		{
			push @{$fields}, $docds->get_field( $_ );
		}
	}

	$page->appendChild( 
		&SESSION->render_input_form( 
			staff=>$self->{staff},
			fields=>$fields,
			values=>$self->{document}->get_data(),
			show_help=>1,
			buttons=>$submit_buttons,
	        	top_buttons=>$submit_buttons,
			default_action=>"next",
			hidden_fields=>$hidden_fields,
			dest=>$self->{formtarget}."#t" ) );

	return( $page );
}

######################################################################
#
#  View / Delete files
#
######################################################################

######################################################################
# 
# $foo = $thing->_do_stage_fileview
#
# undocumented
#
######################################################################

sub _do_stage_fileview
{
	my( $self ) = @_;

	my $page = &SESSION->make_doc_fragment();

	$page->appendChild( $self->_render_problems(
		&SESSION->html_phrase("lib/submissionform:fix_upload"),
		&SESSION->html_phrase("lib/submissionform:please_fix") ) );

	# The hidden fields, used by all forms.
	my $hidden_fields = {	
		docid => $self->{document}->get_value( "docid" ),
		dataset => $self->{eprint}->get_dataset()->id(),
		eprintid => $self->{eprint}->get_value( "eprintid" ),
		_default_action => "upload",
		stage => "fileview" };
	############################

	my $options = [];
	my $hideopts = {};
	foreach( "archive", "graburl", "plain" )
	{
		$hideopts->{$_} = 0;
		my $copt = &ARCHIVE->get_conf( "submission_hide_upload_".$_ );
		$hideopts->{$_} = 1 if( defined $copt && $copt );
	}
	push @{$options},"plain" unless( $hideopts->{plain} );
	#push @{$options},"graburl" unless( $hideopts->{graburl} );
	unless( $hideopts->{archive} )
	{
		push @{$options}, @{&ARCHIVE->get_conf( "archive_formats" )}
	}

	my $arc_format_field = EPrints::MetaField->new(
		confid=>'format',
		name=>'arc_format',
		required=>1,
		input_rows => 1,
		type=>'set',
		options => $options );

	my $fields = [ $arc_format_field ];

	my $submit_buttons;
	$submit_buttons = {
		upload => &SESSION->phrase( 
				"lib/submissionform:action_upload" ) };

	my $upform = &SESSION->render_form( "post", $self->{formtarget}."#t" );
	foreach( keys %{$hidden_fields} )
	{
		$upform->appendChild( &SESSION->render_hidden_field(
			$_, $hidden_fields->{$_} ) );
	}	
	my %upload_bits;
	$upload_bits{type} = $arc_format_field->render_input_field( 'plain', 'format' );
	$upload_bits{file} = &SESSION->render_upload_field( "file" );
	$upload_bits{button} = &SESSION->render_action_buttons(
                upload => &SESSION->phrase( 
                                "lib/submissionform:action_upload" ) );
	$upform->appendChild( &SESSION->html_phrase( 
		"lib/submissionform:upload_layout",
		%upload_bits ) );

	my $urlupform = &SESSION->render_form( "post", $self->{formtarget}."#t" );
	foreach( keys %{$hidden_fields} )
	{
		$urlupform->appendChild( &SESSION->render_hidden_field(
			$_, $hidden_fields->{$_} ) );
	}
	$urlupform->appendChild( &SESSION->render_hidden_field( "arc_format", "graburl" ) );
	my %url_upload_bits;
	$url_upload_bits{url} = &SESSION->make_element( "input", size=>"40", name=>"url", value=>"http://" );
	$url_upload_bits{button} = &SESSION->render_action_buttons(
                upload => &SESSION->phrase( 
                                "lib/submissionform:action_capture" ) );
	$urlupform->appendChild( &SESSION->html_phrase( 
		"lib/submissionform:url_upload_layout",
		%url_upload_bits ) );

	

	##################################
	#
	# Render info about uploaded files

	my %files = $self->{document}->files();

	my( $p, $table, $tr, $th, $td, $form );

	if( scalar keys %files == 1 )
	{
		$self->{document}->set_main( (keys %files)[0] );
		$self->{document}->commit();
	}


	# Headings for Files Table

	my $viewfiles = &SESSION->make_doc_fragment;;
	if( scalar keys %files == 0 )
	{
		$viewfiles->appendChild( &SESSION->html_phrase(
				"lib/submissionform:no_files") );
	}
	else
	{
		$p = &SESSION->make_element( "p" );
		$viewfiles->appendChild( $p );
		$p->appendChild(
			&SESSION->html_phrase(
				"lib/submissionform:files_for_format") );

		my $p = &SESSION->make_element( "p" );
		$table = &SESSION->make_element( "table" );
		$viewfiles->appendChild( $p );
		$p->appendChild( $table );

		if( !defined $self->{document}->get_main() )
		{
			$p->appendChild(
				&SESSION->html_phrase(
					"lib/submissionform:sel_first") );
		}

		my $main = $self->{document}->get_main();
		my $filename;
		my $filecount = 0;
		
		my $hiddenbits = "";
		foreach( keys %{$hidden_fields} )
		{
			$hiddenbits .= $_."=".$hidden_fields->{$_}."&";
		}

		foreach $filename (sort keys %files)
		{
			$tr = &SESSION->make_element( "tr" );
			$table->appendChild( $tr );

			$td = &SESSION->make_element( "td", valign=>"top" );
			$tr->appendChild( $td );
			# Iffy. Non 8bit filenames could cause a render bug. cjg
			my $a = &SESSION->render_link( $self->{document}->get_baseurl().$filename, "_blank" );
			$a->appendChild( &SESSION->make_text( $filename ) );
			$td->appendChild( $a );

			my $size = EPrints::Utils::human_filesize( $files{$filename} );
			$size =~ m/^([0-9]+)([^0-9]*)$/;
			my( $n, $units ) = ( $1, $2 );	
			$td = &SESSION->make_element( "td", valign=>"top", align=>"right" );
			$tr->appendChild( $td );
			$td->appendChild( &SESSION->make_text( $1 ) );
			$td = &SESSION->make_element( "td", valign=>"top", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( &SESSION->make_text( $2 ) );

			$td = &SESSION->make_element( "td", valign=>"top" );
			$tr->appendChild( $td );

			$a = &SESSION->render_link( $self->{formtarget}."?".$hiddenbits."_action_delete_".$filecount."#t" );
			
			$a->appendChild( &SESSION->html_phrase( "lib/submissionform:delete" ) );
			$td->appendChild( &SESSION->make_text( "[" ) );
			$td->appendChild( $a );
			$td->appendChild( &SESSION->make_text( "]" ) );

			if( keys %files > 1 )
			{
				$td = &SESSION->make_element( "td", valign=>"top" );
				$tr->appendChild( $td );
				if( defined $main && $main eq $filename )
				{
					$td->appendChild( &SESSION->html_phrase( "lib/submissionform:shown_first" ) );
				}
				else
				{
					$a = &SESSION->render_link( $self->{formtarget}."?".$hiddenbits."_action_main_".$filecount."#t" );
					$a->appendChild( &SESSION->html_phrase( "lib/submissionform:show_first" ) );
					$td->appendChild( &SESSION->make_text( "[" ) );
					$td->appendChild( $a );
					$td->appendChild( &SESSION->make_text( "]" ) );
				}
			}

			$filecount++;
		}

		if( keys %files > 1 )
		{
			my $p = &SESSION->make_element( "p" );
			my $a = &SESSION->render_link( $self->{formtarget}."?".$hiddenbits."_action_deleteall#t" );
			$a->appendChild( &SESSION->html_phrase( "lib/submissionform:delete_all" ) );
			$p->appendChild( &SESSION->make_text( "[" ) );
			$p->appendChild( $a );
			$p->appendChild( &SESSION->make_text( "]" ) );
			$viewfiles->appendChild( $p );
		}


	}

	$submit_buttons = {
		_class => "submission_buttons",
		_order => [ "prev", "cancel" ],
		cancel => &SESSION->phrase(
				"lib/submissionform:action_doc_cancel" ),
		prev => &SESSION->phrase(
				"lib/submissionform:action_prev" ) };

	if( scalar keys %files > 0 ) {

		$submit_buttons->{finished} = &SESSION->phrase( 
			"lib/submissionform:action_finished" );
		$submit_buttons->{_order} = [ "prev" , "cancel", "finished" ];
	}

	$page->appendChild( 
		&SESSION->render_input_form( 
			staff=>$self->{staff},
			buttons=>$submit_buttons,
			hidden_fields=>$hidden_fields,
			default_action=>"prev",
			dest=>$self->{formtarget}."#t" ) );

	$page->appendChild( 
		&SESSION->html_phrase(
			"lib/submissionform:fileview_page_layout",
			document => $self->{document}->render_description,
			eprint => $self->{eprint}->render_description,
			upload_form => $upform,
			url_form => $urlupform,
			show_files => $viewfiles ) );

	$page->appendChild( 
		&SESSION->render_input_form( 
			staff=>$self->{staff},
			buttons=>$submit_buttons,
			hidden_fields=>$hidden_fields,
			default_action=>"prev",
			dest=>$self->{formtarget}."#t" ) );

	return( $page );
}
	


######################################################################
#
#  Confirm submission
#
######################################################################

######################################################################
# 
# EPrints::SubmissionForm::_do_stage_quickverify { return $_[0]->_do_stage_verify; }( _do_stage_quickverify { return $_[0]->_do_stage_verify; } )
#
# undocumented
#
######################################################################

sub _do_stage_quickverify { return $_[0]->_do_stage_verify( 1 ); }

sub _do_stage_verify
{
	my( $self, $quick ) = @_;

	$self->{eprint}->commit();
	# Validate again, in case we came from home
	$self->{problems} = $self->{eprint}->validate_full( $self->{for_archive} );

	my( $page, $p );
	$page = &SESSION->make_doc_fragment();

	# stage could be either verify or quickverify
	my $hidden_fields = {
		stage => $self->{new_stage},
		dataset => $self->{eprint}->get_dataset()->id(),
		eprintid => $self->{eprint}->get_value( "eprintid" )
	};

	my $submit_buttons = { 
		_class => "submission_buttons",
		_order => []
	};
	unless( $quick ) 
	{
		$submit_buttons->{prev} = &SESSION->phrase(
				"lib/submissionform:action_prev" ),
		push @{$submit_buttons->{_order}}, "prev";
	}
	$submit_buttons->{later} = &SESSION->phrase(
			"lib/submissionform:action_later" ),
	push @{$submit_buttons->{_order}}, "later";

	if( scalar @{$self->{problems}} > 0 )
	{
		$page->appendChild( 
			&SESSION->render_input_form( 
				staff=>$self->{staff},
				buttons=>$submit_buttons,
				hidden_fields=>$hidden_fields,
				dest=>$self->{formtarget}."#t" ) );

		# Null doc fragment past because 'undef' would cause the
		# default to appear.
		$page->appendChild( $self->_render_problems(
			&SESSION->html_phrase("lib/submissionform:fix_probs"),
			&SESSION->make_doc_fragment() ) );
	}
	else
	{
		# If eprint is valid then the control buttons only
		# appear at the end of the page. At the top is a message
		# to tell you that.
		my $controls_at_bottom = &SESSION->make_element( 
			"div", 
			class=>"submission_buttons" );
		$controls_at_bottom->appendChild(
			&SESSION->html_phrase( "lib/submissionform:controls_at_bottom" ) );
		$page->appendChild( $controls_at_bottom );

		$page->appendChild( &SESSION->html_phrase(
			"lib/submissionform:please_verify") );

		$page->appendChild( &SESSION->render_ruler() );	
		my( $full, $title ) = $self->{eprint}->render_full();
		$page->appendChild( $full );
		$page->appendChild( &SESSION->render_ruler() );	

		$page->appendChild( &SESSION->html_phrase( "deposit_agreement_text" ) );

		$submit_buttons->{submit} = &SESSION->phrase(
			"lib/submissionform:action_submit" ),
		push @{$submit_buttons->{_order}}, "submit";

	}

	$page->appendChild( 
		&SESSION->render_input_form( 
			staff=>$self->{staff},
			buttons=>$submit_buttons,
			hidden_fields=>$hidden_fields,
			dest=>$self->{formtarget}."#t" ) );

	return( $page );
}		
		

######################################################################
#
#  All done.
#
######################################################################

######################################################################
# 
# $foo = $thing->_do_stage_done
#
# undocumented
#
######################################################################

sub _do_stage_done
{
	my( $self ) = @_;
	
	my( $page );
	$page = &SESSION->make_doc_fragment();

	$page->appendChild( &SESSION->html_phrase("lib/submissionform:thanks") );

	return( $page );
}


######################################################################
#
#  Confirm deletion
#
######################################################################

######################################################################
# 
# $foo = $thing->_do_stage_confirmdel
#
# undocumented
#
######################################################################

sub _do_stage_confirmdel
{
	my( $self ) = @_;
	
	my( $page, $p );
	$page = &SESSION->make_doc_fragment();

	$page->appendChild( &SESSION->html_phrase("lib/submissionform:sure_delete",
		title=>$self->{eprint}->render_description() ) );

	my $hidden_fields = {
		stage => "confirmdel",
		dataset => $self->{eprint}->get_dataset()->id(),
		eprintid => $self->{eprint}->get_value( "eprintid" )
	};

	my $submit_buttons = {
		cancel => &SESSION->phrase(
				"lib/submissionform:action_cancel" ),
		confirm => &SESSION->phrase(
				"lib/submissionform:action_confirm" ),
		_order => [ "confirm", "cancel" ]
	};

	$page->appendChild( 
		&SESSION->render_input_form( 
			staff=>$self->{staff},
			show_help=>1,
			buttons=>$submit_buttons,
			hidden_fields=>$hidden_fields,
			dest=>$self->{formtarget}."#t" ) );

	return( $page );
}	


######################################################################
#
#  Automatically return to author's home.
#
######################################################################

######################################################################
# 
# $foo = $thing->_do_stage_return
#
# undocumented
#
######################################################################

sub _do_stage_return
{
	my( $self ) = @_;

	&SESSION->redirect( $self->{redirect} );

	return &SESSION->make_doc_fragment;
}	



######################################################################
#
#  Miscellaneous Functions
#
######################################################################

######################################################################
# 
# $foo = $thing->_update_from_form( $field_id )
#
# undocumented
#
######################################################################

sub _update_from_form
{
	my( $self, $field_id ) = @_;
	
	my $field = $self->{dataset}->get_field( $field_id );

	my $value = $field->form_value;

	$self->{eprint}->set_value( $field_id, $value );
}

######################################################################
#
# _render_problems( $before, $after )
#
#  Lists the given problems with the form. If $before and/or $after
#  are given, they are printed before and after the list. If they're
#  undefined, default messages are printed.
#
######################################################################


######################################################################
# 
# $foo = $thing->_render_problems( $before, $after )
#
# undocumented
#
######################################################################

sub _render_problems
{
	my( $self, $before, $after ) = @_;

	my( $p, $ul, $li, $problem_box );

	my $frag = &SESSION->make_doc_fragment();

	if( !defined $self->{problems} || scalar @{$self->{problems}} == 0 )
	{
		# No problems - return an empty node.
		return $frag;
	}

	my $a = &SESSION->make_element( "a", name=>"t" );
	$frag->appendChild( $a );
	$problem_box = &SESSION->make_element( 
				"div",
				class=>"problems" );
	$frag->appendChild( $problem_box );

	# List the problem(s)

	$p = &SESSION->make_element( "p" );
	if( defined $before )
	{
		$p->appendChild( $before );
	}
	else
	{
		$p->appendChild( 	
			&SESSION->html_phrase(
				"lib/submissionform:filled_wrong" ) );
	}
	$problem_box->appendChild( $p );

	$ul = &SESSION->make_element( "ul" );	
	foreach (@{$self->{problems}})
	{
		$li = &SESSION->make_element( "li" );
		$li->appendChild( $_ );
		$ul->appendChild( $li );
	}
	$problem_box->appendChild( $ul );
	
	$p = &SESSION->make_element( "p" );
	if( defined $after )
	{
		$p->appendChild( $after );
	}
	else
	{
		$p->appendChild( 	
			&SESSION->html_phrase(
				"lib/submissionform:please_complete" ) );
	}
	$problem_box->appendChild( $p );
	
	return $frag;
}





######################################################################
# 
# $foo = $thing->_set_stage_next
#
# undocumented
#
######################################################################

sub _set_stage_next
{
	my( $self ) = @_;

	$self->{new_stage} = $self->{stages}->{$self->{stage}}->{next};

	# Skip stage?
	while( &ARCHIVE->get_conf( "submission_stage_skip", $self->{new_stage} ) )
	{
		$self->{new_stage} = $self->{stages}->{$self->{new_stage}}->{next};
	}
}

######################################################################
# 
# $foo = $thing->_set_stage_prev
#
# undocumented
#
######################################################################

sub _set_stage_prev
{
	my( $self ) = @_;

	$self->{new_stage} = $self->{stages}->{$self->{stage}}->{prev};

	# Skip stage?
	while( &ARCHIVE->get_conf( "submission_stage_skip", $self->{new_stage} ) )
	{
		$self->{new_stage} = $self->{stages}->{$self->{new_stage}}->{prev};
	}
}

######################################################################
# 
# $foo = $thing->_set_stage_this
#
# undocumented
#
######################################################################

sub _set_stage_this
{
	my( $self ) = @_;

	$self->{new_stage} = $self->{stage};
}

######################################################################
=pod

=item $foo = $thing->DESTROY

undocumented

=cut
######################################################################

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}

1;

######################################################################
=pod

=back

=cut
