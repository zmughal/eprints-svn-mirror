######################################################################
#
# EPrints::DataObj::EPrint
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

=head1 NAME

B<EPrints::DataObj::EPrint> - Class representing an actual EPrint

=head1 DESCRIPTION

This class represents a single eprint record and the metadata 
associated with it. This is associated with one of more 
EPrint::Document objects.

EPrints::DataObj::EPrint is a subclass of EPrints::DataObj with the following
metadata fields (plus those defined in ArchiveMetadataFieldsConfig):

=head1 SYSTEM METADATA

=over 4

=item eprintid (int)

The unique numerical ID of this eprint. 

=item rev_number (int)

The number of the current revision of this record.

=item userid (itemref)

The id of the user who deposited this eprint (if any). Scripted importing
could cause this not to be set.

=item dir (text)

The directory, relative to the documents directory for this repository, which
this eprints data is stored in. Eg. disk0/00/00/03/34 for record 334.

=item datestamp (date)

The date this record was last modified.

=item type (datatype)

The type of this record, one of the types of the "eprint" dataset.

=item succeeds (itemref)

The ID of the eprint (if any) which this succeeds.  This field should have
been an int and may be changed in a later upgrade.

=item commentary (itemref)

The ID of the eprint (if any) which this eprint is a commentary on.  This 
field should have been an int and may be changed in a later upgrade.

=item replacedby (itemref)

The ID of the eprint (if any) which has replaced this eprint. This is only set
on records in the "deletion" dataset.  This field should have
been an int and may be changed in a later upgrade.

=back

=head1 METHODS

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From EPrints::DataObj
#
######################################################################

package EPrints::DataObj::EPrint;

@ISA = ( 'EPrints::DataObj' );

use File::Path;
use strict;

######################################################################
=pod

=item $metadata = EPrints::DataObj::EPrint->get_system_field_info

Return an array describing the system metadata of the EPrint dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return ( 
	{ name=>"eprintid", type=>"int", required=>1, import=>0 },

	{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

	{ name=>"documents", type=>"subobject", datasetid=>'document',
		multiple=>1 },

	{ name=>"eprint_status", type=>"set", required=>1,
		options=>[qw/ inbox buffer archive deletion /] },

	# UserID is not required, as some bulk importers
	# may not provide this info. maybe bulk importers should
	# set a userid of -1 or something.

	{ name=>"userid", type=>"itemref", 
		datasetid=>"user", required=>0 },

	{ name=>"dir", type=>"text", required=>0, can_clone=>0,
		text_index=>0, import=>0 },

	{ name=>"datestamp", type=>"time", required=>0, import=>0,
		render_res=>"minute", can_clone=>0 },

	{ name=>"lastmod", type=>"time", required=>0, import=>0,
		render_res=>"minute", can_clone=>0 },

	{ name=>"status_changed", type=>"time", required=>0, import=>0,
		render_res=>"minute", can_clone=>0 },

	{ name=>"type", type=>"datatype", datasetid=>"eprint", required=>1, 
		input_rows=>"ALL" },

	{ name=>"succeeds", type=>"itemref", required=>0,
		datasetid=>"eprint", can_clone=>0 },

	{ name=>"commentary", type=>"itemref", required=>0,
		datasetid=>"eprint", can_clone=>0 },

	{ name=>"replacedby", type=>"itemref", required=>0,
		datasetid=>"eprint", can_clone=>0 },

	{ name=>"date_embargo", type=>"date", required=>0,
		min_resolution=>"year" },	

	{ name=>"contact_email", type=>"email", required=>0, can_clone=>0 },

	);
}


######################################################################
=pod

=item $eprint = EPrints::DataObj::EPrint->new( $session, $eprint_id )

Return the eprint with the given eprint_id, or undef if it does not exist.

=cut
######################################################################

sub new
{
	my( $class, $session, $eprint_id ) = @_;

	EPrints::abort "session not defined in EPrint->new" unless defined $session;
	#EPrints::abort "eprint_id not defined in EPrint->new" unless defined $eprint_id;

	my $dataset = $session->get_repository->get_dataset( "eprint" );

	return $session->get_database->get_single( $dataset , $eprint_id );
}


######################################################################
=pod

=item $eprint = EPrints::DataObj::EPrint->new_from_data( $session, $data, $dataset )

Construct a new EPrints::DataObj::EPrint object based on the $data hash 
reference of metadata.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $self = {};
	if( defined $data )
	{
		$self->{data} = EPrints::Utils::clone( $data );
	}
	else
	{
		$self->{data} = {};
	}
	$self->{dataset} = $dataset;
	$self->{session} = $session;

	bless( $self, $class );

	return( $self );
}
	

######################################################################
# =pod
# 
# =item $eprint = EPrints::DataObj::EPrint::create( $session, $dataset, $data )
# 
# Create a new EPrint entry in the given dataset.
# 
# If data is defined, then this is used as the base for the new record.
# Otherwise the repository specific defaults (if any) are used.
# 
# The fields "eprintid" and "dir" will be overridden even if they
# are set.
# 
# If C<$data> is not defined calls L</set_eprint_defaults>.
# 
# =cut
######################################################################

sub create
{
	my( $session, $dataset, $data ) = @_;

	return EPrints::EPrint->create_from_data( 
		$session, 
		$data, 
		$dataset );
}

######################################################################
# =pod
# 
# =item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )
# 
# Create a new object of this type in the database. 
# 
# $dataset is the dataset it will belong to. 
# 
# $data is the data structured as with new_from_data.
# 
# This will create sub objects also.
# 
# =cut
######################################################################

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $new_eprint = $class->SUPER::create_from_data( $session, $data, $dataset );

	$new_eprint->set_under_construction( 1 );

	return unless defined $new_eprint;
	if( defined $data->{documents} )
	{
		foreach my $docdata_orig ( @{$data->{documents}} )
		{
			my %docdata = %{$docdata_orig};
			$docdata{eprintid} = $new_eprint->get_id;
			my $docds = $session->get_repository->get_dataset( "document" );
			EPrints::DataObj::Document->create_from_data( $session,\%docdata,$docds );
		}
	}

	$new_eprint->set_under_construction( 0 );

	my $user = $session->current_user;
	my $userid = undef;
	$userid = $user->get_id if defined $user;

	my $history_ds = $session->get_repository->get_dataset( "history" );
	$history_ds->create_object( 
		$session,
		{
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$new_eprint->get_id,
			revision=>$new_eprint->get_value( "rev_number" ),
			action=>"CREATE",
			details=>undef,
		}
	);

	# write revision, generate static and set auto fields
	$new_eprint->commit;

	return $new_eprint;
}
        
######################################################################
=pod

=item $dataset = $eprint->get_dataset

Return the dataset to which this object belongs. This will return
one of the virtual datasets: inbox, buffer, archive or deletion.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	my $status = $self->get_value( "eprint_status" );

	EPrints::abort "eprint_status not set" unless defined $status;

	return $self->{session}->get_repository->get_dataset( $status );
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::EPrint->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	my $new_id = _create_id( $session );
	my $dir = _create_directory( $session, $new_id );

	$data->{eprintid} = $new_id;
	$data->{dir} = $dir;
	$data->{rev_number} = 1;
	$data->{lastmod} = EPrints::Utils::get_datetimestamp( time );
	$data->{status_changed} = $data->{lastmod};
	if( $data->{eprint_status} eq "archive" )
	{
		$data->{datestamp} = $data->{lastmod};
	}

	$session->get_repository->call(
		"set_eprint_defaults",
		$data,
		$session );

	return $data;
}

######################################################################
# 
# $eprintid = EPrints::DataObj::EPrint::_create_id( $session )
#
#  Create a new EPrint ID code. (Unique across all eprint datasets)
#
######################################################################

sub _create_id
{
	my( $session ) = @_;
	
	return $session->get_database->counter_next( "eprintid" );

}


######################################################################
# 
# $directory =  EPrints::DataObj::EPrint::_create_directory( $session, $eprintid )
#
#  Create a directory on the local filesystem for the new document
#  with the given ID. undef is returned if it couldn't be created
#  for some reason.
#
#  If "df" is available then check for diskspace and mail a warning 
#  to the admin if the threshold is passed.
#
######################################################################

sub _create_directory
{
	my( $session, $eprintid ) = @_;
	
	# Get available directories
	my @dirs = sort $session->get_repository->get_store_dirs;
	my $storedir;

	if( $EPrints::SystemSettings::conf->{disable_df} )
	{
		# df not available, use the LAST available directory, 
		# sorting alphabetically.

		$storedir = pop @dirs;
	}
	else
	{
		# Check amount of space free on each device. We'll use the 
		# first one we find (alphabetically) that has enough space on 
		# it.
		my $warnsize = $session->get_repository->get_conf(
						"diskspace_warn_threshold");
		my $errorsize = $session->get_repository->get_conf(
						"diskspace_error_threshold");

		my $best_free_space = 0;
		my $dir;	
		foreach $dir (sort @dirs)
		{
			my $free_space = $session->get_repository->
						get_store_dir_size( $dir );
			if( $free_space > $best_free_space )
			{
				$best_free_space = $free_space;
			}
	
			unless( defined $storedir )
			{
				if( $free_space >= $errorsize )
				{
					# Enough space on this drive.
					$storedir = $dir;
				}
			}
		}

		# Check that we do have a place for the new directory
		if( !defined $storedir )
		{
			# Argh! Running low on disk space overall.
			$session->get_repository->log(<<END);
*** URGENT ERROR
*** Out of disk space.
*** All available drives have under $errorsize kilobytes remaining.
*** No new eprints may be added until this is rectified.
END
			$session->mail_administrator(
				"lib/eprint:diskout_sub" ,
				"lib/eprint:diskout" );
			return( undef );
		}

		# Warn the administrator if we're low on space
		if( $best_free_space < $warnsize )
		{
			$session->get_repository->log(<<END);
Running low on diskspace.
All available drives have under $warnsize kilobytes remaining.
END
			$session->mail_administrator(
				"lib/eprint:disklow_sub" ,
				"lib/eprint:disklow" );
		}
	}

	# Work out the directory path. It's worked out using the ID of the 
	# EPrint.
	my $idpath = eprintid_to_path( $eprintid );

	if( !defined $idpath )
	{
		$session->get_repository->log(<<END);
Failed to turn eprintid: "$eprintid" into a path.
END
		return( undef ) ;
	}

	my $docdir = $storedir."/".$idpath;

	# Full path including doc store root
	my $full_path = $session->get_repository->get_conf("documents_path").
				"/".$docdir;
	
	if (!EPrints::Utils::mkdir( $full_path ))
	{
		$session->get_repository->log(<<END);
Failed to create directory $full_path: $@
END
                return( undef );
	}
	else
	{
		# Return the path relative to the document store root
		return( $docdir );
	}
}


######################################################################
=pod

=item $eprint = $eprint->clone( $dest_dataset, $copy_documents, $link )

Create a copy of this EPrint with a new ID in the given dataset.
Return the new eprint, or undef in the case of an error.

If $copy_documents is set and true then the documents (and files)
will be copied in addition to the metadata.

If $nolink is true then the new eprint is not connected to the
old one.

=cut
######################################################################

sub clone
{
	my( $self, $dest_dataset, $copy_documents, $nolink ) = @_;

	my $data = EPrints::Utils::clone( $self->{data} );
	foreach my $field ( $self->{dataset}->get_fields )
	{
		next if( $field->get_property( "can_clone" ) );
		delete $data->{$field->get_name};
	}

	# Create the new EPrint record
	my $new_eprint = $dest_dataset->create_object(
		$self->{session},
		$data );
	
	unless( defined $new_eprint )
	{
		return undef;
	}

	my $status = $self->get_value( "eprint_status" );
	unless( $nolink )
	{
		# We assume the new eprint will be a later version of this one,
		# so we'll fill in the succeeds field, provided this one is
		# already in the main repository.
		if( $status eq "archive" || $status eq "deletion" )
		{
			$new_eprint->set_value( "succeeds" , 
				$self->get_value( "eprintid" ) );
		}
	}

	# Attempt to copy the documents, if appropriate
	my $ok = 1;

	if( $copy_documents )
	{
		my @docs = $self->get_all_documents;

		foreach my $doc (@docs)
		{
			my $new_doc = $doc->clone( $new_eprint );
			unless( $new_doc )
			{	
				$ok = 0;
				next;
			}
			$new_doc->register_parent( $new_eprint );
		}
	}

	# Now write the new EPrint to the database
	if( $ok && $new_eprint->commit )
	{
		return( $new_eprint )
	}
	else
	{
		# Attempt to remove half-copied version
		$new_eprint->remove;
		return( undef );
	}
}


######################################################################
# 
# $success = $eprint->_transfer( $new_status )
#
#  Change the eprint status.
#
######################################################################

sub _transfer
{
	my( $self, $new_status ) = @_;

	# Keep the old table
	my $old_status = $self->get_value( "eprint_status" );

	# set the status changed time to now.
	$self->set_value( 
		"status_changed" , 
		EPrints::Utils::get_datetimestamp( time ) );
	$self->set_value( 
		"eprint_status" , 
		$new_status );

	# Write self
	$self->commit( 1 );

	# log the change
	my $user = $self->{session}->current_user;
	my $userid = undef;
	$userid = $user->get_id if defined $user;
	my $code = "MOVE_"."\U$old_status"."_TO_"."\U$new_status";
	my $history_ds = $self->{session}->get_repository->get_dataset( "history" );
	$history_ds->create_object( 
		$self->{session},
		{
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$self->get_id,
			revision=>$self->get_value( "rev_number" ),
			action=>$code,
			details=>undef
		}
	);

	# Need to clean up stuff if we move this record out of the
	# archive.
	if( $old_status eq "archive" )
	{
		$self->_move_from_archive;
	}

	# Trigger any actions which are configured for eprints status
	# changes.
	my $status_change_fn = $self->{session}->get_repository->get_conf( 'eprint_status_change' );
	if( defined $status_change_fn )
	{
		&{$status_change_fn}( $self, $old_status, $new_status );
	}
	
	return( 1 );
}

######################################################################
=pod

=item $eprint->log_mail_owner( $mail )

Log that the given mail message was send to the owner of this EPrint.

$mail is the same XHTML DOM that was sent as the email.

=cut
######################################################################

sub log_mail_owner
{
	my( $self, $mail ) = @_;

	my $user = $self->{session}->current_user;
	my $userid = undef;
	$userid = $user->get_id if defined $user;

	my $history_ds = $self->{session}->get_repository->get_dataset( "history" );
	$history_ds->create_object( 
		$self->{session},
		{
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$self->get_id,
			revision=>$self->get_value( "rev_number" ),
			action=>"MAIL_OWNER",
			details=> EPrints::Utils::tree_to_utf8( $mail , 80 ),
		}
	);
}

######################################################################
=pod

=item $success = $eprint->remove

Erase this eprint and any associated records from the database and
filesystem.

This should only be called on eprints in "inbox" or "buffer".

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

	my $doc;
	foreach $doc ( $self->get_all_documents )
	{
		$doc->remove;
	}

	my $success = $self->{session}->get_database->remove(
		$self->{dataset},
		$self->get_value( "eprintid" ) );

	# remove the webpages assocaited with this record.
	$self->remove_static;

	return $success;
}


######################################################################
=pod

=item $success = $eprint->commit( [$force] );

Commit any changes that might have been made to the database.

If the item has not be changed then this function does nothing unless
$force is true.

Calls L</set_eprint_automatic_fields> just before the C<$eprint> is committed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	$self->{session}->get_repository->call( 
		"set_eprint_automatic_fields", 
		$self );

	if( !$self->is_set( "datestamp" ) && $self->get_value( "eprint_status" ) eq "archive" )
	{
		$self->set_value( 
			"datestamp" , 
			EPrints::Utils::get_datetimestamp( time ) );
	}

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}

	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	

	$self->set_value( 
		"lastmod" , 
		EPrints::Utils::get_datetimestamp( time ) );

	my $success = $self->{session}->get_database->update(
		$self->{dataset},
		$self->{data} );

	if( !$success )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( 
			"Error committing EPrint ".
			$self->get_value( "eprintid" ).": ".$db_error );
		return $success;
	}

	unless( $self->under_construction )
	{
		$self->write_revision;
		$self->generate_static;
	}

	$self->queue_changes;
	
	my $user = $self->{session}->current_user;
	my $userid = undef;
	$userid = $user->get_id if defined $user;

	my $history_ds = $self->{session}->get_repository->get_dataset( "history" );
	$history_ds->create_object( 
		$self->{session},
		{
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$self->get_id,
			revision=>$self->get_value( "rev_number" ),
			action=>"MODIFY",
			details=>undef
		}
	);

	return( $success );
}

######################################################################
=pod

=item $eprint->write_revision

Write out a snapshot of the XML describing the current state of the
eprint.

=cut
######################################################################

sub write_revision
{
	my( $self ) = @_;

	my $dir = $self->local_path."/revisions";
	if( !-d $dir )
	{
		if(!EPrints::Utils::mkdir($dir))
		{
			$self->{session}->get_repository->log( "Error creating revision directory for EPrint ".$self->get_value( "eprintid" ).", ($dir): ".$! );
			return;
		}
	}

	my $rev_file = $dir."/".$self->get_value("rev_number").".xml";
	unless( open( REVFILE, ">$rev_file" ) )
	{
		$self->{session}->get_repository->log( "Error writing file: $!" );
		return;
	}
	print REVFILE '<?xml version="1.0" encoding="utf-8" ?>'."\n";
	print REVFILE $self->export( "XML", fh=>*REVFILE );
	close REVFILE;
}

	

######################################################################
=pod

