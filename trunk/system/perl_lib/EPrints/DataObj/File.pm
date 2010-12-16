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

=pod

=for Pod2Wiki

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

=item $dataobj = EPrints::DataObj::File->new_from_filename( $session, $dataobj, $filename )

Convenience method to get an existing File object for $filename stored in $dataobj.

Returns undef if no such record exists.

=cut

sub new_from_filename
{
	my( $class, $repo, $dataobj, $filename ) = @_;
	
	return undef if !EPrints::Utils::is_set( $filename );

	my $dataset = $repo->dataset( $class->get_dataset_id );

	my $results = $dataset->search(
		filters => [
			{
				meta_fields => [qw( datasetid )],
				value => $dataobj->get_dataset->base_id,
				match => "EX",
			},
			{
				meta_fields => [qw( objectid )],
				value => $dataobj->id,
				match => "EX",
			},
			{
				meta_fields => [qw( filename )],
				value => $filename,
				match => "EX",
			},
		]);

	return $results->item( 0 );
}

=item $dataobj = EPrints::DataObj::File->create_from_data( $session, $data [, $dataset ] )

Create a new File record using $data. If "_content" is defined in $data it will be read from and stored - for possible values see set_file().

=cut

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $content = delete $data->{_content} || delete $data->{_filehandle};

	# if things go wrong later filesize will be zero
	my $filesize = $data->{filesize};
	$data->{filesize} = 0;

	my $self;

	my $ok = 1;
	# read from filehandle/scalar etc.
	if( defined( $content ) )
	{
		EPrints->abort( "Must defined filesize when using _content" ) if !defined $filesize;

		$self = $class->SUPER::create_from_data( $session, $data, $dataset );
		return if !defined $self;

		$ok = defined $self->set_file( $content, $filesize );
	}
	# read from XML (Base64 encoded)
	elsif( EPrints::Utils::is_set( $data->{data} ) )
	{
		$self = $class->SUPER::create_from_data( $session, $data, $dataset );
		return if !defined $self;

		use bytes;
		my $data = MIME::Base64::decode( delete $data->{data} );
		$ok = defined $self->set_file( \$data, length($data) );
	}
	# read from a URL
	elsif( EPrints::Utils::is_set( $data->{url} ) )
	{
		$self = $class->SUPER::create_from_data( $session, $data, $dataset );
		return if !defined $self;

		my $tmpfile = File::Temp->new;

		my $r = EPrints::Utils::wget( $session, $data->{url}, $tmpfile );
		if( $r->is_success )
		{
			seek( $tmpfile, 0, 0 );
			$ok = $self->set_file( $tmpfile, -s $tmpfile );
		}
		else
		{
			$session->get_repository->log( "Failed to retrieve $data->{url}: " . $r->code . " " . $r->message );
			$ok = 0;
		}
	}
	else
	{
		$data->{filesize} = $filesize; # callers responsibility
		$self = $class->SUPER::create_from_data( $session, $data, $dataset );
		return if !defined $self;
	}

	# content write failed
	if( !$ok )
	{
		$self->remove();
		return undef;
	}

	$self->commit();

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
		{ name=>"fileid", type=>"counter", required=>1, import=>0, show_in_html=>0,
			can_clone=>0, sql_counter=>"fileid" },

		{ name=>"datasetid", type=>"id", text_index=>0, import=>0,
			can_clone=>0 }, 

		{ name=>"objectid", type=>"int", import=>0, can_clone=>0 }, 

		{ name=>"filename", type=>"id", },

		{ name=>"mime_type", type=>"id", },

		{ name=>"hash", type=>"id", },

		{ name=>"hash_type", type=>"id", },

		{ name=>"filesize", type=>"bigint", },

		{ name=>"mtime", type=>"timestamp", },

		{ name=>"url", type=>"url", virtual=>1 },

		{ name=>"data", type=>"base64", virtual=>1 },

		{
			export_as_xml => 0,
			name=>"copies", type=>"compound", multiple=>1,
			fields=>[{
				sub_name=>"pluginid",
				type=>"text",
			},{
				sub_name=>"sourceid",
				type=>"text",
			}],
		},
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
	my( $class, $session, $data, $dataset ) = @_;
	
	$class->SUPER::get_defaults( $session, $data, $dataset );

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

=item $new_file = $file->clone( $parent )

Clone the $file object (including contained files) and return the new object.

=cut

sub clone
{
	my( $self, $parent ) = @_;

	my $data = EPrints::Utils::clone( $self->{data} );

	$data->{objectid} = $parent->get_id;
	$data->{_parent} = $parent;

	my $new_file = $self->{dataset}->create_object( $self->{session}, $data );
	return undef if !defined $new_file;

	my $storage = $self->{session}->get_storage;

	my $rc = 1;

	$rc &&= $storage->open_write( $new_file );
	$rc &&= $self->get_file( sub { $storage->write( $new_file, $_[0] ) } );
	$rc &&= $storage->close_write( $new_file );

	if( !$rc )
	{
		$new_file->remove;
		return undef;
	}

	return $new_file;
}

