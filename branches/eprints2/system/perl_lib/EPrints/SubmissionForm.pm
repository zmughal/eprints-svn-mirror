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

B<EPrints::SubmissionForm> - Form for modifying EPrints.

=head1 DESCRIPTION

This class represents an object which renders the forms for modifying
an EPrint object, and reads the values from the form back in to the
eprint.

It also handles validation and submitting the eprint to the editorial
review buffer.

This will ultimately be replaced with the new workflow system.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
# $self->{session}
#    the current EPrints::Session object.
#
# $self->{redirect}
#    The URL to go to after the form is complete.
#
# $self->{staff}
#    If true then any eprint can be edited, not just those belonging
#    to the current user. Also if true then fields marked as staffonly
#    in metadata phrases will be included.
#
# $self->{dataset}
#    The EPrints::DataSet to which the eprint being edited belongs.
#
# $self->{eprint}
#    The EPrints::DataObj::EPrint currently being edited.
#
# $self->{formtarget}
#    The URL of the form. Used as the target for <form>
#
# $self->{for_archive}
#    If true then the validation for moving to the main archive is
#    applied as oppose to the validation for moving to the editorial
#    review buffer.
#
# $self->{autosend}
#    If false then the resulting page is not sent to the browser,
#    instead it is stored in $self->{page}. Used for embedding the
#    form in a larger page.
#
# $self->{page} 
#    See autosend.
#
# $self->{stages}
#    If the default stage ordering is not being used then the new
#    ordering is stored here.
#
######################################################################

package EPrints::SubmissionForm;

use EPrints;

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

=item $s_form = EPrints::SubmissionForm->new( $session, $redirect, $staff, $dataset, $formtarget )

Create a new Submission Form Object.

$session is the current EPrints::Session.

$redirect is the URL to redirect to when the form is completed.

$staff is a boolean. If it's true then the 'staffonly' fields are
included in the form. If it's false and the eprint isn't owned by
the current user then the form returns a permission denied error page. 

$dataset is the EPrints::DataSet which the eprint being edited 
belongs to. Or will belong to, if it's not created yet.

$formtarget is the URL to submit the form to.

If $autosend is set to zero then the search form is not send out to
the browser, it is stored and may be retrieved with 
$s_form->get_page()

=cut
######################################################################

sub new
{
	my( $class, $session, $redirect, $staff, $dataset, $formtarget, $autosend ) = @_;
	
	my $self = {};
	bless $self, $class;


	$self->{session} = $session;
	$self->{redirect} = $redirect;
	$self->{staff} = $staff;
	$self->{dataset} = $dataset;
	$self->{formtarget} = $formtarget;
	$self->{for_archive} = $staff;
	$self->{autosend} = $autosend;
	unless( defined $self->{autosend} ) { $self->{autosend} = 1; }
	
	# Use user configured order for stages or...
	$self->{stages} = $session->get_repository->get_conf( 
		"submission_stages" );

	$self->{stages} = $STAGES if( !defined $self->{stages} );

	return( $self );
}



######################################################################
=pod

=item $ok = $s_form->process

Process everything from the previous form, and render the next.

Unless autosend was set to false, the next form is sent to the 
browser.

If the end of the form is reached then the browser is redirected to
the redirect URL specified in construction.

Returns true if the form was processed OK.

=cut
######################################################################

sub process
{
	my( $self ) = @_;
	
	$self->{action}    = $self->{session}->get_action_button();
	$self->{stage}     = $self->{session}->param( "stage" );
	$self->{eprintid}  = $self->{session}->param( "eprintid" );
	$self->{user}      = $self->{session}->current_user();
	$self->{dataview}  = $self->{session}->param( "dataview" );

	# If we have an EPrint ID, retrieve its entry from the database
	if( defined $self->{eprintid} )
	{
		if( $self->{staff} )
		{
			if( defined $self->{session}->param( "dataset" ) )
			{
				my $arc = $self->{session}->get_repository;
				$self->{dataset} = $arc->get_dataset( 
					$self->{session}->param( "dataset" ) );
			}
		}
		$self->{eprint} = EPrints::DataObj::EPrint->new( 
			$self->{session},
			$self->{eprintid},
			$self->{dataset} );

		# Check it was retrieved OK
		if( !defined $self->{eprint} )
		{
			my $db_error = $self->{session}->get_database->error;
			#cjg LOG..
			$self->{session}->get_repository->log( 
				"Database Error: $db_error" );
			$self->_database_err;
			return( 0 );
		}

		# check that we got the record we wanted - if we didn't
		# then something is heap big bad. ( This is being a bit
		# over paranoid, but what the hell )
		if( $self->{session}->param( "eprintid" ) ne
	    		$self->{eprint}->get_value( "eprintid" ) )
		{
			my $form_id = $self->{session}->param( "eprintid" );
			$self->{session}->get_repository->log( 
				"Form error: EPrint ID in form ".
				$self->{session}->param( "eprintid" ).
				" doesn't match object id ".
				$self->{eprint}->get_value( "eprintid" ) );
			$self->_corrupt_err;
			return( 0 );
		}

		# Check it's owned by the current user
		if( !$self->{staff} && !$self->{user}->is_owner( $self->{eprint} ) )
		{
			$self->{session}->get_repository->log( 
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


	if( $self->{action} eq "jump" )
	{
		$self->{new_stage} = $self->{stage};
		$self->{pageid} = $self->{session}->param( "pageid" );
	}
	else
	{
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
	}
	
	if( $ok )
	{
		# Render stuff for next stage

		my $stage = $self->{new_stage};

		if( $self->{session}->get_repository->get_conf( 'log_submission_timing' ) )
		{
			if( $stage ne "meta" )
			{
				$self->log_submission_stage($stage);
			}
			# meta gets logged after pageid is worked out
		}

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
				$self->{session}->get_lang->has_phrase( 
						$self->{title_phrase} ) )
			{
				$title_phraseid = $self->{title_phrase};
			}
				
			$self->{session}->build_page(
				$self->{session}->html_phrase( 
					$title_phraseid,
					type => $self->{eprint}->render_value( "type" ),
					eprintid => $self->{eprint}->render_value( "eprintid" ),
					desc => $self->{eprint}->render_description ),
				$page,
				"submission_".$stage );
			$self->{session}->send_page();
		}
		else
		{
			$self->{page} = $page;
		}
	}
	return( 1 );
}

######################################################################
=pod

=item $xhtml_form = $s_form->get_page

If we didn't send the rendered form to the browser, then this function
will return it as an XHTML DOM data structure.

=cut
######################################################################

sub get_page
{
	my( $self ) = @_;

	return $self->{page};
}

######################################################################
=pod

=item $stage = $s_form->get_stage

Return the identifier of the submission stage that we are in after
the form has been processed.

=cut
######################################################################

sub get_stage
{
	my( $self ) = @_;

	return $self->{new_stage};
}

######################################################################
=pod

=item $s_form->log_submission_stage( $stage )

Log to the submission_timings file for this repository that this stage
of the submission form was active at this time for the current user.

Only called if the log_submission_timings config option is set.

=cut
######################################################################

sub log_submission_stage
{
	my( $self, $stage ) = @_;

	my $fn = EPrints::Config::get("var_path")."/submission_timings.".$self->{session}->get_repository->get_id.".log";
	unless( open( SLOG, ">>$fn" ) )
	{
		$self->{session}->get_repository->log( "Could not append to $fn" );
	}
	my @data = ( time, $self->{eprintid}, $self->{user}->get_id, $stage, $self->{action} );
	print SLOG join( "\t", @data )."\n";
	close SLOG;
}

######################################################################
# 
# $s_form->_corrupt_err
#
######################################################################

sub _corrupt_err
{
	my( $self ) = @_;

	$self->{session}->render_error( 
		$self->{session}->html_phrase( 
			"lib/submissionform:corrupt_err",
			line_no => 
				$self->{session}->make_text( (caller())[2] ) ),
		$self->{session}->get_repository->get_conf( "userhome" ) );

}

######################################################################
# 
# $s_form->_database_err
#
######################################################################

sub _database_err
{
	my( $self ) = @_;

	$self->{session}->render_error( 
		$self->{session}->html_phrase( 
			"lib/submissionform:database_err",
			line_no => 
				$self->{session}->make_text( (caller())[2] ) ),
		$self->{session}->get_repository->get_conf( "userhome" ) );
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
# $ok = $s_form->_from_stage_home
#
#  Came from an external page (usually author or staff home,
#  or bookmarked)
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
			$self->{session}->render_error( 
				$self->{session}->html_phrase(
		        		"lib/submissionform:use_auth_area" ),
				$self->{session}->get_repository->get_conf( 
					"userhome" ) );
			return( 0 );
		}
		
		$self->{eprint} = $self->{dataset}->create_object( $self->{session}, { 
			userid => $self->{user}->get_value( "userid" ) } );

		$self->{eprintid} = $self->{eprint}->get_id;

		if( !defined $self->{eprint} )
		{
			my $db_error = $self->{session}->get_database->error;
			$self->{session}->get_repository->log( "Database Error: $db_error" );
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
			$self->{session}->render_error( 
				$self->{session}->html_phrase( 
					"lib/submissionform:nosel_err" ),
				$self->{session}->get_repository->get_conf( 
					"userhome" ) );
			return( 0 );
		}

		$self->_set_stage_next;
		return( 1 );
	}


	if( $self->{action} eq "copy" )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( 
				$self->{session}->html_phrase( 
					"lib/submissionform:nosel_err" ),
				$self->{session}->get_repository->get_conf( 
					"userhome" ) );
			return( 0 );
		}
		
		my $new_eprint = $self->{eprint}->clone( $self->{dataset}, 0, 1 );

		if( defined $new_eprint )
		{
			$self->{new_stage} = "return";
			return( 1 );
		}
		else
		{
			my $error = $self->{session}->get_database->error;
			$self->{session}->get_repository->log( "SubmissionForm error: Error copying EPrint ".$self->{eprint}->get_value( "eprintid" ).": ".$error );
			$self->_database_err;
			return( 0 );
		}
	}

	if( $self->{action} eq "clone" )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( 
				$self->{session}->html_phrase( 
					"lib/submissionform:nosel_err" ),
				$self->{session}->get_repository->get_conf( 
					"userhome" ) );
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
			my $error = $self->{session}->get_database->error;
			$self->{session}->get_repository->log( "SubmissionForm error: Error cloning EPrint ".$self->{eprint}->get_value( "eprintid" ).": ".$error );
			$self->_database_err;
			return( 0 );
		}
	}

	if( $self->{action} eq "delete" )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( 
				$self->{session}->html_phrase( 
					"lib/submissionform:nosel_err" ),
				$self->{session}->get_repository->get_conf( 
					"userhome" ) );
			return( 0 );
		}
		$self->{new_stage} = "confirmdel";
		return( 1 );
	}

	if( $self->{action} eq "submit" )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( 
				$self->{session}->html_phrase( 
					"lib/submissionform:nosel_err" ),
				$self->{session}->get_repository->get_conf( 
					"userhome" ) );
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
# $ok = $s_form->_from_stage_type
#
# Come from type form
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
# $ok = $s_form->_from_stage_linking
#
#  From sucession/commentary stage
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
# $ok = $s_form->_from_stage_meta
#
# Come from metadata entry form
#
######################################################################

sub _from_stage_meta
{
	my( $self ) = @_;

	# Process uploaded data

	my @pages = $self->{dataset}->get_type_pages(
                                        $self->{eprint}->get_value( "type" ) );

	$self->{pageid} = $self->{session}->param( "pageid" );
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

	if( $self->{session}->internal_button_pressed() )
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
# $ok = $s_form->_from_stage_files
#
#  From "select files" page
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
		my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
		$self->{document} = $doc_ds->create_object( $self->{session}, { 
			eprintid => $self->{eprint}->get_id } );
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
	$self->{document} = EPrints::DataObj::Document->new( $self->{session}, $docid );

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
# $ok = $s_form->_from_stage_docmeta
#
#  From docmeta page
#
######################################################################

sub _from_stage_docmeta
{
	my( $self ) = @_;

	# Check the document is OK, and that it is associated with the current
	# eprint
	$self->{document} = EPrints::DataObj::Document->new(
		$self->{session},
		$self->{session}->param( "docid" ) );

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
		foreach( "formatdesc", "format", "language", "security", "license" )
		{
			next if( $self->{session}->get_repository->get_conf(
				"submission_hide_".$_ ) );
			$self->{document}->set_value( $_,
				$self->{session}->param( $_ ) );
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
# $ok = $s_form->_from_stage_fileview
#
#  From fileview page
#
######################################################################

sub _from_stage_fileview
{
	my( $self ) = @_;

	# Check the document is OK, and that it is associated with the current
	# eprint
	$self->{document} = EPrints::DataObj::Document->new(
		$self->{session},
		$self->{session}->param( "docid" ) );

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
		my $arc_format = $self->{session}->param( "arc_format" );
		my $success = 0;

		if( $arc_format eq "plain" )
		{
			$success = EPrints::Apache::AnApache::upload_doc_file( 
				$self->{session},
				$self->{document},
				'file' );
		}
		elsif( $arc_format eq "graburl" )
		{
			my $url = $self->{session}->param( "url" );
			$success = $self->{document}->upload_url( $url );
		}
		else
		{
			$success = EPrints::Apache::AnApache::upload_doc_archive( 
				$self->{session},
				$self->{document},
				'file',
				$arc_format );
		}
		
		if( !$success )
		{
			$self->{problems} = [
				$self->{session}->html_phrase( "lib/submissionform:upload_prob" ) ];
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
#		$self->{arc_format} = $self->{session}->param( "arc_format" );
#		$self->{num_files} = $self->{session}->param( "num_files" );
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
# $s_form->_from_stage_verify
# $s_form->_from_stage_quickverify
#
#  Come from verify page or the quickverify page.
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

			my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" );	
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
# $ok = $s_form->_from_stage_confirmdel
#
#  Come from confirm deletion page
#
######################################################################

sub _from_stage_confirmdel
{
	my( $self ) = @_;

	if( $self->{action} eq "confirm" )
	{
		if( !$self->{eprint}->remove() )
		{
			my $db_error = $self->{session}->get_database->error;
			$self->{session}->get_repository->log( "DB error removing EPrint ".$self->{eprint}->get_value( "eprintid" ).": $db_error" );
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
# $page = $s_form->_do_stage_type
#
#  Select type form
#
######################################################################

sub _do_stage_type
{
	my( $self ) = @_;

	my( $page, $p );

	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	$page->appendChild( $self->{session}->html_phrase( 
		"lib/submissionform:bib_info",
		desc=>$self->{eprint}->render_citation ) );
	# should this be done with "help?" cjg

	my $submit_buttons = {
		_order => [ "save","next" ],
		_class => "submission_buttons",
		save => $self->{session}->phrase(
				"lib/submissionform:action_save" ),
		next => $self->{session}->phrase( 
				"lib/submissionform:action_next" ) };
	$self->_staff_buttons( $submit_buttons ) if( $self->{staff} );

	$page->appendChild( $self->{session}->render_input_form( 
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
			eprintid => $self->{eprint}->get_value( "eprintid" ) ,
			dataview => $self->{dataview},
		},
		dest=>$self->{formtarget}."#t",
		object=>$self->{eprint},
	) );

	return( $page );
}

######################################################################
# 
# $page = $s_form->_do_stage_linking
#
#  Succession/Commentary form
#
######################################################################

sub _do_stage_linking
{
	my( $self ) = @_;
	
	my( $page, $p );

	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );
	$page->appendChild( $self->{session}->html_phrase( 
		"lib/submissionform:bib_info",
		desc=>$self->{eprint}->render_citation ) );

	my $archive_ds =
		$self->{session}->get_repository->get_dataset( "archive" );
	my $comment = {};
	my $field_id;
	foreach $field_id ( "succeeds", "commentary" )
	{
		next unless( defined $self->{eprint}->get_value( $field_id ) );

		my $older_eprint = new EPrints::DataObj::EPrint( 
			$self->{session}, 
		        $self->{eprint}->get_value( $field_id ),
		        $archive_ds );
	
		$comment->{$field_id} = $self->{session}->make_doc_fragment();	

		if( defined $older_eprint )
		{
			my $citation = $older_eprint->render_citation();
			$comment->{$field_id}->appendChild( 
				$self->{session}->html_phrase( 
					"lib/submissionform:verify",
					citation => $citation ) );
		}
		else
		{
			my $idtext = $self->{session}->make_text(
					$self->{eprint}->get_value($field_id));

			$comment->{$field_id}->appendChild( 
				$self->{session}->html_phrase( 
					"lib/submissionform:invalid_eprint",
					eprintid => $idtext ) );
		}
	}
			

	my $submit_buttons = {
		_order => [ "prev", "verify", "save", "next" ],
		_class => "submission_buttons",
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ),
		verify => $self->{session}->phrase(
				"lib/submissionform:action_verify" ),
		save => $self->{session}->phrase(
				"lib/submissionform:action_save" ),
		next => $self->{session}->phrase( 
				"lib/submissionform:action_next" ) };
	$self->_staff_buttons( $submit_buttons ) if( $self->{staff} );

	$page->appendChild( $self->{session}->render_input_form( 
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
			dataview => $self->{dataview},
			eprintid => $self->{eprint}->get_value( "eprintid" ) 
		},
		comments=>$comment,
		dest=>$self->{formtarget}."#t",
		object=>$self->{eprint},
	) );

	return( $page );

}
	
######################################################################
# 
# $page = $s_form->_do_stage_meta
#
#  Enter metadata fields form
#
######################################################################

sub _do_stage_meta
{
	my( $self ) = @_;
	
	my( $page, $p );

	$page = $self->{session}->make_doc_fragment();

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

	if( $self->{session}->get_repository->get_conf( 'log_submission_timing' ) )
	{
		$self->log_submission_stage( "meta.".$self->{pageid} );
	}

	$page->appendChild( $self->{session}->html_phrase( 
		"lib/submissionform:bib_info",
		desc=>$self->{eprint}->render_citation ) );
	
	my @edit_fields = $self->{dataset}->get_page_fields( 
		$self->{eprint}->get_value( "type" ), 
		$self->{pageid}, 
		$self->{staff} );

	my $hidden_fields = {	
			stage => "meta", 
			dataset => $self->{dataset}->id(),
			dataview => $self->{dataview},
			eprintid => $self->{eprint}->get_value( "eprintid" ),
			pageid => $self->{pageid} 
		};

	my $submit_buttons = {
		_order => [ "prev", "save", "next" ],
		_class => "submission_buttons",
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ),
		save => $self->{session}->phrase(
				"lib/submissionform:action_save" ),
		next => $self->{session}->phrase( 
				"lib/submissionform:action_next" ) };
	$self->_staff_buttons( $submit_buttons ) if( $self->{staff} );

	$page->appendChild( 
		$self->{session}->render_input_form( 
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
		object=>$self->{eprint},
			dest=>$self->{formtarget}."#t" ) );

	$self->{title_phrase} = "metapage_title_".$self->{pageid};

	return( $page );
}

######################################################################
# 
# $page = $s_form->_do_stage_files
#
#  Select an upload format
#
######################################################################

sub _do_stage_files
{
	my( $self ) = @_;

	my( $page, $p, $form, $table, $tr, $td, $th  );

	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	# Validate again, so we know what buttons to put up and how 
	# to state stuff
	$self->{eprint}->prune_documents(); 
	my $probs = $self->{eprint}->validate_documents( $self->{for_archive} );

	$page->appendChild( $self->{session}->html_phrase( 
		"lib/submissionform:bib_info",
		desc=>$self->{eprint}->render_citation ) );
	$form = $self->{session}->render_form( "post", $self->{formtarget}."#t" );
	$page->appendChild( $form );

	my %buttons;
	$buttons{prev} = $self->{session}->phrase( "lib/submissionform:action_prev" );
	$buttons{save} = $self->{session}->phrase( "lib/submissionform:action_save" ),
	$buttons{_order} = [ "prev", "save" ];
	$buttons{_class} = "submission_buttons";
	if( scalar @{$probs} == 0 )
	{
		# docs validated ok
		$buttons{next} = $self->{session}->phrase( "lib/submissionform:action_next" ); 
		$buttons{_order} = [ "prev", "save", "next" ];
	}
	$self->_staff_buttons( \%buttons ) if( $self->{staff} );

	# buttons at top.
	$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );

	my @docs = $self->{eprint}->get_all_documents();

	if( scalar @docs > 0 )
	{
		$form->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:current_docs") );

		$table = $self->{session}->make_element( "table", border=>1 );
		$form->appendChild( $table );
		$tr = $self->{session}->make_element( "tr" );
		$table->appendChild( $tr );
		$th = $self->{session}->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild( 
			$self->{session}->html_phrase("lib/submissionform:format") );
		$th = $self->{session}->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild( 
			$self->{session}->html_phrase("lib/submissionform:files_uploaded") );
		
		my $docds = $self->{session}->get_repository->get_dataset( "document" );
		my $doc;
		foreach $doc ( @docs )
		{
			$tr = $self->{session}->make_element( "tr" );
			$table->appendChild( $tr );
			$td = $self->{session}->make_element( "td" );
			$tr->appendChild( $td );
			$td->appendChild( $doc->render_description() );
			$td = $self->{session}->make_element( "td", align=>"center" );
			$tr->appendChild( $td );
			my %files = $doc->files();
			my $nfiles = scalar(keys %files);
			$td->appendChild( $self->{session}->make_text( $nfiles ) );
			$td = $self->{session}->make_element( "td" );
			$tr->appendChild( $td );
			my $edit_id = "edit_".$doc->get_value( "docid" );
			my $remove_id = "remove_".$doc->get_value( "docid" );
			$td->appendChild( 
				$self->{session}->render_action_buttons(
					_order => [ $edit_id, $remove_id ],
					$edit_id => $self->{session}->phrase( 
						"lib/submissionform:action_edit" ) ,
					$remove_id => $self->{session}->phrase( 
						"lib/submissionform:action_remove" ) 
			) );
		}
		$form->appendChild( $self->{session}->make_element( "br" ) );
	}

	$form->appendChild( $self->{session}->render_hidden_field(
		"stage",
		"files" ) );
	$form->appendChild( $self->{session}->render_hidden_field(
		"dataview",
		$self->{dataview} ) );
	$form->appendChild( $self->{session}->render_hidden_field(
		"eprintid",
		$self->{eprint}->get_value( "eprintid" ) ) );
	$form->appendChild( $self->{session}->render_hidden_field(
		"dataset",
		$self->{eprint}->get_dataset()->id() ) );

	my @reqformats = $self->{eprint}->required_formats;
	if( scalar @reqformats == 0 )
	{
		$form->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:none_required" ) );
	}
	else
	{
 		my $doc_ds = $self->{session}->get_repository->get_dataset( 
			"document" );
		my $list = $self->{session}->make_doc_fragment();
		my $c = scalar @reqformats;
		foreach( @reqformats )
		{
			--$c;
                	$list->appendChild( 
				$doc_ds->render_type_name( 
					$self->{session}, $_ ) );
			if( $c > 0 )
			{
                		$list->appendChild( 
					$self->{session}->make_text( ", " ) );
			}
		}
		$form->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:least_one",
				list=>$list ) );
	}

	my $buttoncode = "lib/submissionform:action_newdoc";
	if( scalar @docs == 0 )
	{
		$buttoncode = "lib/submissionform:action_firstdoc";
	}
	$form->appendChild( $self->{session}->render_action_buttons(
		newdoc => $self->{session}->phrase( $buttoncode ) ) );
	$form->appendChild( $self->{session}->make_element( "br" ) );
	$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );

	return( $page );
}

######################################################################
# 
# $page = $s_form->_do_stage_docmeta
#
#  Document metadata
#
######################################################################

sub _do_stage_docmeta
{
	my( $self ) = @_;

	my $page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->_render_problems(
		$self->{session}->html_phrase("lib/submissionform:fix_upload"),
		$self->{session}->html_phrase("lib/submissionform:please_fix") ) );
	$page->appendChild( $self->{session}->html_phrase( 
		"lib/submissionform:bib_info",
		desc=>$self->{eprint}->render_citation ) );

	# The hidden fields, used by all forms.
	my $hidden_fields = {	
		docid => $self->{document}->get_value( "docid" ),
		dataset => $self->{eprint}->get_dataset()->id(),
		dataview => $self->{dataview},
		eprintid => $self->{eprint}->get_value( "eprintid" ),
		stage => "docmeta" };

	my $repository = $self->{session}->get_repository;

	my $docds = $repository->get_dataset( "document" );

	my $submit_buttons = 
	{	
		next => $self->{session}->phrase( "lib/submissionform:action_next" ),
		cancel => $self->{session}->phrase( "lib/submissionform:action_doc_cancel" ),
		_class => "submission_buttons",
		_order => [ "cancel", "next" ] 
	};

	my $fields = [];
	foreach( "format", "formatdesc", "language", "security", "license" )
	{
		unless( $repository->get_conf( "submission_hide_".$_ ) )
		{
			push @{$fields}, $docds->get_field( $_ );
		}
	}

	$page->appendChild( 
		$self->{session}->render_input_form( 
			staff=>$self->{staff},
			fields=>$fields,
			values=>$self->{document}->get_data(),
			show_help=>1,
			buttons=>$submit_buttons,
	        	top_buttons=>$submit_buttons,
			default_action=>"next",
			hidden_fields=>$hidden_fields,
		object=>$self->{eprint},
			dest=>$self->{formtarget}."#t" ) );

	return( $page );
}

######################################################################
# 
# $page = $s_form->_do_stage_fileview
#
#  View / Delete files
#
######################################################################

sub _do_stage_fileview
{
	my( $self ) = @_;

	my $page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->_render_problems(
		$self->{session}->html_phrase("lib/submissionform:fix_upload"),
		$self->{session}->html_phrase("lib/submissionform:please_fix") ) );
	$page->appendChild( $self->{session}->html_phrase( 
		"lib/submissionform:bib_info",
		desc=>$self->{eprint}->render_citation ) );

	# The hidden fields, used by all forms.
	my $hidden_fields = {	
		docid => $self->{document}->get_value( "docid" ),
		dataset => $self->{eprint}->get_dataset()->id(),
		eprintid => $self->{eprint}->get_value( "eprintid" ),
		dataview => $self->{dataview},
		_default_action => "upload",
		stage => "fileview" };
	############################

	my $options = [];
	my $hideopts = {};
	foreach( "archive", "graburl", "plain" )
	{
		$hideopts->{$_} = 0;
		my $copt = $self->{session}->get_repository->get_conf( 
			"submission_hide_upload_".$_ );
		$hideopts->{$_} = 1 if( defined $copt && $copt );
	}
	push @{$options},"plain" unless( $hideopts->{plain} );
	#push @{$options},"graburl" unless( $hideopts->{graburl} );
	unless( $hideopts->{archive} )
	{
		push @{$options}, @{$self->{session}->get_repository->get_conf( 
					"archive_formats" )}
	}

	my $arc_format_field = EPrints::MetaField->new(
		confid=>'format',
		repository=> $self->{session}->get_repository,
		name=>'arc_format',
		required=>1,
		input_rows => 1,
		type=>'set',
		options => $options );

	my $fields = [ $arc_format_field ];

	my $submit_buttons;
	$submit_buttons = {
		upload => $self->{session}->phrase( 
				"lib/submissionform:action_upload" ) };

	my $upform = $self->{session}->render_form( "post", $self->{formtarget}."#t" );
	foreach( keys %{$hidden_fields} )
	{
		$upform->appendChild( $self->{session}->render_hidden_field(
			$_, $hidden_fields->{$_} ) );
	}	
	my %upload_bits;
	$upload_bits{type} = $arc_format_field->render_input_field( $self->{session}, 'plain', 'format' );
	$upload_bits{file} = $self->{session}->render_upload_field( "file" );
	$upload_bits{button} = $self->{session}->render_action_buttons(
                upload => $self->{session}->phrase( 
                                "lib/submissionform:action_upload" ) );
	$upform->appendChild( $self->{session}->html_phrase( 
		"lib/submissionform:upload_layout",
		%upload_bits ) );

	my $urlupform = $self->{session}->render_form( "post", $self->{formtarget}."#t" );
	foreach( keys %{$hidden_fields} )
	{
		$urlupform->appendChild( $self->{session}->render_hidden_field(
			$_, $hidden_fields->{$_} ) );
	}
	$urlupform->appendChild( $self->{session}->render_hidden_field( "arc_format", "graburl" ) );
	my %url_upload_bits;
	$url_upload_bits{url} = $self->{session}->make_element( "input", size=>"40", name=>"url", value=>"http://" );
	$url_upload_bits{button} = $self->{session}->render_action_buttons(
                upload => $self->{session}->phrase( 
                                "lib/submissionform:action_capture" ) );
	$urlupform->appendChild( $self->{session}->html_phrase( 
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

	my $viewfiles = $self->{session}->make_doc_fragment;;
	if( scalar keys %files == 0 )
	{
		$viewfiles->appendChild( $self->{session}->html_phrase(
				"lib/submissionform:no_files") );
	}
	else
	{
		$p = $self->{session}->make_element( "p" );
		$viewfiles->appendChild( $p );
		$p->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:files_for_format") );

		my $p = $self->{session}->make_element( "p" );
		$table = $self->{session}->make_element( "table" );
		$viewfiles->appendChild( $p );
		$p->appendChild( $table );

		if( !defined $self->{document}->get_main() )
		{
			$p->appendChild(
				$self->{session}->html_phrase(
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
			$tr = $self->{session}->make_element( "tr" );
			$table->appendChild( $tr );

			$td = $self->{session}->make_element( "td", valign=>"top" );
			$tr->appendChild( $td );
			# Iffy. Non 8bit filenames could cause a render bug. cjg
			my $a = $self->{session}->render_link( $self->{document}->get_url($filename), "_blank" );
			$a->appendChild( $self->{session}->make_text( $filename ) );
			$td->appendChild( $a );

			my $size = EPrints::Utils::human_filesize( $files{$filename} );
			$size =~ m/^([0-9]+)([^0-9]*)$/;
			my( $n, $units ) = ( $1, $2 );	
			$td = $self->{session}->make_element( "td", valign=>"top", align=>"right" );
			$tr->appendChild( $td );
			$td->appendChild( $self->{session}->make_text( $1 ) );
			$td = $self->{session}->make_element( "td", valign=>"top", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( $self->{session}->make_text( $2 ) );

			$td = $self->{session}->make_element( "td", valign=>"top" );
			$tr->appendChild( $td );

			$a = $self->{session}->render_link( $self->{formtarget}."?".$hiddenbits."_action_delete_".$filecount."#t" );
			
			$a->appendChild( $self->{session}->html_phrase( "lib/submissionform:delete" ) );
			$td->appendChild( $self->{session}->make_text( "[" ) );
			$td->appendChild( $a );
			$td->appendChild( $self->{session}->make_text( "]" ) );

			if( keys %files > 1 )
			{
				$td = $self->{session}->make_element( "td", valign=>"top" );
				$tr->appendChild( $td );
				if( defined $main && $main eq $filename )
				{
					$td->appendChild( $self->{session}->html_phrase( "lib/submissionform:shown_first" ) );
				}
				else
				{
					$a = $self->{session}->render_link( $self->{formtarget}."?".$hiddenbits."_action_main_".$filecount."#t" );
					$a->appendChild( $self->{session}->html_phrase( "lib/submissionform:show_first" ) );
					$td->appendChild( $self->{session}->make_text( "[" ) );
					$td->appendChild( $a );
					$td->appendChild( $self->{session}->make_text( "]" ) );
				}
			}

			$filecount++;
		}

		if( keys %files > 1 )
		{
			my $p = $self->{session}->make_element( "p" );
			my $a = $self->{session}->render_link( $self->{formtarget}."?".$hiddenbits."_action_deleteall#t" );
			$a->appendChild( $self->{session}->html_phrase( "lib/submissionform:delete_all" ) );
			$p->appendChild( $self->{session}->make_text( "[" ) );
			$p->appendChild( $a );
			$p->appendChild( $self->{session}->make_text( "]" ) );
			$viewfiles->appendChild( $p );
		}


	}

	$submit_buttons = {
		_class => "submission_buttons",
		_order => [ "prev", "cancel" ],
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_doc_cancel" ),
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ) };

	if( scalar keys %files > 0 ) {

		$submit_buttons->{finished} = $self->{session}->phrase( 
			"lib/submissionform:action_finished" );
		$submit_buttons->{_order} = [ "prev" , "cancel", "finished" ];
	}

	$page->appendChild( 
		$self->{session}->render_input_form( 
			staff=>$self->{staff},
			buttons=>$submit_buttons,
			hidden_fields=>$hidden_fields,
			default_action=>"prev",
			dest=>$self->{formtarget}."#t" ) );

	$page->appendChild( 
		$self->{session}->html_phrase(
			"lib/submissionform:fileview_page_layout",
			document => $self->{document}->render_description,
			eprint => $self->{eprint}->render_description,
			upload_form => $upform,
			url_form => $urlupform,
			show_files => $viewfiles ) );

	$page->appendChild( 
		$self->{session}->render_input_form( 
			staff=>$self->{staff},
			buttons=>$submit_buttons,
			hidden_fields=>$hidden_fields,
			default_action=>"prev",
			dest=>$self->{formtarget}."#t" ) );

	return( $page );
}
	
######################################################################
# 
# $page = $s_form->_do_stage_quickverify
# $page = $s_form->_do_stage_verify
#
#  Confirm submission
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
	$page = $self->{session}->make_doc_fragment();

	# stage could be either verify or quickverify
	my $hidden_fields = {
		stage => $self->{new_stage},
		dataset => $self->{eprint}->get_dataset()->id(),
		dataview => $self->{dataview},
		eprintid => $self->{eprint}->get_value( "eprintid" )
	};

	my $submit_buttons = { 
		_class => "submission_buttons",
		_order => []
	};
	unless( $quick ) 
	{
		$submit_buttons->{prev} = $self->{session}->phrase(
				"lib/submissionform:action_prev" ),
		push @{$submit_buttons->{_order}}, "prev";
	}
	$submit_buttons->{later} = $self->{session}->phrase(
			"lib/submissionform:action_later" ),
	push @{$submit_buttons->{_order}}, "later";

	if( scalar @{$self->{problems}} > 0 )
	{
		$page->appendChild( 
			$self->{session}->render_input_form( 
				staff=>$self->{staff},
				buttons=>$submit_buttons,
				hidden_fields=>$hidden_fields,
				dest=>$self->{formtarget}."#t" ) );

		# Null doc fragment past because 'undef' would cause the
		# default to appear.
		$page->appendChild( $self->_render_problems(
			$self->{session}->html_phrase("lib/submissionform:fix_probs"),
			$self->{session}->make_doc_fragment() ) );
	}
	else
	{
		# If eprint is valid then the control buttons only
		# appear at the end of the page. At the top is a message
		# to tell you that.
		my $controls_at_bottom = $self->{session}->make_element( 
			"div", 
			class=>"submission_buttons" );
		$controls_at_bottom->appendChild(
			$self->{session}->html_phrase( "lib/submissionform:controls_at_bottom" ) );
		$page->appendChild( $controls_at_bottom );

		$page->appendChild( $self->{session}->html_phrase(
			"lib/submissionform:please_verify") );

		$page->appendChild( $self->{session}->render_ruler() );	
		$page->appendChild( $self->{eprint}->render_full() );
		$page->appendChild( $self->{session}->render_ruler() );	

		$page->appendChild( $self->{session}->html_phrase( "deposit_agreement_text" ) );

		$submit_buttons->{submit} = $self->{session}->phrase(
			"lib/submissionform:action_submit" ),
		push @{$submit_buttons->{_order}}, "submit";

	}

	$page->appendChild( 
		$self->{session}->render_input_form( 
			staff=>$self->{staff},
			buttons=>$submit_buttons,
			hidden_fields=>$hidden_fields,
			dataview => $self->{dataview},
			dest=>$self->{formtarget}."#t" ) );

	return( $page );
}		
		
######################################################################
# 
# $page = $s_form->_do_stage_done
#
#  All done.
#
######################################################################

sub _do_stage_done
{
	my( $self ) = @_;
	
	my( $page );
	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->{session}->html_phrase("lib/submissionform:thanks") );

	return( $page );
}

######################################################################
# 
# $ok = $s_form->_do_stage_confirmdel
#
#  Confirm deletion
#
######################################################################

sub _do_stage_confirmdel
{
	my( $self ) = @_;
	
	my( $page, $p );
	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->{session}->html_phrase("lib/submissionform:sure_delete",
		title=>$self->{eprint}->render_description() ) );

	my $hidden_fields = {
		stage => "confirmdel",
		dataset => $self->{eprint}->get_dataset()->id(),
		dataview => $self->{dataview},
		eprintid => $self->{eprint}->get_value( "eprintid" )
	};

	my $submit_buttons = {
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		confirm => $self->{session}->phrase(
				"lib/submissionform:action_confirm" ),
		_order => [ "confirm", "cancel" ]
	};

	$page->appendChild( 
		$self->{session}->render_input_form( 
			staff=>$self->{staff},
			show_help=>1,
			buttons=>$submit_buttons,
			hidden_fields=>$hidden_fields,
			dest=>$self->{formtarget}."#t" ) );

	return( $page );
}	