=item $problems = $eprint->validate_type( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the results of the "type" stage of eprint
submission.

A reference to an empty array indicates no problems.

Calls L</validate_field> for the C<type> field.

=cut
######################################################################

sub validate_type
{
	my( $self, $for_archive ) = @_;
	
	return [] if $self->skip_validation;

	my @problems;

	# Make sure we have a value for the type, and that it's one of the
	# configured EPrint types
	if( !defined $self->get_value( "type" ) )
	{
		push @problems, 
			$self->{session}->html_phrase( "lib/eprint:no_type" );
	} 
	elsif( ! $self->{dataset}->is_valid_type( $self->get_value( "type" ) ) )
	{
		push @problems, $self->{session}->html_phrase( 
					"lib/eprint:invalid_type" );
	}

	my $field = $self->{dataset}->get_field( "type" );

	push @problems, $self->{session}->get_repository->call(
				"validate_field",
				$field,
				$self->get_value( $field->get_name ),
				$self->{session},
				$for_archive );

	return( \@problems );
}


######################################################################
=pod

=item $problems = $eprint->validate_linking( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the results of the "linking" stage of eprint
submission.

A reference to an empty array indicates no problems.

Calls L</validate_field> for the C<succeeds> and C<commentary> fields.

=cut
######################################################################

sub validate_linking
{
	my( $self, $for_archive ) = @_;

	return [] if $self->skip_validation;

	my @problems;
	
	my $field_id;
	foreach $field_id ( "succeeds", "commentary" )
	{
		my $field = $self->{dataset}->get_field( $field_id );
	
		push @problems, $self->{session}->get_repository->call(
					"validate_field",
					$field,
					$self->get_value( $field->get_name ),
					$self->{session},
					$for_archive );

		next unless( defined $self->get_value( $field_id ) );

		my $test_eprint = new EPrints::DataObj::EPrint( 
			$self->{session}, 
			$self->get_value( $field_id ) );

		if( !defined( $test_eprint ) )
		{
			push @problems, $self->{session}->html_phrase(
				"lib/eprint:invalid_id",	
				field => $field->render_name( 
						$self->{session} ) );
			next;
		}
		# can link to non-live items. Is that a problem?

		unless( $field_id eq "succeeds" )
		{
			next;
		}

		# so it is "succeeds"...
		# Ensure that the user is authorised to post to this
		# either the same user owns both eprints, or the 
		# current user is an editor.

		my $user = $self->{session}->current_user;
		unless( 
			( defined $user && $user->has_priv( "editor" ) ) ||
			( $test_eprint->get_value("userid" ) eq 
				$self->get_value("userid") ) )
		{
 			# Not the same user. 
			push @problems, $self->{session}->html_phrase( 
				"lib/eprint:cant_succ" );
		}
	}

	
	return( \@problems );
}


######################################################################
=pod

=item $problems = $eprint->validate_meta( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the results of the "meta" stage of eprint
submission.

A reference to an empty array indicates no problems.

Calls L</validate_eprint_meta> for the C<$eprint> and L</validate_field> for all required fields.

=cut
######################################################################

sub validate_meta
{
	my( $self, $for_archive ) = @_;
	
	return [] if $self->skip_validation;

	my @all_problems;
	my @req_fields = $self->{dataset}->get_required_type_fields( 
		$self->get_value("type") );
	my @all_fields = $self->{dataset}->get_fields;

	# For all required fields...
	foreach my $field (@req_fields)
	{
		# Check that the field is filled 
		next if ( $self->is_set( $field->get_name ) );

		my $problem = $self->{session}->html_phrase( 
			"lib/eprint:not_done_field" ,
			fieldname=> $field->render_name( $self->{session} ) );

		push @all_problems,$problem;
	}

	# Give the site validation module a go
	foreach my $field (@all_fields)
	{
		push @all_problems, $self->{session}->get_repository->call(
			"validate_field",
			$field,
			$self->get_value( $field->{name} ),
			$self->{session},
			$for_archive );
	}

	# Site validation routine for eprint metadata as a whole:
	push @all_problems, $self->{session}->get_repository->call(
		"validate_eprint_meta",
		$self, 
		$self->{session},
		$for_archive );

	return( \@all_problems );
}
	
######################################################################
=pod

=item $problems = $eprint->validate_meta_page( $page, [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the results of the "meta" stage of eprint
submission. This just validates a single page rather than all metadata
fields.

A reference to an empty array indicates no problems.

Calls L</validate_eprint_meta> for the C<$eprint> and L</validate_field> for all page fields.

=cut
######################################################################

sub validate_meta_page
{
	my( $self, $page, $for_archive ) = @_;
	
	return [] if $self->skip_validation;

	my @problems;

	my @check_fields = $self->{dataset}->get_page_fields( 
		$self->get_value( "type" ),
		$page );

	# For all fields we need to check
	foreach my $field ( @check_fields )
	{
		if( $self->{dataset}->field_required_in_type(
			$field,
			$self->get_value("type") ) 
			&&
			(!  $self->is_set( $field->get_name ) ) )
		{
			# field	is required but not set!

			my $problem = $self->{session}->html_phrase( 
				"lib/eprint:not_done_field" ,
				fieldname=> $field->render_name( 
						$self->{session} ) );
			push @problems,$problem;
		}

		push @problems, $self->{session}->get_repository->call(
			"validate_field",
			$field,
			$self->get_value( $field->{name} ),
			$self->{session},
			$for_archive );
	}

	# then call the validate page function for this page
	push @problems, $self->{session}->get_repository->call(
		"validate_eprint_meta_page",
		$self,
		$self->{session},
		$page,
		$for_archive );

	return( \@problems );
}




######################################################################
=pod

=item $problems = $eprint->validate_documents( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the results of the "documents" stage of eprint
submission. That is to say, validate all the documents.

A reference to an empty array indicates no problems.

=cut
######################################################################

sub validate_documents
{
	my( $self, $for_archive ) = @_;
	
	return [] if $self->skip_validation;

	my @problems;
	
        my @req_formats = $self->required_formats;
	my @docs = $self->get_all_documents;

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
		my $doc_ds = $self->{session}->get_repository->get_dataset( 
			"document" );
		my $prob = $self->{session}->make_doc_fragment;
		$prob->appendChild( $self->{session}->html_phrase( 
			"lib/eprint:need_a_format" ) );
		my $ul = $self->{session}->make_element( "ul" );
		$prob->appendChild( $ul );
		
		foreach( @req_formats )
		{
			my $li = $self->{session}->make_element( "li" );
			$ul->appendChild( $li );
			$li->appendChild( $doc_ds->render_type_name( 
				$self->{session}, $_ ) );
		}
			
		push @problems, $prob;

	}

	foreach $doc (@docs)
	{
		my $probs = $doc->validate( $for_archive );
		foreach (@$probs)
		{
			my $prob = $self->{session}->make_doc_fragment;
			$prob->appendChild( $doc->render_description );
			$prob->appendChild( 
				$self->{session}->make_text( ": " ) );
			$prob->appendChild( $_ );
			push @problems, $prob;
		}
	}

	return( \@problems );
}


######################################################################
=pod

=item $problems = $eprint->validate_full( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the entire eprint.

A reference to an empty array indicates no problems.

Calls L</validate_eprint> for the C<$eprint>.

=cut
######################################################################

sub validate_full
{
	my( $self , $for_archive ) = @_;

	return [] if $self->skip_validation;
	
	my @problems;

	# Firstly, all the previous checks, just to be certain... it's possible
	# that some problems remain, but the user is submitting direct from
	# the author home.	
	my $probs = $self->validate_type( $for_archive );
	push @problems, @$probs;

	$probs = $self->validate_linking( $for_archive );
	push @problems, @$probs;

	$probs = $self->validate_meta( $for_archive );
	push @problems, @$probs;

	$probs = $self->validate_documents( $for_archive );
	push @problems, @$probs;

	# Now give the site specific stuff one last chance to have a gander.
	push @problems, $self->{session}->get_repository->call( 
			"validate_eprint", 
			$self,
			$self->{session},
			$for_archive );

	return( \@problems );
}


######################################################################
=pod

=item $boolean = $eprint->skip_validation

Returns true if this eprint should pass validation without being
properly validated. This is to allow the use of dodgey data imported
from legacy systems.

=cut
######################################################################

sub skip_validation 
{
	my( $self ) = @_;

	my $skip_func = $self->{session}->get_repository->get_conf( "skip_validation" );

	return( 0 ) if( !defined $skip_func );

	return &{$skip_func}( $self );
}


######################################################################
=pod

=item $eprint->prune_documents

Remove any documents associated with this eprint which don't actually
have any files.

=cut
######################################################################

sub prune_documents
{
	my( $self ) = @_;

	# Check each one
	foreach my $doc ( $self->get_all_documents )
	{
		my %files = $doc->files;
		if( scalar keys %files == 0 )
		{
			# Has no associated files, prune
			$doc->remove;
		}
	}
}


######################################################################
=pod

=item @documents = $eprint->get_all_documents

Return an array of all EPrint::Document objects associated with this
eprint.

=cut
######################################################################

sub get_all_documents
{
	my( $self ) = @_;

	my $doc_ds = $self->{session}->get_repository->get_dataset( "document" );

	my $searchexp = EPrints::Search->new(
		session=>$self->{session},
		dataset=>$doc_ds );

	$searchexp->add_field(
		$doc_ds->get_field( "eprintid" ),
		$self->get_value( "eprintid" ) );

	my $searchid = $searchexp->perform_search;
	my @documents = $searchexp->get_records;
	$searchexp->dispose;
	foreach my $doc ( @documents )
	{
		$doc->register_parent( $self );
	}

	return( @documents );
}



######################################################################
=pod

=item @formats =  $eprint->required_formats

Return a list of the required formats for this 
eprint. Only one of the required formats is required, not all.

An empty list means no format is required.

=cut
######################################################################

sub required_formats
{
	my( $self ) = @_;

	my $fmts = $self->{session}->get_repository->get_conf( 
				"required_formats" );
	if( ref( $fmts ) ne "ARRAY" )
	{
		# function pointer then...
		$fmts = &{$fmts}($self->{session},$self);
	}

	return @{$fmts};
}

######################################################################
=pod

=item $success = $eprint->move_to_deletion

Transfer the EPrint into the "deletion" dataset. Should only be
called in eprints in the "archive" dataset.

=cut
######################################################################

sub move_to_deletion
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset( "eprint" );
	
	my $last_in_thread = $self->last_in_thread( $ds->get_field( "succeeds" ) );
	my $replacement_id = $last_in_thread->get_value( "eprintid" );

	if( $replacement_id == $self->get_value( "eprintid" ) )
	{
		# This IS the last in the thread, so we should redirect
		# enquirers to the one this replaced, if any.
		$replacement_id = $self->get_value( "succeeds" );
	}

	$self->set_value( "replacedby" , $replacement_id );

	my $success = $self->_transfer( "deletion" );

	if( $success )
	{
		$self->generate_static_all_related;
	}
	
	return $success;
}


######################################################################
=pod

=item $success = $eprint->move_to_inbox

Transfer the EPrint into the "inbox" dataset. Should only be
called in eprints in the "buffer" dataset.

=cut
######################################################################

sub move_to_inbox
{
	my( $self ) = @_;

	my $success = $self->_transfer( "inbox" );

	return $success;
}


######################################################################
=pod

=item $success = $eprint->move_to_buffer

Transfer the EPrint into the "buffer" dataset. Should only be
called in eprints in the "inbox" or "archive" dataset.

=cut
######################################################################

sub move_to_buffer
{
	my( $self ) = @_;
	
	my $success = $self->_transfer( "buffer" );
	
	if( $success )
	{
		# supported but deprecated. use eprint_status_change instead.
		if( $self->{session}->get_repository->can_call( "update_submitted_eprint" ) )
		{
			$self->{session}->get_repository->call( 
				"update_submitted_eprint", $self );
			$self->commit;
		}
	}
	
	return( $success );
}


######################################################################
# 
# $eprint->_move_from_archive
#
# Called when an item leaves the main archive. Removes the static 
# pages.
#
######################################################################

sub _move_from_archive
{
	my( $self ) = @_;

	$self->generate_static_all_related;
}


######################################################################
=pod

=item $success = $eprint->move_to_archive

Move this eprint into the main "archive" dataset. Normally only called
on eprints in "deletion" or "buffer" datasets.

=cut
######################################################################

sub move_to_archive
{
	my( $self ) = @_;

	my $success = $self->_transfer( "archive" );
	
	if( $success )
	{
		# supported but deprecated. use eprint_status_change instead.
		if( $self->{session}->get_repository->can_call( "update_archived_eprint" ) )
		{
			$self->{session}->get_repository->try_call( 
				"update_archived_eprint", $self );
			$self->commit;
		}

		$self->generate_static_all_related;
	}
	
	return( $success );
}


######################################################################
=pod

=item $path = $eprint->local_path

Return the full path of the EPrint directory on the local filesystem.
No trailing slash.

=cut
######################################################################

sub local_path
{
	my( $self ) = @_;

	unless( $self->is_set( "dir" ) )
	{
		$self->{session}->get_repository->log( "EPrint ".$self->get_id." has no directory set." );
		return undef;
	}
	
	return( 
		$self->{session}->get_repository->get_conf( 
			"documents_path" )."/".$self->get_value( "dir" ) );
}


######################################################################
=pod

=item $url = $eprint->url_stem

Return the URL to this EPrint's directory. Note, this INCLUDES the
trailing slash, unlike the local_path method.

=cut
######################################################################

sub url_stem
{
	my( $self ) = @_;

	my $repository = $self->{session}->get_repository;

	my $shorturl = $repository->get_conf( "use_short_urls" );
	$shorturl = 0 unless( defined $shorturl );

	my $url;
	$url = $repository->get_conf( "base_url" );
	$url .= '/archive' unless( $shorturl );
	$url .= '/';
	if( $shorturl )
	{
		$url .= $self->get_value( "eprintid" )+0;
	}
	else
	{
		$url .= sprintf( "%08d", $self->get_value( "eprintid" ) );
	}
	$url .= '/';

	return $url;
}


######################################################################
=pod

=item $eprint->generate_static

Generate the static version of the abstract web page. In a multi-language
repository this will generate one version per language.

If called on inbox or buffer, remove the abstract page.

Always create the symlinks for documents in the secure area.

=cut
######################################################################

sub generate_static
{
	my( $self ) = @_;

	my $status = $self->get_value( "eprint_status" );

	$self->remove_static;

	# We is going to temporarily change the language of our session to
	# render the abstracts in each language.
	my $real_langid = $self->{session}->get_langid;

	my @langs = @{$self->{session}->get_repository->get_conf( "languages" )};
	foreach my $langid ( @langs )
	{
		$self->{session}->change_lang( $langid );
		my $full_path = $self->_htmlpath( $langid );

		my @created = eval
		{
			my @created = mkpath( $full_path, 0, 0775 );
			return( @created );
		};

		# only deleted and live records have a web page.
		next if( $status ne "archive" && $status ne "deletion" );

		my( $page, $title, $links ) = $self->render;

		$self->{session}->build_page( $title, $page, "abstract", $links, "default" );
		$self->{session}->page_to_file( $full_path . "/index.html" );

		next if( $status ne "archive" );
		# Only live archive records have actual documents 
		# available.

		my @docs = $self->get_all_documents;
		my $doc;
		foreach $doc ( @docs )
		{
			unless( $doc->is_set( "security" ) )
			{
				$doc->create_symlink( $self, $full_path );
			}
		}
	}
	$self->{session}->change_lang( $real_langid );
	my @docs = $self->get_all_documents;
	foreach my $doc ( @docs )
	{
		my $linkdir = EPrints::DataObj::Document::_secure_symlink_path( $self );
		$doc->create_symlink( $self, $linkdir );
	}
}

######################################################################
=pod

=item $eprint->generate_static_all_related

Generate the static pages for this eprint plus any it's related to,
by succession or commentary.

=cut
######################################################################

sub generate_static_all_related
{
	my( $self ) = @_;

	$self->generate_static;

	# Generate static pages for everything in threads, if 
	# appropriate
	my @to_update = $self->get_all_related;
	
	# Do the actual updates
	foreach my $related (@to_update)
	{
		$related->generate_static;
	}
}

######################################################################
=pod

=item $eprint->remove_static

Remove the static web page or pages.

=cut
######################################################################

sub remove_static
{
	my( $self ) = @_;

	my $langid;
	foreach $langid 
		( @{$self->{session}->get_repository->get_conf( "languages" )} )
	{
		rmtree( $self->_htmlpath( $langid ) );
	}
}

######################################################################
# 
# $path = $eprint->_htmlpath( $langid )
#
# return the filesystem path in which the static files for this eprint
# are stored.
#
######################################################################

sub _htmlpath
{
	my( $self, $langid ) = @_;

	return $self->{session}->get_repository->get_conf( "htdocs_path" ).
		"/".$langid."/archive/".
		eprintid_to_path( $self->get_value( "eprintid" ) );
}


######################################################################
=pod

=item ( $description, $title, $links ) = $eprint->render

Render the eprint. The 3 returned values are references to XHTML DOM
objects. $description is the public viewable description of this eprint
that appears as the body of the abstract page. $title is the title of
the abstract page for this eprint. $links is any elements which should
go in the <head> of this page.

Calls L</eprint_render> to actually render the C<$eprint>, if it isn't deleted.

=cut
######################################################################

sub render
{
        my( $self ) = @_;

        my( $dom, $title, $links );

	my $status = $self->get_value( "eprint_status" );
	if( $status eq "deletion" )
	{
		$title = $self->{session}->html_phrase( 
			"lib/eprint:eprint_gone_title" );
		$dom = $self->{session}->make_doc_fragment;
		$dom->appendChild( $self->{session}->html_phrase( 
			"lib/eprint:eprint_gone" ) );
		my $replacement = new EPrints::DataObj::EPrint(
			$self->{session},
			$self->get_value( "replacedby" ) );
		if( defined $replacement )
		{
			my $cite = $replacement->render_citation_link;
			$dom->appendChild( 
				$self->{session}->html_phrase( 
					"lib/eprint:later_version", 
					citation => $cite ) );
		}
	}
	else
	{
		( $dom, $title, $links ) = 
			$self->{session}->get_repository->call( 
				"eprint_render", 
				$self, $self->{session} );
	}

	if( !defined $links )
	{
		$links = $self->{session}->make_doc_fragment;
	}
	
        return( $dom, $title, $links );
}


######################################################################
=pod

=item ( $html ) = $eprint->render_history

Render the history of this eprint as XHTML DOM.

=cut
######################################################################

sub render_history
{
	my( $self ) = @_;

	my $page = $self->{session}->make_doc_fragment;

	my $ds = $self->{session}->get_repository->get_dataset( "history" );
	my $searchexp = EPrints::Search->new(
		session=>$self->{session},
		dataset=>$ds,
		custom_order=>"-timestamp/-historyid" );
	
	$searchexp->add_field(
		$ds->get_field( "objectid" ),
		$self->get_id );
	$searchexp->add_field(
		$ds->get_field( "datasetid" ),
		'eprint' );
	
	my $results = $searchexp->perform_search;
	
	$results->map( sub {
		my( $session, $dataset, $item ) = @_;
	
		$page->appendChild( $item->render );
	} );

	return $page;
}

######################################################################
=pod

=item $url = $eprint->get_url( [$staff] )

Return the public URL of this eprints abstract page. If $staff is
true then return the URL of the staff view of this eprint.

=cut
######################################################################

sub get_url
{
	my( $self , $staff ) = @_;

	if( defined $staff && $staff )
	{
		return $self->{session}->get_repository->get_conf( "perl_url" ).
			"/users/staff/edit_eprint?eprintid=".
			$self->get_value( "eprintid" )
	}
	
	return( $self->url_stem );
}


######################################################################
=pod

=item $user = $eprint->get_user

Return the EPrints::User to whom this eprint belongs (if any).

=cut
######################################################################

sub get_user
{
	my( $self ) = @_;

	my $user = EPrints::User->new( 
		$self->{session}, 
		$self->get_value( "userid" ) );

	return $user;
}


######################################################################
=pod

=item $path = EPrints::DataObj::EPrint::eprintid_to_path( $eprintid )

Return this eprints id converted into directories. Thousands of 
files in one directory cause problems. For example, the eprint with the 
id 50344 would have the path 00/05/03/44.

=cut
######################################################################

sub eprintid_to_path
{
	my( $eprintid ) = @_;

	return unless( $eprintid =~ m/^\d+$/ );

	my( $a, $b, $c, $d );
	$d = $eprintid % 100;
	$eprintid = int( $eprintid / 100 );
	$c = $eprintid % 100;
	$eprintid = int( $eprintid / 100 );
	$b = $eprintid % 100;
	$eprintid = int( $eprintid / 100 );
	$a = $eprintid % 100;
	
	return sprintf( "%02d/%02d/%02d/%02d", $a, $b, $c, $d );
}


######################################################################
=pod

=item @eprints = $eprint->get_all_related

Return the eprints that are related in some way to this in a succession
or commentary thread. The returned list does NOT include this EPrint.

=cut
######################################################################

sub get_all_related
{
	my( $self ) = @_;

	my $succeeds_field = $self->{dataset}->get_field( "succeeds" );
	my $commentary_field = $self->{dataset}->get_field( "commentary" );

	my @related = ();

	if( $self->in_thread( $succeeds_field ) )
	{
		push @related, $self->all_in_thread( $succeeds_field );
	}
	
	if( $self->in_thread( $commentary_field ) )
	{
		push @related, $self->all_in_thread( $commentary_field );
	}
	
	# Remove duplicates, just in case
	my %related_uniq;
	my $eprint;	
	my $ownid = $self->get_value( "eprintid" );
	foreach $eprint (@related)
	{
		# We don't want to re-update ourself
		next if( $ownid eq $eprint->get_value( "eprintid" ) );
		
		$related_uniq{$eprint->get_value("eprintid")} = $eprint;
	}

	return( values %related_uniq );
}


######################################################################
=pod

=item $boolean = $eprint->in_thread( $field )

Return true if this eprint is part of a thread of $field. $field
should be an EPrint::MetaField representing either "commentary" or
"succeeds".

=cut
######################################################################

sub in_thread
{
	my( $self, $field ) = @_;
	
	if( defined $self->get_value( $field->get_name ) )
	{
		return( 1 );
	}

	my @later = $self->later_in_thread( $field );

	return( 1 ) if( scalar @later > 0 );
	
	return( 0 );
}


######################################################################
=pod

=item $eprint = $eprint->first_in_thread( $field )

Return the first (earliest) version or first paper in the thread
of commentaries of this paper in the repository.

=cut
######################################################################

sub first_in_thread
{
	my( $self, $field ) = @_;
	
	my $first = $self;
	my $below = {};	
	while( defined $first->get_value( $field->get_name ) )
	{
		if( $below->{$first->get_id} )
		{
			$self->loop_error( $field, keys %{$below} );
			last;
		}
		$below->{$first->get_id} = 1;
		my $prev = EPrints::DataObj::EPrint->new( 
				$self->{session},
				$first->get_value( $field->get_name ) );

		return( $first ) unless( defined $prev );
		$first = $prev;
	}
		       
	return( $first );
}


######################################################################
=pod

=item @eprints = $eprint->later_in_thread( $field )

Return a list of the immediately later items in the thread. 

=cut
######################################################################

sub later_in_thread
{
	my( $self, $field ) = @_;

	my $searchexp = EPrints::Search->new(
		session => $self->{session},
		dataset => $self->{session}->get_repository->get_dataset( 
			"archive" ) );
#cjg		[ "datestamp DESC" ] ) ); sort by date!

	$searchexp->add_field( 
		$field, 
		$self->get_value( "eprintid" ) );

	my $searchid = $searchexp->perform_search;
	my @eprints = $searchexp->get_records;
	$searchexp->dispose;

	return @eprints;
}


######################################################################
=pod

=item @eprints = $eprint->all_in_thread( $field )

Return all of the EPrints in the given thread.

=cut
######################################################################

sub all_in_thread
{
	my( $self, $field ) = @_;

	my $above = {};
	my $set = {};
	
	my $first = $self->first_in_thread( $field );
	
	$self->_collect_thread( $field, $first, $set, $above );

	return( values %{$set} );
}

######################################################################
# 
# $eprint->_collect_thread( $field, $current, $eprints, $set, $above )
#
# $above is a hash which contains all the ids eprints above the current
# one as keys.
# $set contains all the eprints found.
#
######################################################################

sub _collect_thread
{
	my( $self, $field, $current, $set, $above ) = @_;

	if( defined $above->{$current->get_id} )
	{
		$self->loop_error( $field, keys %{$above} );
		return;
	}
	$set->{$current->get_id} = $current;	
	my %above2 = %{$above};
	$above2{$current->get_id} = $current; # copy the hash contents
	$set->{$current->get_id} = $current;	
	
	my @later = $current->later_in_thread( $field );
	foreach my $later_eprint (@later)
	{
		$self->_collect_thread( $field, $later_eprint, $set, \%above2 );
	}
}


######################################################################
=pod

=item $eprint = $eprint->last_in_thread( $field )

Return the last item in the specified thread.

=cut
######################################################################

sub last_in_thread
{
	my( $self, $field ) = @_;
	
	my $latest;
	my @later = ( $self );
	my $above = {};
	while( scalar @later > 0 )
	{
		$latest = $later[0];
		if( defined $above->{$latest->get_id} )
		{
			$self->loop_error( $field, keys %{$above} );
			last;
		}
		$above->{$latest->get_id} = 1;
		@later = $latest->later_in_thread( $field );
	}

	return( $latest );
}


######################################################################
=pod

=item $eprint->remove_from_threads

Extract the eprint from any threads it's in. i.e., if any other
paper is a later version of or commentary on this paper, the link
from that paper to this will be removed.

Abstract pages are updated if needed.

=cut
######################################################################

sub remove_from_threads
{
	my( $self ) = @_;

	return unless( $self->get_value( "eprint_status" ) eq "archive" );

	# Remove thread info in this eprint
	$self->set_value( "succeeds", undef );
	$self->set_value( "commentary", undef );
	$self->commit;

	my @related = $self->get_all_related;
	my $eprint;
	# Remove all references to this eprint
	my $this_id = $self->get_value( "eprintid" );

	foreach $eprint ( @related )
	{
		# Update the objects if they refer to us (the objects were 
		# retrieved before we unlinked ourself)
		my $changed = 0;
		if( $eprint->get_value( "succeeds" ) eq $this_id )
		{
			$self->set_value( "succeeds", undef );
			$changed = 1;
		}
		if( $eprint->get_value( "commentary" ) eq $this_id )
		{
			$self->set_value( "commentary", undef );
			$changed = 1;
		}
		if( $changed )
		{
			$eprint->commit;
		}
	}

	# Update static pages for each eprint
	foreach $eprint (@related)
	{
		next if( $eprint->get_value( "eprintid" ) eq $this_id );
		$eprint->generate_static; 
	}
}


######################################################################
=pod

=item $xhtml = $eprint->render_version_thread( $field )

Render XHTML DOM describing the entire thread as nested unordered lists.

=cut
######################################################################

sub render_version_thread
{
	my( $self, $field ) = @_;

	my $html;

	my $first_version = $self->first_in_thread( $field );

	my $ul = $self->{session}->make_element( "ul" );
	
	$ul->appendChild( $first_version->_render_version_thread_aux( $field, $self, {} ) );
	
	return( $ul );
}

######################################################################
# 
# $xhtml = $eprint->_render_version_thread_aux( $field, $eprint_shown, $above )
#
# $above is a hash ref, the keys of which are ID's of eprints already 
# seen above this item. One item CAN appear twice, just not as it's
#  own decentant.
#
######################################################################

sub _render_version_thread_aux
{
	my( $self, $field, $eprint_shown, $above ) = @_;

	my $li = $self->{session}->make_element( "li" );

	if( defined $above->{$self->get_id} )
	{
		$self->loop_error( $field, keys %{$above} );
		$li->appendChild( $self->{session}->make_text( "ERROR, THREAD LOOPS: ".join( ", ",keys %{$above} ) ));
		return $li;
	}
	
	my $cstyle = "thread_".$field->get_name;

	if( $self->get_value( "eprintid" ) != $eprint_shown->get_value( "eprintid" ) )
	{
		$li->appendChild( $self->render_citation_link( $cstyle ) );
	}
	else
	{
		$li->appendChild( $self->render_citation( $cstyle ) );
		$li->appendChild( $self->{session}->make_text( " " ) );
		$li->appendChild( $self->{session}->html_phrase( "lib/eprint:curr_disp" ) );
	}

	my @later = $self->later_in_thread( $field );

	# Are there any later versions in the thread?
	if( scalar @later > 0 )
	{
		my %above2 = %{$above};
		$above2{$self->get_id} = 1;
		# if there are, start a new list
		my $ul = $self->{session}->make_element( "ul" );
		foreach my $version (@later)
		{
			$ul->appendChild( $version->_render_version_thread_aux(
				$field, $eprint_shown, \%above2 ) );
		}
		$li->appendChild( $ul );
	}
	
	return( $li );
}

######################################################################
=pod

=item $eprint->loop_error( $field, @looped_ids )

This eprint is part of a threading loop which is not allowed. Log a
warning.

=cut
######################################################################

sub loop_error
{
	my( $self, $field, @looped_ids ) = @_;

	$self->{session}->get_repository->log( 
"EPrint ".$self->get_id." is part of a thread loop.\n".
"This means that either the commentary or succeeds form a complete\n".
"circle. Break the circle to disable this warning.\n".
"Looped field is '".$field->get_name."'\n".
"Loop is: ".join( ", ",@looped_ids ) );
}

######################################################################
=pod

=item $type = $eprint->get_type

Return the type of this eprint.

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return $self->get_value( "type" );
}



######################################################################
=pod

=item $xhtml_ul_list = $eprint->render_export_links( [$staff] )

Return a <ul> list containing links to all the formats this eprint
is available in. 

If $staff is true then show all formats available to staff, and link
to the staff export URL.

=cut
######################################################################
	
sub render_export_links
{
	my( $self, $staff ) = @_;

	my $vis = "all";
	$vis = "staff" if $staff;
	my $id = $self->get_value( "eprintid" );
	my $ul = $self->{session}->make_element( "ul" );
	my @plugins = $self->{session}->plugin_list( 
					type=>"Export",
					can_accept=>"dataobj/eprint", 
					is_visible=>$vis );
	foreach my $plugin_id ( @plugins ) {
		my $li = $self->{session}->make_element( "li" );
		my $plugin = $self->{session}->plugin( $plugin_id );
		my $url = $plugin->dataobj_export_url( $self, $staff );
		my $a = $self->{session}->render_link( $url );
		$a->appendChild( $plugin->render_name );
		$li->appendChild( $a );
		$ul->appendChild( $li );
	}
	return $ul;
}


######################################################################
=pod

=item @roles = $eprint->user_roles( $user )

Return the @roles $user has on $eprint.

=cut
######################################################################

sub user_roles
{
	my( $self, $user ) = @_;
	my $session = $self->{session};
	my @roles;

	return () unless defined( $user );
	
	# $user owns this eprint if their userid matches ours
	if( $self->get_value( "userid" ) eq $user->get_value( "userid" ) )
	{
		push @roles, qw( eprint.owner );
	}
	
	return @roles;
}

######################################################################
=pod

=item $eprint->datestamp

DEPRECATED.

=cut
######################################################################

sub datestamp
{
	my( $self ) = @_;

	my( $package,$filename,$line,$subroutine ) = caller(2);
	$self->{session}->get_repository->log( 
"The \$eprint->datestamp method is deprecated. It was called from $filename line $line." );
}

######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success

__END__

=head1 CALLBACKS

Callbacks may optionally be defined in the ArchiveConfig.

=over 4

=item validate_field

	validate_field( $field, $value, $session, [$for_archive] )

=item validate_eprint

	validate_eprint( $eprint, $session, [$for_archive] )
	
=item validate_eprint_meta

	validate_eprint_meta( $eprint, $session, [$for_archive] )

=item set_eprint_defaults

	set_eprint_defaults( $data, $session )

=item set_eprint_automatic_fields

	set_eprint_automatic_fields( $eprint )

=item eprint_render

	eprint_render( $eprint, $session )

See L<ArchiveRenderConfig/eprint_render>.

=back