=item $success = $file->remove

Delete the stored file.

=cut

sub remove
{
	my( $self ) = @_;

	$self->SUPER::remove();

	$self->get_session->get_storage->delete( $self );
}

=item $filename = $file->get_local_copy()

Return the name of a local copy of the file (may be a L<File::Temp> object).

Will retrieve and cache the remote object if necessary.

=cut

sub get_local_copy
{
	my( $self ) = @_;

	return $self->get_session->get_storage->get_local_copy( $self );
}

sub get_remote_copy
{
	my( $self ) = @_;

	return $self->get_session->get_storage->get_remote_copy( $self );
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

Returns the number of bytes read from $filehandle or undef on failure.

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
	my $type = $self->{session}->get_repository->call( "guess_doc_type", $self->{session}, $filename );
	if( $type ne "other" )
	{
		$self->set_value( "mime_type", $type );
	}

	$filesize = $self->set_file( $fh, $filesize );
	
	$self->commit();

	return $filesize;
}

=item $success = $stored->write_copy( $filename )

Write a copy of this file to $filename.

Returns true if the written file contains the same number of bytes as the stored file.

=cut

sub write_copy
{
	my( $self, $filename ) = @_;

	open(my $out, ">", $filename) or return 0;

	my $rc = $self->write_copy_fh( $out );

	close($out);

	return $rc;
}

=item $success = $stored->write_copy_fh( $filehandle )

Write a copy of this file to $filehandle.

=cut

sub write_copy_fh
{
	my( $self, $out ) = @_;

	return $self->get_file(sub {
		print $out $_[0]
	});
}

=item $md5 = $stored->generate_md5

Calculates and returns the MD5 for this file.

=cut

sub generate_md5
{
	my( $self ) = @_;

	my $md5 = Digest::MD5->new;

	$self->get_file(sub {
		$md5->add( $_[0] )
	});

	return $md5->hexdigest;
}

sub update_md5
{
	my( $self ) = @_;

	my $md5 = $self->generate_md5;

	$self->set_value( "hash", $md5 );
	$self->set_value( "hash_type", "MD5" );
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

	$self->get_file(sub {
		$sha->add( $_[0] )
	});

	return $sha->hexdigest;
}

sub update_sha
{
	my( $self, $alg ) = @_;

	$alg ||= "256";

	my $digest = $self->generate_sha( $alg );

	$self->set_value( "hash", $digest );
	$self->set_value( "hash_type", "SHA-$alg" );
}

sub to_sax
{
	my( $self, %opts ) = @_;

	my $handler = $opts{Handler};
	my $dataset = $self->dataset;
	my $name = $dataset->base_id;

	$handler->start_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
		Attributes => {
			('{}id') => {
				Prefix => '',
				LocalName => 'id',
				Name => 'id',
				NamespaceURI => '',
				Value => $self->uri,
			},
		},
	});

	if( $self->value( "datasetid" ) eq "document" )
	{
		my $doc = $self->parent();
		my $url = $doc->get_url( $self->value( "filename" ) );
		$self->set_value( "url", $url );
	}

	foreach my $field ($dataset->fields)
	{
		next if !$field->property( "export_as_xml" );

		$field->to_sax(
			$field->get_value( $self ),
			%opts
		);
	}

	if( $opts{embed} )
	{
		$handler->start_element({
			Prefix => '',
			LocalName => 'data',
			Name => 'data',
			NamespaceURI => EPrints::Const::EP_NS_DATA,
			Attributes => {
				('{}encoding') => {
					Prefix => '',
					LocalName => 'encoding',
					Name => 'encoding',
					NamespaceURI => '',
					Value => 'base64',
				},
			},
		});
		my $buffer = "";
		$self->get_file(sub {
			use bytes;
			substr($_[0],0,0) = $buffer;
			$handler->characters({
				Data => MIME::Base64::encode_base64( substr($_[0],0,length($_[0]) - length($_[0])%57 ) )
			});
			$buffer = substr($_[0],length($_[0]) - length($_[0])%57);
		});
		$handler->characters({
			Data => MIME::Base64::encode_base64( $buffer )
		});
		$handler->end_element({
			Prefix => '',
			LocalName => 'data',
			Name => 'data',
			NamespaceURI => EPrints::Const::EP_NS_DATA,
		});
	}

	$handler->end_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
}

=item $stored->add_plugin_copy( $plugin, $sourceid )

Add a copy of this file stored using $plugin identified by $sourceid.

=cut

sub add_plugin_copy
{
	my( $self, $plugin, $sourceid ) = @_;

	my $copies = EPrints::Utils::clone( $self->get_value( "copies" ) );
	push @$copies, {
		pluginid => $plugin->get_id,
		sourceid => $sourceid,
	};
	$self->set_value( "copies", $copies );
}

