######################################################################
#
# EPrints::Document
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

B<EPrints::Document> - A single format of a record.

=head1 DESCRIPTION

Document represents a single format of an EPrint (eg. PDF) - the 
actual file(s) rather than the metadata.

This class is a subclass of DataObj, with the following metadata fields: 

=over 4

=item docid (text)

The unique ID of the document. This is a string of the format 123-02
where the first number is the eprint id and the second is the document
number within that eprint.

This should probably have been and "int" but isn't. I later version
of EPrints may change this.

=item eprintid (itemref)

The id number of the eprint to which this document belongs.

=item format (datatype)

The format of this document. One of the types of the dataset "document".

=item formatdesc (text)

An additional description of this document. For example the specific version
of a format.

=item language (datatype)

The ISO ID of the language of this document. The default configuration of
EPrints does not set this.

=item security (datatype)

The security type of this document - who can view it. One of the types
of the dataset "security".

=item main (text)

The file which we should link to. For something like a PDF file this is
the only file. For an HTML document with images it would be the name of
the actual HTML file.

=back

Document has all the methods of dataobj with the addition of the following.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::Document;
@ISA = ( 'EPrints::DataObj' );
use EPrints::DataObj;


use File::Basename;
use File::Path;
use File::Copy;
use Cwd;
use Fcntl qw(:DEFAULT :seek);

use URI::Heuristic;
use Convert::PlainText;

use EPrints::Database;
use EPrints::EPrint;
use EPrints::Probity;



use strict;

# Field to use for unsupported formats (if archive allows their deposit)
$EPrints::Document::OTHER = "OTHER";

######################################################################
=pod

=item $metadata = EPrints::Document->get_system_field_info

Return an array describing the system metadata of the Document dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"docid", type=>"text", required=>1 },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

		{ name=>"eprintid", type=>"itemref",
			datasetid=>"eprint", required=>1 },

		{ name=>"format", type=>"datatype", required=>1, 
			datasetid=>"document" },

		{ name=>"formatdesc", type=>"text" },

		{ name=>"language", type=>"datatype", required=>1, 
			datasetid=>"language" },

		{ name=>"security", type=>"datatype", required=>1, 
			datasetid=>"security" },

		{ name=>"license", type=>"license", required=>0, 
			datasetid=>"license" },

		{ name=>"main", type=>"text", required=>1 }

	);

}


######################################################################
=pod

=item $thing = EPrints::Document->new( $session, $docid )

Return the document with the given $docid, or undef if it does not
exist.

=cut
######################################################################

sub new
{
	my( $class, $session, $docid ) = @_;

	return $session->get_db()->get_single( 
		$session->get_archive()->get_dataset( "document" ),
		$docid );
}


######################################################################
=pod

=item $doc = EPrints::Document->new_from_data( $session, $data )

Construct a new EPrints::Document based on the ref to a hash of metadata.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data ) = @_;

	my $self = {};
	bless $self, $class;
	$self->{data} = $data;
	$self->{dataset} = $session->get_archive()->get_dataset( "document" ),
	$self->{session} = $session;

	return( $self );
}



######################################################################
=pod

=item $doc = EPrints::Document::create( $session, $eprint )

Create and return a new Document belonging to the given $eprint object, 
get the initial metadata from set_document_defaults in the configuration
for this archive.

Note that this creates the document in the database, not just in memory.

=cut
######################################################################

sub create
{
	my( $session, $eprint ) = @_;
	
	# Generate new doc id
	my $doc_id = _generate_doc_id( $session, $eprint );
	# Make directory on filesystem
	return undef unless _create_directory( $doc_id, $eprint ); 

	my $data = {};
	$session->get_archive()->call( 
			"set_document_defaults", 
			$data,
 			$session,
 			$eprint );
	$data->{docid} = $doc_id;
	$data->{eprintid} = $eprint->get_value( "eprintid" );

	# Make database entry
	my $dataset = $session->get_archive()->get_dataset( "document" );

	my $success = $session->get_db()->add_record(
		$dataset,
		$data );  

	if( $success )
	{
		my $doc = EPrints::Document->new( $session, $doc_id );
		# Make secure area symlink
		my $linkdir = _secure_symlink_path( $eprint );
		$doc->create_symlink( $eprint, $linkdir );
		$doc->queue_all;
		return $doc;
	}
	else
	{
		return( undef );
	}
}


######################################################################
# 
# $success = EPrints::Document::_create_directory( $id, $eprint )
#
#  Make Document $id a directory. $eprint is the EPrint this document
#  is associated with.
#
######################################################################

sub _create_directory
{
	my( $id, $eprint ) = @_;
	
	my $dir = $eprint->local_path()."/".docid_to_path( $eprint->get_session()->get_archive(), $id );

	if( -d $dir )
	{
		$eprint->get_session()->get_archive()->log( "Dir $dir already exists!" );
		return 1;
	}

	# Return undef if dir creation failed. Should always have created 1 dir.
	if(!EPrints::Utils::mkdir($dir))
	{
		$eprint->get_session()->get_archive()->log( "Error creating directory for EPrint ".$eprint->get_value( "eprintid" ).", docid=".$id." ($dir): ".$! );
		return 0;
	}
	else
	{
		return 1;
	}
}


######################################################################
=pod

=item $success = $doc->create_symlink( $eprint, $linkdir )

Symbolically link the directory containing this document into the
directory $linkdir. If $linkdir does not exist then create it.

=cut
######################################################################

sub create_symlink
{
	my( $self, $eprint, $linkdir ) = @_;

	my $id = $self->get_value( "docid" );

	my $archive = $eprint->get_session()->get_archive();

	my $dir = $eprint->local_path()."/".docid_to_path( $archive, $id );

	unless( -d $linkdir )
	{
		my @created = mkpath( $linkdir, 0, 0775 );

		if( scalar @created == 0 )
		{
			$archive->log( "Error creating symlink target dir for EPrint ".$eprint->get_value( "eprintid" ).", docid=".$id." ($linkdir): ".$! );
			return( 0 );
		}
	}

	my $symlink = $linkdir."/".docid_to_path( $archive, $id );
	if( -e $symlink )
	{
		unlink( $symlink );
	}
	unless( symlink( $dir, $symlink ) )
	{
		$archive->log( "Error creating symlink for EPrint ".$eprint->get_value( "eprintid" ).", docid=".$id." symlink($dir to $symlink): ".$! );
		return( 0 );
	}	

	return( 1 );
}


######################################################################
=pod

=item $success = $doc->remove_symlink( $eprint, $linkdir )

Remove a symlink in $linkdir created by $doc->create_symlink

=cut
######################################################################

sub remove_symlink
{
	my( $self, $eprint, $linkdir ) = @_;

	my $id = $self->get_value( "docid" );

	my $archive = $eprint->get_session()->get_archive();

	my $symlink = $linkdir."/".docid_to_path( $archive, $id );

	unless( unlink( $symlink ) )
	{
		$archive->log( "Failed to unlink secure symlink for ".$eprint->get_value( "eprintid" ).", docid=".$id." ($symlink): ".$! );
		return( 0 );
	}
	return( 1 );	
}

#cjg: should this belong to eprint?
######################################################################
# 
# EPrints::Document::_secure_symlink_path( $eprint )
#
# undocumented
#
######################################################################

sub _secure_symlink_path
{
	my( $eprint ) = @_;

	my $archive = $eprint->get_session()->get_archive();
		
	return( $archive->get_conf( "htdocs_secure_path" )."/".EPrints::EPrint::eprintid_to_path( $eprint->get_value( "eprintid" ) ) );
}


######################################################################
=pod

=item $path = EPrints::Document::docid_to_path( $archive, $docid )

Return the name of the directory (in the eprint directory) in which
to place this document.

=cut
######################################################################

sub docid_to_path
{
	my( $archive, $docid ) = @_;

	$docid =~ m/-(\d+)$/;
	my $id = $1;
	if( !defined $1 )
	{
		$archive->log( "Doc ID did not take expected format: \"".$docid."\"" );
		# Setting id to "badid" is messy, but recoverable. And should
		# be noticed easily enough.
		$id = "badid";
	}
	return $id;
}


######################################################################
# 
# $docid = EPrints::Document::_generate_doc_id( $session, $eprint )
#
#  Generate an ID for a new document associated with $eprint
#
######################################################################

sub _generate_doc_id
{
	my( $session, $eprint ) = @_;

	my $dataset = $session->get_archive()->get_dataset( "document" );

	my $searchexp = EPrints::SearchExpression->new(
				session=>$session,
				dataset=>$dataset );
	$searchexp->add_field(
		$dataset->get_field( "eprintid" ),
		$eprint->get_value( "eprintid" ) );
	$searchexp->perform_search();
	my( @docs ) = $searchexp->get_records();
	$searchexp->dispose();

	my $n = 0;
	foreach( @docs )
	{
		my $id = $_->get_value( "docid" );
		$id=~m/-(\d+)$/;
		if( $1 > $n ) { $n = $1; }
	}
	$n = $n + 1;

	return sprintf( "%s-%02d", $eprint->get_value( "eprintid" ), $n );
}



######################################################################
=pod

=item $newdoc = $doc->clone( $eprint )

Attempt to clone this document. Both the document metadata and the
actual files. The clone will be associated with the given EPrint.

=cut
######################################################################

sub clone
{
	my( $self, $eprint ) = @_;
	
	# First create a new doc object
	my $new_doc = EPrints::Document::create( $self->{session}, $eprint );

	return( 0 ) if( !defined $new_doc );
	
	# Copy fields across
	foreach( "format", "formatdesc", "language", "security", "main" )
	{
		$new_doc->set_value( $_, $self->get_value( $_ ) );
	}
	
	# Copy files
	my $rc = system( "/bin/cp -pR ".$self->local_path()."/* ".$new_doc->local_path() ) & 0xffff;

	# If something's gone wrong...
	if ( $rc!=0 )
	{
		$self->{session}->get_archive()->log( "Error copying from ".$self->local_path()." to ".$new_doc->local_path().": $!" );
		return( undef );
	}

	if( $new_doc->commit() )
	{
		$new_doc->files_modified;
		return( $new_doc );
	}
	else
	{
		$new_doc->remove();
		return( undef );
	}
}


######################################################################
=pod

=item $success = $doc->remove

Attempt to completely delete this document

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

	# If removing the symlink fails then it's not the end of the 
	# world. We will delete all the files it points to. 

	my $eprint = $self->get_eprint();

	$self->remove_symlink( 
		$self->get_eprint(),
		_secure_symlink_path( $eprint ) );

	# Remove database entry
	my $success = $self->{session}->get_db()->remove(
		$self->{session}->get_archive()->get_dataset( "document" ),
		$self->get_value( "docid" ) );
	

	if( !$success )
	{
		my $db_error = $self->{session}->get_db()->error();
		$self->{session}->get_archive()->log( "Error removing document ".$self->get_value( "docid" )." from database: $db_error" );
		return( 0 );
	}

	# Remove directory and contents
	my $full_path = $self->local_path();
	my $num_deleted = rmtree( $full_path, 0, 0 );

	if( $num_deleted <= 0 )
	{
		$self->{session}->get_archive()->log( "Error removing document files for ".$self->get_value("docid").", path ".$full_path.": $!" );
		$success = 0;
	}

	return( $success );
}


######################################################################
=pod

=item $eprint = $doc->get_eprint

Return the EPrint this document is associated with.

=cut
######################################################################

sub get_eprint
{
	my( $self ) = @_;
	
	# If we have it already just pass it on
	return( $self->{eprint} ) if( defined $self->{eprint} );

	# Otherwise, create object and return
	$self->{eprint} = new EPrints::EPrint( 
		$self->{session},
		$self->get_value( "eprintid" ) );
	
	return( $self->{eprint} );
}


######################################################################
=pod

=item $url = $doc->get_baseurl( [$staff] )

Return the base URL of the document. Overrides the stub in DataObj.
$staff is currently ignored.

=cut
######################################################################

sub get_baseurl
{
	my( $self ) = @_;

	# The $staff param is ignored.

	my $eprint = $self->get_eprint();

	return( undef ) if( !defined $eprint );

	my $archive = $self->{session}->get_archive();

	# Unless this is a public doc in "archive" then the url should
	# point into the secure area. 

	my $shorturl = $archive->get_conf( "use_short_urls" );
	$shorturl = 0 unless( defined $shorturl );

	my $docpath = docid_to_path( $archive, $self->get_value( "docid" ) );

	if( !$self->is_set( "security" ) && $eprint->get_dataset()->id() eq "archive" )
	{
		return $eprint->url_stem.$docpath.'/';
	}

	my $url = $archive->get_conf( "secure_url" ).'/';
	$url .= sprintf( "%08d", $eprint->get_value( "eprintid" ) );
	$url .= '/'.$docpath.'/';

	return $url;
}

######################################################################
=pod

=item $url = $doc->get_url( [$file] )

Return the full URL of the document. Overrides the stub in DataObj.

If file is not specified then the "main" file is used.

=cut
######################################################################

sub get_url
{
	my( $self, $file ) = @_;

	$file = $self->get_main unless( defined $file );

	# just in case we don't *have* a main part yet.
	return $self->get_baseurl unless( defined $file );

	# unreserved characters according to RFC 2396
	$file =~ s/([^-_\.!~\*'\(\)A-Za-z0-9])/sprintf('%%%02X',ord($1))/ge;
	
	return $self->get_baseurl.$file;
}


######################################################################
=pod

=item $path = $doc->local_path

Return the full path of the directory where this document is stored
in the filesystem.

=cut
######################################################################

sub local_path
{
	my( $self ) = @_;

	my $eprint = $self->get_eprint();

	if( !defined $eprint )
	{
		$self->{session}->get_archive->log(
			"Document ".$self->get_id." has no eprint (eprintid is ".$self->get_value( "eprintid" )."!" );
		return( undef );
	}	
	
	return( $eprint->local_path()."/".docid_to_path( $self->{session}->get_archive(), $self->get_value( "docid" ) ) );
}


######################################################################
=pod

=item %files = $doc->files

Return a hash, the keys of which are all the files belonging to this
document (relative to $doc->local_path). The values are the sizes of
the files, in bytes.

=cut
######################################################################

sub files
{
	my( $self ) = @_;
	
	my %files;

	my $root = $self->local_path();
	if( defined $root )
	{
		_get_files( \%files, $root, "" );
	}

	return( %files );
}


# cjg should this function be in some kind of utils module and
# used by generate_static too?
######################################################################
# 
# %files = EPrints::Document::_get_files( $files, $root, $dir )
#
#  Recursively get all the files in $dir. Paths are returned relative
#  to $root (i.e. $root is removed from the start of files.)
#
######################################################################

sub _get_files
{
	my( $files, $root, $dir ) = @_;

	my $fixed_dir = ( $dir eq "" ? "" : $dir . "/" );

	# Read directory contents
	opendir CDIR, $root . "/" . $dir or return( undef );
	my @filesread = readdir CDIR;
	closedir CDIR;

	# Iterate through files
	my $name;
	foreach $name (@filesread)
	{
		if( $name ne "." && $name ne ".." )
		{
			# If it's a directory, recurse
			if( -d $root . "/" . $fixed_dir . $name )
			{
				_get_files( $files, $root, $fixed_dir . $name );
			}
			else
			{
				#my @stats = stat( $root . "/" . $fixed_dir . $name );
				$files->{$fixed_dir.$name} = -s $root . "/" . $fixed_dir . $name;
				#push @files, $fixed_dir . $name;
			}
		}
	}

}
######################################################################
=pod

=item $success = $doc->remove_file( $filename )

Attempt to remove the given file. Give the filename as it is
returned by get_files().

=cut
######################################################################

sub remove_file
{
	my( $self, $filename ) = @_;
	
	# If it's the main file, unset it
	$self->set_value( "main" , undef ) if( $filename eq $self->get_main() );

	my $count = unlink $self->local_path()."/".$filename;
	
	if( $count != 1 )
	{
		$self->{session}->get_archive()->log( "Error removing file $filename for doc ".$self->get_value( "docid" ).": $!" );
	}

	$self->files_modified;

	return( $count==1 );
}


######################################################################
=pod

=item $success = $doc->remove_all_files

Attempt to remove all files associated with this document.

=cut
######################################################################

sub remove_all_files
{
	my( $self ) = @_;

	my $full_path = $self->local_path()."/*";

	my @to_delete = glob ($full_path);

	my $num_deleted = rmtree( \@to_delete, 0, 0 );

	$self->set_main( undef );

	if( $num_deleted < scalar @to_delete )
	{
		$self->{session}->get_archive()->log( "Error removing document files for ".$self->get_value( "docid" ).", path ".$full_path.": $!" );
		return( 0 );
	}

	$self->files_modified;

	return( 1 );
}


######################################################################
=pod

=item $doc->set_main( $main_file )

Sets the main file. Won't affect the database until a $doc->commit().

=cut
######################################################################

sub set_main
{
	my( $self, $main_file ) = @_;
	
	if( defined $main_file )
	{
		# Ensure that the file exists
		my %all_files = $self->files();

		# Set the main file if it does
		$self->set_value( "main", $main_file ) if( defined $all_files{$main_file} );
	}
	else
	{
		# The caller passed in undef, so we unset the main file
		$self->set_value( "main", undef );
	}
}


######################################################################
=pod

=item $filename = $doc->get_main

Return the name of the main file in this document.

=cut
######################################################################

sub get_main
{
	my( $self ) = @_;
	
	return( $self->{data}->{main} );
}


######################################################################
=pod

=item $doc->set_format( $format )

Set format. Won't affect the database until a commit(). Just an alias 
for $doc->set_value( "format" , $format );

=cut
######################################################################

sub set_format
{
	my( $self, $format ) = @_;
	
	$self->set_value( "format" , $format );
}


######################################################################
=pod

=item $doc->set_format_desc( $format_desc )

Set the format description.  Won't affect the database until a commit().
Just an alias for
$doc->set_value( "format_desc" , $format_desc );

=cut
######################################################################

sub set_format_desc
{
	my( $self, $format_desc ) = @_;
	
	$self->set_value( "format_desc" , $format_desc );
}


######################################################################
=pod

=item $success = $doc->upload( $filehandle, $filename )

Upload the contents of the given file handle into this document as
the given filename.

=cut
######################################################################

sub upload
{
	my( $self, $filehandle, $filename ) = @_;

	# Get the filename. File::Basename isn't flexible enough (setting 
	# internal globals in reentrant code very dodgy.)

	my( $bytes, $buffer );

	my $out_path = $self->local_path() . "/" . sanitise( $filename );

	seek( $filehandle, 0, SEEK_SET );
	
	open OUT, ">$out_path" or return( 0 );
	while( $bytes = read( $filehandle, $buffer, 1024 ) )
	{
		print OUT $buffer;
	}
	close OUT;

	$self->files_modified;
	
	return( 1 );
}

######################################################################
=pod

=item $success = $doc->add_file( $file, $filename )

$file is the full path to a file to be added to the document, with
name $filename.

=cut
######################################################################

sub add_file
{
	my( $self, $file, $filename ) = @_;

	my $fh;
	open( $fh, $file ) or return( 0 );
	my $rc = $self->upload( $fh, $filename );
	close $fh;

	return $rc;
}

######################################################################
=pod

=item $cleanfilename = sanitise( $filename )

Return just the filename (no leading path) and convert any naughty
characters to underscore.

=cut
######################################################################

sub sanitise 
{
	my( $filename ) = @_;
	$filename =~ s/.*\\//;     # Remove everything before a "\" (MSDOS or Win)
	$filename =~ s/.*\///;     # Remove everything before a "/" (UNIX)

	$filename =~ s/ /_/g;      # Change spaces into underscores

	return $filename;
}

######################################################################
=pod

=item $success = $doc->upload_archive( $filehandle, $filename, $archive_format )

Upload the contents of the given archive file. How to deal with the 
archive format is configured in SystemSettings. 

(In case the over-loading of the word "archive" is getting confusing, 
in this context we mean ".zip" or ".tar.gz" archive.)

=cut
######################################################################

sub upload_archive
{
	my( $self, $filehandle, $filename, $archive_format ) = @_;

	my $file = $self->local_path.'/'.$filename;

	# Grab the archive into a temp file
	$self->upload( 
		$filehandle, 
		$filename ) || return( 0 );

	my $rc = $self->add_archive( 
		$file,
		$archive_format );

	# Remove the temp archive
	unlink $file;

	return $rc;
}

######################################################################
=pod

=item $success = $doc->add_archive( $file, $archive_format )

$file is the full path to an archive file, eg. zip or .tar.gz 

This function will add the contents of that archive to the document.

=cut
######################################################################

sub add_archive
{
	my( $self, $file, $archive_format ) = @_;

	# Do the extraction
	my $rc = $self->{session}->get_archive()->exec( 
			$archive_format, 
			DIR => $self->local_path,
			ARC => $file );
	
	$self->files_modified;

	return( $rc==0 );
}


######################################################################
=pod

=item $success = $doc->upload_url( $url )

Attempt to grab stuff from the given URL. Grabbing HTML stuff this
way is always problematic, so (by default): only relative links will 
be followed and only links to files in the same directory or 
subdirectory will be followed.

This (by default) uses wget. The details can be configured in
SystemSettings.

=cut
######################################################################

sub upload_url
{
	my( $self, $url_in ) = @_;
	
	# Use the URI heuristic module to attempt to get a valid URL, in case
	# users haven't entered the initial http://.
	my $url = URI::Heuristic::uf_uristr( $url_in );

	# save previous dir
	my $prev_dir = getcwd();

	# Change directory to destination dir., return with failure if this 
	# fails.
	unless( chdir $self->local_path() )
	{
		chdir $prev_dir;
		return( 0 );
	}
	
	# Work out the number of directories to cut, so top-level files go in
	# at the top level in the destination dir.
	
	# Count slashes
	my $pos = -1;
	my $count = -1;
	
	do
	{
		$pos = index $url, "/", $pos+1;
		$count++;
	}
	while( $pos >= 0 );
	
	# Assuming http://server/dir/dir/filename, number of dirs to cut is
	# $count - 3.
	my $cut_dirs = $count - 3;
	
	# If the result is less than zero, assume no cut dirs (probably have URL
	# with no trailing slash, an INCORRECT result from URI::Heuristic
	$cut_dirs = 0 if( $cut_dirs < 0 );

	my $rc = $self->{session}->get_archive()->exec( 
			"wget",
			CUTDIRS => $cut_dirs,
			URL => $url );
	
	chdir $prev_dir;

	# If something's gone wrong...

	return( 0 ) if ( $rc!=0 );

	# Otherwise set the main file if appropriate
	if( !defined $self->get_main() || $self->get_main() eq "" )
	{
		my $endfile = $url;
		$endfile =~ s/.*\///;
		$self->set_main( $endfile );

		# If it's still undefined, try setting it to index.html or index.htm
		$self->set_main( "index.html" ) unless( defined $self->get_main() );
		$self->set_main( "index.htm" ) unless( defined $self->get_main() );

		# Those are our best guesses, best leave it to the user if still don't
		# have a main file.
	}
	
	$self->files_modified;

	return( 1 );
}


######################################################################
=pod

=item $success = $doc->commit

Commit any changes that have been made to this object to the
database.

Calls "set_document_automatic_fields" in the ArchiveConfig first to
set any automatic fields that may be needed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	my $dataset = $self->{session}->get_archive()->get_dataset( "document" );

	$self->{session}->get_archive()->call( "set_document_automatic_fields", $self );

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	

	my $success = $self->{session}->get_db()->update(
		$dataset,
		$self->{data} );
	
	if( !$success )
	{
		my $db_error = $self->{session}->get_db()->error();
		$self->{session}->get_archive()->log( "Error committing Document ".$self->get_value( "docid" ).": $db_error" );
	}

	$self->queue_changes;

	# cause a new new revision of the parent eprint.
	$self->get_eprint->commit( 1 );

	return( $success );
}
	

######################################################################
=pod

=item $problems = $doc->validate_meta( [$for_archive] )

Return an array of XHTML DOM objects describing validation problems
with the metadata of this document.

A reference to an empty array indicates no problems.

=cut
######################################################################

sub validate_meta
{
	my( $self, $for_archive ) = @_;

	return [] if $self->get_eprint->skip_validation;

	my @problems;

	unless( EPrints::Utils::is_set( $self->get_type() ) )
	{
		# No type specified
		push @problems, $self->{session}->html_phrase( 
					"lib/document:no_type" );
	}
	
	push @problems, $self->{session}->get_archive()->call( 
		"validate_document_meta", 
		$self, 
		$self->{session},
		$for_archive );

	return( \@problems );
}


######################################################################
=pod

=item $problems = $doc->validate( [$for_archive] )

Return an array of XHTML DOM objects describing validation problems
with the entire document, including the metadata and archive config
specific requirements.

A reference to an empty array indicates no problems.

=cut
######################################################################

sub validate
{
	my( $self, $for_archive ) = @_;

	return [] if $self->get_eprint->skip_validation;

	my @problems;

	push @problems,@{$self->validate_meta( $for_archive )};
	
	# System default checks:
	# Make sure there's at least one file!!
	my %files = $self->files();

	if( scalar keys %files ==0 )
	{
		push @problems, $self->{session}->html_phrase( "lib/document:no_files" );
	}
	elsif( !defined $self->get_main() || $self->get_main() eq "" )
	{
		# No file selected as main!
		push @problems, $self->{session}->html_phrase( "lib/document:no_first" );
	}
		
	# Site-specific checks
	push @problems, $self->{session}->get_archive()->call( 
		"validate_document", 
		$self, 
		$self->{session},
		$for_archive );

	return( \@problems );
}


######################################################################
=pod

=item $boolean = $doc->can_view( $user )

Return true if this documents security settings allow the given user
to view it.

=cut
######################################################################

sub can_view
{
	my( $self, $user ) = @_;

	return $self->{session}->get_archive()->call( 
		"can_user_view_document",
		$self,
		$user );	
}


######################################################################
=pod

=item $type = $doc->get_type

Return the type of this document.

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return $self->get_value( "format" );
}

######################################################################
=pod

=item $doc->files_modified

This method does all the things that need doing when a file has been
modified.

=cut
######################################################################

sub files_modified
{
	my( $self ) = @_;

	$self->rehash;

	$self->{session}->get_db->index_queue( 
		$self->get_eprint->get_dataset->id,
		$self->get_eprint->get_id,
		$EPrints::Utils::FULLTEXT );

	$self->commit( 1 );

	# remove the now invalid cache of words from this document
	unlink $self->words_file if( -e $self->words_file );
}

######################################################################
=pod

=item $doc->rehash

Recalculate the hash value of the document. Uses MD5 of the files (in
alphabetic order), but can use user specified hashing function instead.

=cut
######################################################################

sub rehash
{
	my( $self ) = @_;

	my %f = $self->files;
	my @filelist = ();
	foreach my $file ( keys %f )
	{
		push @filelist, $self->local_path."/".$file;
	}

	my $eprint = $self->get_eprint;
	unless( defined $eprint )
	{
		$self->{session}->get_archive->log(
"rehash: skipped document with no associated eprint (".$self->get_id.")." );
		return;
	}

	my $hashfile = $self->get_eprint->local_path."/".
		$self->get_value( "docid" ).".".
		EPrints::Utils::get_UTC_timestamp().".xsh";

	EPrints::Probity::create_log( 
		$self->{session}, 
		\@filelist,
		$hashfile );
}

######################################################################
=pod

=item $text = $doc->get_text

Get the text of the document as a UTF-8 encoded string, if possible.

This is used for full-text indexing. The text will probably not
be well formated.

=cut
######################################################################

sub get_text
{
	my( $self ) = @_;

	my $converter = new Convert::PlainText;
	my $words_file = $self->words_file;
	return '' unless defined $words_file;

	my %files = $self->files;
	my @fullpath_files = ();
	foreach( keys %files )
	{
		push @fullpath_files, $self->local_path."/".$_;
	}
	$converter->build($words_file, @fullpath_files);

	return '' unless open( WORDS, $words_file );
	my $words = join( '', <WORDS> );
	close WORDS;

	return $words;
}

######################################################################
=pod

=item $filename = $doc->words_file

Return the filename in which this document uses to cache words 
extracted from the full text.

=cut
######################################################################

sub words_file
{
	my( $self ) = @_;
	return $self->cache_file( 'words' );
}

######################################################################
=pod

=item $filename = $doc->indexcodes_file

Return the filename in which this document uses to cache indexcodes 
extracted from the words cache file.

=cut
######################################################################

sub indexcodes_file
{
	my( $self ) = @_;
	return $self->cache_file( 'indexcodes' );
}

######################################################################
=pod

=item $filename = $doc->cache_file( $suffix );

Return a cache filename for this document with the givven suffix.

=cut
######################################################################

sub cache_file
{
	my( $self, $suffix ) = @_;

	my $eprint =  $self->get_eprint;
	return unless( defined $eprint );

	return $eprint->local_path."/".
		$self->get_value( "docid" ).".".$suffix;
}
	
######################################################################
#
# $doc->register_parent( $eprint )
#
# Give the document the EPrints::EPrint object that it belongs to.
#
# This may cause reference loops, but it does avoid two identical
# EPrints objects existing at once.
#
######################################################################

sub register_parent
{
	my( $self, $parent ) = @_;

	$self->{eprint} = $parent;
}

1;

######################################################################
=pod

=back

=cut