######################################################################
# 
# $page = $s_form->_do_stage_return
#
#  Automatically return to author's home.
#
######################################################################

sub _do_stage_return
{
	my( $self ) = @_;

	$self->{session}->redirect( $self->{redirect} );

	return $self->{session}->make_doc_fragment;
}	

######################################################################
# 
# $s_form->_update_from_form( $field_id )
#
#  Miscellaneous Functions
#
######################################################################

sub _update_from_form
{
	my( $self, $field_id ) = @_;
	
	my $field = $self->{dataset}->get_field( $field_id );

	my $value = $field->form_value( $self->{session}, $self->{eprint} );
print STDERR Dumper( $field_id, $value );
use Data::Dumper;

	$self->{eprint}->set_value( $field_id, $value );
}

######################################################################
# 
# $errors_xhtml = $s_form->_render_problems( $before, $after )
#
#  Lists the given problems with the form. If $before and/or $after
#  are given, they are printed before and after the list. If they're
#  undefined, default messages are printed.
#
######################################################################

sub _render_problems
{
	my( $self, $before, $after ) = @_;

	my( $p, $ul, $li, $problem_box );

	my $frag = $self->{session}->make_doc_fragment();

	if( !defined $self->{problems} || scalar @{$self->{problems}} == 0 )
	{
		# No problems - return an empty node.
		return $frag;
	}

	my $a = $self->{session}->make_element( "a", name=>"t" );
	$frag->appendChild( $a );
	$problem_box = $self->{session}->make_element( 
				"div",
				class=>"problems" );
	$frag->appendChild( $problem_box );

	# List the problem(s)

	$p = $self->{session}->make_element( "p" );
	if( defined $before )
	{
		$p->appendChild( $before );
	}
	else
	{
		$p->appendChild( 	
			$self->{session}->html_phrase(
				"lib/submissionform:filled_wrong" ) );
	}
	$problem_box->appendChild( $p );

	$ul = $self->{session}->make_element( "ul" );	
	foreach (@{$self->{problems}})
	{
		$li = $self->{session}->make_element( "li" );
		$li->appendChild( $_ );
		$ul->appendChild( $li );
	}
	$problem_box->appendChild( $ul );
	
	$p = $self->{session}->make_element( "p" );
	if( defined $after )
	{
		$p->appendChild( $after );
	}
	else
	{
		$p->appendChild( 	
			$self->{session}->html_phrase(
				"lib/submissionform:please_complete" ) );
	}
	$problem_box->appendChild( $p );
	
	return $frag;
}

######################################################################
# 
# $s_form->_set_stage_next
#
######################################################################

sub _set_stage_next
{
	my( $self ) = @_;

	$self->{new_stage} = $self->{stages}->{$self->{stage}}->{next};

	# Skip stage?
	while( $self->{session}->get_repository->get_conf( "submission_stage_skip", $self->{new_stage} ) )
	{
		$self->{new_stage} = $self->{stages}->{$self->{new_stage}}->{next};
	}
}

######################################################################
# 
# $s_form->_set_stage_prev
#
######################################################################

sub _set_stage_prev
{
	my( $self ) = @_;

	$self->{new_stage} = $self->{stages}->{$self->{stage}}->{prev};

	# Skip stage?
	while( $self->{session}->get_repository->get_conf( "submission_stage_skip", $self->{new_stage} ) )
	{
		$self->{new_stage} = $self->{stages}->{$self->{new_stage}}->{prev};
	}
}

######################################################################
# 
# $s_form->_set_stage_this
#
######################################################################

sub _set_stage_this
{
	my( $self ) = @_;

	$self->{new_stage} = $self->{stage};
}

######################################################################
# 
# $s_form->_staff_buttons( $buttons )
#
# this method modifies the buttons so as to be suitable for a staff
# mode search.
#
######################################################################

sub _staff_buttons
{
	my( $self, $buttons ) = @_;

	my $islast = $self->{new_stage} eq $self->last_edit_stage;

	my @o2 = ();
	foreach( @{$buttons->{_order}} )
	{
		next if( $islast && $_ eq "next" );
		push @o2, $_;
		if( $_ eq "save" ) { push @o2,"stop"; }
	}
	delete $buttons->{next} if( $islast );
	$buttons->{_order} = \@o2;
	$buttons->{stop} = 
		$self->{session}->phrase( "lib/submissionform:action_staff_stop" );
	$buttons->{save} = 
		$self->{session}->phrase( "lib/submissionform:action_staff_save" );
}

######################################################################
=pod

=item @stages = $s_form->get_stages;

Return an array of the IDs of the stages of this submission form.

=cut
######################################################################

sub get_stages
{
	my( $self ) = @_;

	my @stages = ();

	my $stage = "home";
	while( $stage ne "return" && $stage ne "done" )
	{
		$stage = $self->{stages}->{$stage}->{next};

		# Skip stage?
		while( $self->{session}->get_repository->get_conf( "submission_stage_skip", $stage ) )
		{
			$stage = $self->{stages}->{$stage}->{next};
		}
		push @stages, $stage;
	}

	return @stages;
}

######################################################################
=pod

=item $stage = $s_form->last_edit_stage;

Return the ID of the last stage which edits the eprint, ignores
return, done and verify stages.

=cut
######################################################################

sub last_edit_stage
{
	my( $self ) = @_;

	my @stages = $self->get_stages;
	my $laststage = pop @stages;
	while( $laststage eq "verify" || $laststage eq "done" || $laststage eq "return" )
	{
		$laststage = pop @stages;
	}
	return $laststage;
}


1;

######################################################################
=pod

=back

=cut