=item $stored->remove_plugin_copy( $plugin )

Remove the copy of this file stored using $plugin.

=cut

sub remove_plugin_copy
{
	my( $self, $plugin ) = @_;

	my $copies = EPrints::Utils::clone( $self->get_value( "copies" ) );
	@$copies = grep { $_->{pluginid} ne $plugin->get_id } @$copies;
	$self->set_value( "copies", $copies );
}

=item $success = $stored->get_file( CALLBACK [, $offset, $n ] )

Get the contents of the stored file - see L<EPrints::Storage/retrieve>.

$offset is the position in bytes to start reading from, default 0.

$n is the number of bytes to read, default C<filesize>.

=cut

sub get_file
{
	my( $self, $f, $offset, $n ) = @_;

	$offset = 0 if !defined $offset;
	$n = $self->value( "filesize" ) if !defined $n;

	return $self->{session}->get_storage->retrieve( $self, $offset, $n, $f );
}

=item $content_length = $stored->set_file( CONTENT, $content_length )

Reads data from CONTENT and stores it. Sets the MD5 hash and filesize.

If the write failed returns undef and sets the filesize to 0.

CONTENT may be one of:

	CODEREF - will be called until it returns empty string ("")
	SCALARREF - a scalar reference will be used as-is (expects bytes)
	GLOB - will be treated as a file handle and read with sysread()

This method does not check the actual number of bytes read is the same as $content_length.

=cut

sub set_file
{
	my( $self, $content, $clen ) = @_;

	use bytes;
	# on 32bit platforms this will cause wrapping at 2**31, without integer
	# Perl will wrap at some much larger value (so use 64bit O/S!)
#	use integer;

	my $md5 = Digest::MD5->new;

	my $f;
	if( ref($content) eq "CODE" )
	{
		$f = sub {
			my $buffer = &$content();
			$md5->add( $buffer );
			return $buffer;
		};
	}
	elsif( ref($content) eq "SCALAR" )
	{
		$md5->add( $$content );
		my $first = 1;
		$f = sub {
			return $first-- ? $$content : "";
		};
	}
	else
	{
		binmode($content);
		$f = sub {
			return "" unless sysread($content,my $buffer,16384);
			$md5->add( $buffer );
			return $buffer;
		};
	}

	$self->set_value( "filesize", 0 );
	$self->set_value( "hash", undef );
	$self->set_value( "hash_type", undef );

	my $rlen = do {
		local $self->{data}->{filesize} = $clen;
		$self->{session}->get_storage->store( $self, $f );
	};

	# no storage plugin or plugins failed
	if( !defined $rlen )
	{
		$self->{session}->log( $self->get_dataset_id."/".$self->get_id."::set_file(".$self->get_value( "filename" ).") failed: No storage plugins succeeded" );
		return undef;
	}

	# read failed
	if( $rlen != $clen )
	{
		$self->{session}->log( $self->get_dataset_id."/".$self->get_id."::set_file(".$self->get_value( "filename" ).") failed: expected $clen bytes but actually got $rlen bytes" );
		return undef;
	}

	$self->set_value( "filesize", $rlen );
	$self->set_value( "hash", $md5->hexdigest );
	$self->set_value( "hash_type", "MD5" );

	return $rlen;
}

sub start_element
{
	my( $self, $data, $epdata, $state ) = @_;

	$self->SUPER::start_element( $data, $epdata, $state );

	if( $state->{depth} == 2 )
	{
		my $attr = $data->{Attributes}->{"{}encoding"};
		if( defined $attr && $data->{LocalName} eq "data" && $attr->{Value} eq "base64" )
		{
			delete $state->{handler};

			$state->{encoding} = $attr->{Value};
			$state->{buffer} = "";
			my $tmpfile = $epdata->{_content} = File::Temp->new();
			binmode($tmpfile);
		}
	}
}

sub end_element
{
	my( $self, $data, $epdata, $state ) = @_;

	if( $state->{depth} == 2 && defined $state->{encoding} )
	{
		my $tmpfile = $epdata->{_content};
		print $tmpfile MIME::Base64::decode_base64( $state->{buffer} );
		seek($tmpfile,0,0);
		delete $state->{encoding};
		delete $state->{buffer};
	}

	$self->SUPER::end_element( $data, $epdata, $state );
}

sub characters
{
	my( $self, $data, $epdata, $state ) = @_;

	$self->SUPER::characters( $data, $epdata, $state );

	if( $state->{depth} == 2 && defined $state->{encoding} )
	{
		my $tmpfile = $epdata->{_content};
		$state->{buffer} .= $data->{Data};
		for($state->{buffer})
		{
			print $tmpfile MIME::Base64::decode_base64( substr($_,0,length($_) - length($_)%77) );
			$_ = substr($_,length($_) - length($_)%77);
		}
	}
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut
