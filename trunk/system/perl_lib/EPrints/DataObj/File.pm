######################################################################
#
# EPrints::DataObj::File
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

B<EPrints::DataObj::File> - a stored file

=head1 DESCRIPTION

This class contains the technical metadata associated with a file. A file is a sequence of bytes stored in the storage layer (a "stored object"). Utility methods for storing and retrieving the stored object from the storage layer are made available.

Revision numbers on File work slightly differently to other objects. A File is only revised when it's stored object is changed and not when changes to it's metadata are made.

This class is a subclass of L<EPrints::DataObj::SubObject>.

=head1 CORE FIELDS

=over 4

=item fileid

Unique identifier for this file.

=item rev_number (int)

The number of the current revision of this file.

=item datasetid

Id of the dataset of the parent object.

=item objectid

Id of the parent object.

=item bucket

Name of the bucket the file is in.

=item filename

Name of the file (may contain directory separators).

=item mime_type

MIME type of the file (e.g. "image/png").

=item hash

Check sum of the file.

=item hash_type

Name of check sum algorithm used (e.g. "MD5").

=item filesize

Size of the file in bytes.

=item mtime

Last modification time of the file.

=item url

Virtual field for storing the file's URL.

=item data

Virtual field for storing the file's content.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::File;

@ISA = ( 'EPrints::DataObj::SubObject' );

use EPrints;
use Digest::MD5;
use MIME::Base64 ();

BEGIN
{
	eval "use Digest::SHA";
	eval "use Digest::SHA::PurePerl" if $@;
}

use strict;

######################################################################

=head2 Constructor Methods

=cut

######################################################################

=item $dataobj = EPrints::DataObj::File->new_from_filename( $session, $dataobj, $bucket, $filename )

Convenience method to get an existing File object for $filename stored in the $bucket in $dataobj.

Returns undef if no such record exists.

=cut

sub new_from_filename
{
	my( $class, $session, $dataobj, $bucket, $filename ) = @_;
	
	my $ds = $session->get_repository->get_dataset( $class->get_dataset_id );

	my $searchexp = new EPrints::Search(
		session=>$session,
		dataset=>$ds );

	$searchexp->add_field(
		$ds->get_field( "datasetid" ),
		$dataobj->get_dataset->confid );
	$searchexp->add_field(
		$ds->get_field( "objectid" ),
		$dataobj->get_id );
	$searchexp->add_field(
		$ds->get_field( "bucket" ),
		$bucket );
	$searchexp->add_field(
		$ds->get_field( "filename" ),
		$filename );

	my $searchid = $searchexp->perform_search;
	my @records = $searchexp->get_records(0,1);
	$searchexp->dispose();
	
	return $records[0];
}

=item $dataobj = EPrints::DataObj::File->create_from_data( $session, $data [, $dataset ] )

Create a new File record using $data. If "_filehandle" is defined in $data it will be read from and stored.

=cut

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $fh = delete $data->{_filehandle};

	my $self = $class->SUPER::create_from_data( $session, $data, $dataset );

	return unless defined $self;

	my $length;

	if( defined( $fh ) )
	{
		$length = $session->get_storage->store( $self, $fh );
	}
	elsif( EPrints::Utils::is_set( $data->{data} ) )
	{
		my $tmpfile = File::Temp->new;

		syswrite($tmpfile, MIME::Base64::decode( $data->{data} ));
		seek( $tmpfile, 0, 0 );
		$length = $session->get_storage->store( $self, $tmpfile );
	}
	elsif( EPrints::Utils::is_set( $data->{url} ) )
	{
		my $tmpfile = File::Temp->new;

		my $r = EPrints::Utils::wget( $session, $data->{url}, $tmpfile );
		if( $r->is_success )
		{
			seek( $tmpfile, 0, 0 );
			$length = $session->get_storage->store( $self, $tmpfile );
		}
		else
		{
			# warn, cleanup and return
			$session->get_repository->log( "Failed to retrieve $data->{url}: " . $r->code . " " . $r->message );
			$self->remove();
			return;
		}
	}

	# make sure the filesize is the actual number of stored bytes
	$self->set_value( "filesize", $length );

	return $self;
}

######################################################################

=head2 Class Methods

=cut

######################################################################

=item $thing = EPrints::DataObj::File->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"fileid", type=>"int", required=>1, import=>0, show_in_html=>0, can_clone=>0 },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0, show_in_html=>0 },

		{ name=>"datasetid", type=>"text", text_index=>0, }, 

		{ name=>"objectid", type=>"int", }, 

		{ name=>"bucket", type=>"text", },

		{ name=>"filename", type=>"text", },

		{ name=>"mime_type", type=>"text", },

		{ name=>"hash", type=>"longtext", },

		{ name=>"hash_type", type=>"text", },

		{ name=>"filesize", type=>"int", },

		{ name=>"mtime", type=>"time", },

		{ name=>"url", type=>"url", virtual=>1 },

		{ name=>"data", type=>"base64", virtual=>1 },

	);
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::File->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "file";
}

######################################################################

=item $defaults = EPrints::DataObj::File->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;
	
	$data->{fileid} = $session->get_database->counter_next( "fileid" );

	$data->{mtime} = EPrints::Time::get_iso_timestamp();

	$data->{rev_number} = 1;

	if( defined( $data->{filename} ) )
	{
		my $type = $session->get_repository->call( "guess_doc_type", $session, $data->{filename} );
		if( $type ne "other" )
		{
			$data->{mime_type} = $type;
		}
	}

	return $data;
}

######################################################################

=head2 Object Methods

=over 4

=cut

######################################################################

sub revised
{
	my( $self ) = @_;

	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );
}

sub get_mtime
{
	my( $self ) = @_;

	return $self->get_value( "mtime" );
}

=item $success = $stored->remove

Remove the stored file. Deletes all revisions of the contained object.

=cut

sub remove
{
	my( $self ) = @_;

	$self->SUPER::remove();

	foreach my $revision (1..$self->get_value( "rev_number" ))
	{
		$self->get_session->get_storage->delete( $self, $revision );
	}
}

=item $filename = $file->get_local_copy( [ $revision ] )

Return the name of a local copy of the file (may be a L<File::Temp> object).

Will retrieve and cache the remote object if necessary.

=cut

sub get_local_copy
{
	my( $self, $revision ) = @_;

	return $self->get_session->get_storage->get_local_copy( $self, $revision );
}

=item $fh = $stored->get_fh( [ $revision ] )

Retrieve a file handle to the stored file (this is a wrapper around L<EPrints::Storage>::retrieve).

=cut

sub get_fh
{
	my( $self, $revision ) = @_;

	return $self->get_session->get_storage->retrieve( $self, $revision );
}

=item $success = $file->add_file( $filepath, $filename [, $preserve_path ] )

Read and store the contents of $filepath at $filename.

If $preserve_path is untrue will strip any leading path in $filename.

=cut

sub add_file
{
	my( $self, $filepath, $filename, $preserve_path ) = @_;

	open(my $fh, "<", $filepath) or return 0;
	binmode($fh);

	my $rc = $self->upload( $fh, $filename, -s $filepath, $preserve_path );

	close($fh);

	return $rc;
}

=item $bytes = $file->upload( $filehandle, $filename, $filesize [, $preserve_path ] )

Read and store the data from $filehandle at $filename at the next revision number.

If $preserve_path is untrue will strip any leading path in $filename.

Returns the number of bytes read from $filehandle.

=cut

sub upload
{
	my( $self, $fh, $filename, $filesize, $preserve_path ) = @_;

	unless( $preserve_path )
	{
		$filename =~ s/^.*\///; # Unix
		$filename =~ s/^.*\\//; # Windows
	}

	$self->set_value( "filename", $filename );
	$self->set_value( "filesize", $filesize );
	$self->revised();

	$self->commit();

	$filesize = $self->get_session->get_storage->store( $self, $fh );

	# make sure the filesize is the actual number of stored bytes
	$self->set_value( "filesize", $filesize );
	$self->commit();

	return $filesize;
}

=item $success = $stored->write_copy( $filename [, $revision] )

Write a copy of this file to $filename.

Returns true if the written file contains the same number of bytes as the stored file.

=cut

sub write_copy
{
	my( $self, $filename, $revision ) = @_;

	open(my $out, ">", $filename) or return 0;

	my $rc = $self->write_copy_fh( $out, $revision );

	close($out);

	return $rc;
}

=item $success = $stored->write_copy_fh( $filehandle [, $revision ] )

Write a copy of this file to $filehandle.

=cut

sub write_copy_fh
{
	my( $self, $out, $revision ) = @_;

	use bytes;

	my $in = $self->get_fh( $revision ) or return 0;

	binmode($in);
	binmode($out);

	my $buffer;
	while(sysread($in,$buffer,4096))
	{
		print $out $buffer;
	}

	close($in);
	close($out);

	return 1;
}

=item $md5 = $stored->generate_md5

Calculates and returns the MD5 for this file.

=cut

sub generate_md5
{
	my( $self ) = @_;

	my $md5 = Digest::MD5->new;

	$md5->addfile( $self->get_fh );

	return $md5->hexdigest;
}

sub update_md5
{
	my( $self ) = @_;

	my $md5 = $self->generate_md5;

	$self->set_value( "hash", $md5 );
	$self->set_value( "hash_type", "MD5" );

	$self->commit();
}

=item $digest = $file->generate_sha( [ ALGORITHM ] )

Generate a SHA for this file, see L<Digest::SHA::PurePerl> for a list of supported algorithms. Defaults to "256" (SHA-256).

Returns the hex-encoded digest.

=cut

sub generate_sha
{
	my( $self, $alg ) = @_;

	$alg ||= "256";

	# PurePerl is quite slow
	my $class = defined(&Digest::SHA::new) ?
		"Digest::SHA" :
		"Digest::SHA::PurePerl";

	my $sha = $class->new( $alg );

	$sha->addfile( $self->get_fh );

	return $sha->hexdigest;
}

sub update_sha
{
	my( $self, $alg ) = @_;

	$alg ||= "256";

	my $digest = $self->generate_sha( $alg );

	$self->set_value( "hash", $digest );
	$self->set_value( "hash_type", "SHA-$alg" );

	$self->commit();
}

sub to_xml
{
	my( $self, %opts ) = @_;

	# This is a bit of a hack to inject the publicly accessible URL of data
	# files in documents into XML exports.
	# In future importers should probably use the "id" URI to retrieve
	# file objects?
	if( $self->get_value( "datasetid" ) eq "document" &&
		$self->get_value( "bucket" ) eq "data" )
	{
		my $doc = $self->get_parent();
		my $url = $doc->get_url( $self->get_value( "filename" ) );
		$self->set_value( "url", $url );

	}

	if( $opts{embed} )
	{
		if( defined(my $fh = $self->get_fh) )
		{
			use bytes;
			binmode($fh);
			my $data = "";
			while(sysread($fh,$data,4096,length($data))) { }
			close($fh);
			$self->set_value( "data", MIME::Base64::encode( $data ) );
		}
	}

	my $file = $self->SUPER::to_xml( %opts );

	return $file;
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

