=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::DataObj::EPM> - Class representing an EPrints Package

=head1 DESCRIPTION

=head1 SYSTEM METADATA

=over 4

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

package EPrints::DataObj::EPM;

@ISA = ( 'EPrints::DataObj' );

use strict;

######################################################################
=pod

=item $metadata = EPrints::DataObj::EPM->get_system_field_info

Return an array describing the system metadata of the EPrint dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return ( 
	
	# a unique name for this package
	{ name=>"epmid", type=>"id", required=>1, import=>0, can_clone=>0, },

	# bazaar.eprint.eprintid
	{ name=>"eprintid", type=>"int", can_clone=>0, },

	# package contents
	{ name=>"documents", type=>"subobject", datasetid=>'document',
		multiple=>1 },

	# version in x.y.z
	{ name=>"version", type=>"text" },

	# control 'Screen' plugin
	# 	action_enable, action_disable
	# 	render_action_link [configure link]
	# 	render [configuration]
	{ name=>"controller", type=>"text", render_value => \&render_controller, },

	# change to functional content
	{ name=>"datestamp", type=>"date" },

	# human-readable title
	{ name=>"title", type=>"longtext", },

	# human-readable description
	{ name=>"description", type=>"longtext", },
	
	# human-readable description of requirements
	{ name=>"requirements", type=>"longtext", },

	# add-on home-page
	{ name=>"home_page", type=>"url" },

	# icon filename
	{ name=>"icon", type=>"url", render_value => \&render_icon, },

	);
}

sub render_controller
{
	my( $repo, $field, $value, undef, undef, $epm ) = @_;

	$value = "EPMC" if !defined $value;

	my $plugin = $repo->plugin( "Screen::$value" );
	return $repo->xml->create_document_fragment if !defined $plugin;

	return $plugin->render_action_link;
}

sub render_icon
{
	my( $repo, $field, $value, undef, undef, $epm ) = @_;

	$value = "images/epm/unknown.png" if !EPrints::Utils::is_set( $value );

	my $url = $value =~ /^https?:/ ?
		$value :
		$repo->current_url( host => 1, path => "static", $value );

	return $repo->xml->create_element( "img",
		src => $url,
	);
}

sub get_dataset_id
{
	return "epm";
}

# mostly for errors generated by us
sub html_phrase
{
	my( $self, $phraseid, @pins ) = @_;

	return $self->repository->html_phrase( "epm:$phraseid", @pins );
}

# convert epdata to objects in documents/documents.files
sub _upgrade
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my $document_dataset = $repo->dataset( "document" );
	my $file_dataset = $repo->dataset( "file" );

	foreach my $doc (@{$self->value( "documents" )})
	{
		if( !UNIVERSAL::isa( $doc, "EPrints::DataObj" ) )
		{
			$doc = $document_dataset->make_dataobj( $doc );
		}
		foreach my $file (@{$doc->value( "files" )})
		{
			if( !UNIVERSAL::isa( $file, "EPrints::DataObj" ) )
			{
				my $content = delete $file->{_content};
				$file = $file_dataset->make_dataobj( $file );
				if( defined $content )
				{
					sysread($content,my $data,-s $content);
					$file->set_value( "data",
						MIME::Base64::encode_base64( $data )
					);
				}
				else
				{
					next;
#					Carp::carp( "Package is missing file content" );
				}
			}
		}
	}
}

=item EPrints::DataObj::EPM->map( $repo, sub { ... }, $ctx )

Apply a function over all installed EPMs.

	sub {
		my( $repo, $dataset, $epm [, $ctx ] ) = @_;
	}

This loads the EPM index files only.

=cut

sub map
{
	my( $class, $repo, $f, $ctx ) = @_;

	my $dataset = $repo->dataset( "epm" );

	my $epm_dir = $repo->config( "base_path" ) . "/lib/epm";
	opendir(my $dh, $epm_dir) or return;
	while(defined(my $file = readdir($dh)))
	{
		next if $file =~ /^\./;
		next if !-f "$epm_dir/$file/$file.epmi";
		if(open(my $fh, "<", "$epm_dir/$file/$file.epmi"))
		{
			sysread($fh, my $xml, -s $fh);
			close($fh);
			&$f( $repo, $dataset, $class->new_from_xml( $repo, $xml ), $ctx );
		}
	}
	closedir($dh);
}

=item $epm = EPrints::DataObj::EPM->new( $repo, $id )

Returns a new object representing the installed package $id.

=cut

sub new
{
	my( $class, $repo, $id ) = @_;

	my $filepath = $repo->config( "base_path" ) . "/lib/epm/$id/$id.epm";
	if( open(my $fh, "<", $filepath) )
	{
		sysread($fh, my $xml, -s $fh);
		close($fh);
		return $class->new_from_xml( $repo, $xml );
	}

	return;
}

sub new_from_xml
{
	my( $class, $repo, $xml ) = @_;

	my $doc = $repo->xml->parse_string( $xml );

	my $epdata = $repo->dataset( "epm" )->dataobj_class->xml_to_epdata(
		$repo, $doc->documentElement
	);

	my $epm = $repo->dataset( "epm" )->make_dataobj( $epdata );
	$epm->_upgrade;

	return $epm;
}

=item $epm = EPrint::DataObj::EPM->new_from_manifest( $repo, $epdata [, @manifest ] )

Makes and returns a new EPM object based on a manifest of installable files.

=cut

sub new_from_manifest
{
	my( $class, $repo, $epdata, @manifest ) = @_;

	my $self = $class->SUPER::new_from_data( $repo, $epdata );

	my $base_path = $self->repository->config( "base_path" ) . "/lib";

	my $install = $repo->dataset( "document" )->make_dataobj({
		content => "install",
		files => [],
	});
	$self->set_value( "documents", [ $install ]);

	for(@manifest)
	{
		my $filepath = "$base_path/$_";
		use bytes;
		open(my $fh, "<", $filepath) or die "Error opening $filepath: $!";
		sysread($fh, my $data, -s $fh);
		close($fh);
		my $md5 = Digest::MD5::md5_hex( $data );

		$install->set_value( "files", [
			@{$install->value( "files")},
			$repo->dataset( "file" )->make_dataobj({
				filename => $_,
				filesize => length($data),
				data => MIME::Base64::encode_base64( $data ),
				hash => $md5,
				hash_type => "MD5",
			})
		]);

		if( m#^static/(images/epm/.*)# )
		{
			$self->set_value( "icon", $1 );
			my $icon = $repo->dataset( "document" )->make_dataobj({
				content => "icon",
				files => [],
			});
			$icon->set_value( "files", [
				$repo->dataset( "file" )->make_dataobj({
					filename => $_,
					filesize => length($data),
					data => MIME::Base64::encode_base64( $data ),
					hash => $md5,
					hash_type => "MD5",
				})
			]);
			$self->set_value( "documents", [
				@{$self->value( "documents" )},
				$icon,
			]);
		}
	}

	return $self;
}

=item $epm->commit

Commit any changes to the installed .epm, .epmi files.

=cut

sub commit
{
	my( $self ) = @_;

	EPrints->system->mkdir( $self->epm_dir );

	if( open(my $fh, ">", $self->epm_dir . "/" . $self->id . ".epm") )
	{
		syswrite($fh, $self->serialise( 1 ));
		close($fh);
	}
	if( open(my $fh, ">", $self->epm_dir . "/" . $self->id . ".epmi") )
	{
		syswrite($fh, $self->serialise( 0 ));
		close($fh);
	}
}

=item $epm->rebuild

Reload all of the installed files (regenerating hashes if necessary).

=cut

sub rebuild
{
	my( $self ) = @_;

	my @files = $self->installed_files;

	my $epm = ref($self)->new_from_manifest(
		$self->repository,
		$self->get_data,
		map { $_->value( "filename" ) } @files
	);

	$self->set_value( "documents", $epm->value( "documents" ) );
	for(keys %{$epm->{changed}})
	{
		$self->set_value( $_, $epm->value( $_ ) );
	}
}

=item $bool = $epm->is_enabled

Returns true if the $epm is enabled for the current repository.

=cut

sub is_enabled
{
	my( $self ) = @_;

	return -f $self->_is_enabled_filepath;
}

=item @repoids = $epm->repositories

Returns a list of repository ids this $epm is enabled in.

=cut

sub repositories
{
	my( $self ) = @_;

	my @repoids;

	foreach my $repoid (EPrints->repository_ids)
	{
		local $self->{session} = EPrints->repository( $repoid );
		push @repoids, $repoid if $self->is_enabled;
	}

	return @repoids;
}

=item $filename = $epm->package_filename()

Returns the complete package filename.

=cut

sub package_filename
{
	my( $self ) = @_;

	return $self->id . '-' . $self->value( "version" ) . '.epm';
}

=item $dir = $epm->epm_dir

Path to the epm directory for this $epm.

=cut

sub epm_dir
{
	my( $self ) = @_;

	return $self->repository->config( "base_path" ) . "/lib/epm/" . $self->id;
}

=item @files = $epm->installed_files()

Returns a list of installed files as L<EPrints::DataObj::File>.

=cut

sub installed_files
{
	my( $self ) = @_;

	my $install;
	for(@{$self->value( "documents" )})
	{
		$install = $_ if $_->value( "content" ) eq "install";
	}
	return () if !defined $install;

	return @{$install->value( "files" )};
}

=item @files = $epm->config_files()

Returns the list of configuration files used to enable/configure an $epm.

=cut

sub config_files
{
	my( $self ) = @_;

	my $epmid = $self->id;

	return grep {
			$_->value( "filename" ) =~ m# ^epm/$epmid/cfg\.d/[^\/]+\.pl$ #x
		} $self->installed_files;
}

=item $screen = $epm->control_screen( %params )

Returns the control screen for this $epm. %params are passed to the plugin constructor.

=cut

sub control_screen
{
	my( $self, %params ) = @_;

	my $controller = $self->value( "controller" );
	$controller = "EPMC" if !defined $controller;
	$controller = $self->repository->plugin( "Screen::$controller",
			%params,
		);
	$controller = $self->repository->plugin( "Screen::EPM",
			%params,
		) if !defined $controller;

	return $controller;
}

=item $xml = $epm->serialise( [ FILES ] )

Returns the XML serialisation of $epm. If FILES is true files are included.

=cut

sub serialise
{
	my( $self, $files ) = @_;

	local $self->{data}->{documents} = [] if !$files;

	return "<?xml version='1.0'?>\n".$self->repository->xml->to_string(
		$self->to_xml,
		indent => 1
	);
}

=item $ok = $epm->install( HANDLER [, FORCE ] )

Install the EPM into the system. HANDLER is a L<EPrints::CLIProcessor> or
L<EPrints::ScreenProcessor>, used for reporting errors.

=cut

sub install
{
	my( $self, $handler, $force ) = @_;

	my $repo = $self->repository;

	$self->_upgrade;

	my @files = $self->installed_files;
	if( !@files )
	{
		$handler->add_message( "error", $self->html_phrase( "no_files" ) );
		return 0;
	}

	my %files;

	my $base_path = $repo->config( "base_path" ) . "/lib";

	for(@files)
	{
		my $filename = $_->value( "filename" );
		if( $filename =~ m#[\/]\.# )
		{
			$handler->add_message( "error", $self->html_phrase( "bad_filename",
					filename => $repo->xml->create_text_node( $filename ),
				) );
			return 0;
		}
		my $data = MIME::Base64::decode_base64( $_->value( "data" ) );
		my $md5 = Digest::MD5::md5_hex( $data );
		if( $md5 ne $_->value( "hash" ) )
		{
			$handler->add_message( "error", $self->html_phrase( "bad_checksum",
					filename => $repo->xml->create_text_node( $filename ),
				) );
			return 0;
		}
		my $filepath = "$base_path/$filename";
		if( !$force && -e $filepath )
		{
			open(my $fh, "<", $filepath)
				or die "Error reading from $filename: $!";
			sysread($fh, my $rdata, -s $fh);
			close($fh);
			if( Digest::MD5::md5_hex( $rdata ) ne $md5 )
			{
				$handler->add_message( "error", $self->html_phrase( "file_exists",
						filename => $repo->xml->create_text_node( $filename ),
					) );
				return 0;
			}
		}
		my $directory = $filepath;
		$directory =~ s/[^\/]+$//;
		if( !-d $directory && !EPrints->system->mkdir( $directory ) )
		{
			$handler->add_message( "error", $self->html_phrase( "file_error",
					filename => $repo->xml->create_text_node( $directory ),
					error => $repo->xml->create_text_node( $! ),
				) );
			return 0;
		}
		$files{$filepath} = $data;
	}

	while(my( $filepath, $data ) = each %files)
	{
		my $fh;
		if( !open($fh, ">", $filepath) )
		{
			$handler->add_message( "error", $self->html_phrase( "file_error",
					filename => $repo->xml->create_text_node( $filepath ),
					error => $repo->xml->create_text_node( $! ),
				) );
			return 0;
		}
		syswrite($fh, $data);
		close($fh);
	}

	$self->commit;

	return 1;
}

=item $ok = $epm->uninstall( HANDLER [, FORCE ] )

Remove the EPM from the system. HANDLER is a L<EPrints::CLIProcessor> or
L<EPrints::ScreenProcessor>, used for reporting errors.

=cut

sub uninstall
{
	my( $self, $handler, $force ) = @_;

	my $repo = $self->repository;

	$self->_upgrade;

	my @files = $self->installed_files;

	my %files;

	my $base_path = $repo->config( "base_path" ) . "/lib";

	for(@files)
	{
		my $filename = $_->value( "filename" );
		my $filepath = "$base_path/$filename";
		next if !-e $filepath; # skip missing files
		my $data = "";
		if( open(my $fh, "<", $filepath) )
		{
			sysread($fh,$data,-s $fh);
			close($fh);
		}
		if( !$force && Digest::MD5::md5_hex($data) ne $_->value( "hash" ) )
		{
			$handler->add_message( "error", $self->html_phrase( "bad_checksum",
					filename => $repo->xml->create_text_node( $filename ),
				) );
			return 0;
		}
		$files{$filepath} = 1;
	}

	foreach my $filepath (keys %files)
	{
		if( !unlink($filepath) )
		{
			$handler->add_message( "error", $self->html_phrase( "unlink_failed",
					filename => $repo->xml->create_text_node( $filepath ),
				) );
		}
	}

	for(qw( .epm .epmi ))
	{
		unlink($self->epm_dir . "/" . $self->id . $_);
	}

	# sanity check
	if( length($self->id) )
	{
		EPrints::Utils::rmtree( "$base_path/epm/".$self->id );
	}

	return 1;
}

sub _is_enabled_filepath
{
	my( $self ) = @_;

	return $self->{session}->config( "archiveroot" ) . "/cfg/epm/" . $self->id;
}

=item $ok = $epm->enable( $handler )

Enables the $epm for the current repository.

=cut

sub enable
{
	my( $self, $handler ) = @_;

	my $repo = $self->repository;

	my $datasets = $self->current_datasets;

	my $base_path = $repo->config( "base_path" ) . "/lib";
	my $epmid = $self->id;

	FILE: foreach my $file ($self->config_files)
	{
		my $filename = $file->value( "filename" );
		my $filepath = $base_path . "/$filename";
		next if $filename !~ m# /([^\/]+)$ #x;

		my $targetpath = $repo->config( "archiveroot" ) . "/cfg/cfg.d/$1";
		my $data;
		if(open(my $fh, "<", $filepath))
		{
			sysread($fh, $data, -s $fh);
			close($fh);
		}
		else
		{
			$handler->add_message( "warning", $self->html_phrase( "missing",
					filename => $repo->xml->create_text_node( $filepath ),
				) );
			next FILE;
		}
		if( !$file->is_set( "hash" ) )
		{
			$file->set_value( "hash", Digest::MD5::md5_hex( $data ) );
			$file->set_value( "hash_type", "MD5" );
		}
		elsif( $file->value( "hash" ) ne Digest::MD5::md5_hex( $data ) )
		{
			$handler->add_message( "error", $self->html_phrase( "bad_checksum",
					filename => $repo->xml->create_text_node( $filename ),
				) );
			return 0;
		}
		if( -f $targetpath )
		{
			my $tdata;
			if(open(my $fh, "<", $targetpath))
			{
				sysread($fh, $tdata, -s $fh);
				close($fh);
			}
			if( $file->value( "hash" ) eq Digest::MD5::md5_hex( $tdata ) )
			{
				next FILE;
			}
			else
			{
				$handler->add_message( "error", $self->html_phrase( "file_exists",
						filename => $repo->xml->create_text_node( $targetpath ),
					) );
				return 0;
			}
		}
		if(open(my $fh, ">", $targetpath))
		{
			syswrite($fh, $data);
			close($fh);
		}
	}

	EPrints->system->mkdir( $repo->config( "archiveroot" ) . "/cfg/epm" );
	open( my $fh, ">", $self->_is_enabled_filepath );
	close( $fh );

	# reload the configuration
	$repo->load_config;

	$self->update_datasets( $datasets );

	return 1;
}

sub disable
{
	my( $self, $handler ) = @_;

	my $repo = $self->repository;

	my $datasets = $self->current_datasets;

	my $epmid = $self->id;

	foreach my $file ($self->config_files)
	{
		my $filename = $file->value( "filename" );
		next if $filename !~ m# /([^\/]+)$ #x;
		my $targetpath = $repo->config( "archiveroot" ) . "/cfg/cfg.d/$1";
		next if !-f $targetpath;
		unlink( $targetpath );
	}

	unlink( $self->_is_enabled_filepath );

	# reload the configuration
	$repo->load_config;

	$self->update_datasets( $datasets );

	return 1;
}

=back

=head2 Utility Methods

=over 4

=cut

=item $conf = $epm->current_datasets()

=cut

sub current_datasets
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my $data = {};

	foreach my $datasetid ( $repo->get_sql_dataset_ids() )
	{
		my $dataset = $repo->dataset( $datasetid );
		$data->{$datasetid}->{dataset} = $dataset;
		foreach my $field ($repo->dataset( $datasetid )->fields)
		{
			next if $field->is_virtual;
			$data->{$datasetid}->{fields}->{$field->name} = $field;
		}
	}

	return $data;
}

=item $ok = $epm->update_datasets( $conf )

Update the datasets following any configuration changes made by the extension on being enabled. $conf should be retrieved before enabling by using L</current_datasets>.

=cut

sub update_datasets
{
	my( $self, $before ) = @_;

	my $repo = $self->repository;
	
	my $db = $repo->get_db();

	my $rc = 1;

	# create new datasets/fields tables
	foreach my $datasetid ($repo->get_sql_dataset_ids)
	{
		my $dataset = $repo->dataset( $datasetid );
		if( !exists $before->{$datasetid} )
		{
			$db->create_dataset_tables( $dataset );
		}
		else
		{
			foreach my $field ($dataset->fields)
			{
				next if $field->is_virtual;
				if( !exists $before->{$datasetid}->{fields}->{$field->name} )
				{
					$db->add_field( $dataset, $field );
				}
			}
		}
	}

	# destroy removed datasets/fields tables
	foreach my $datasetid ( keys %$before )
	{
		my $dataset = $before->{$datasetid};
		if( !defined $repo->dataset( $datasetid ) )
		{
			$db->drop_dataset_tables( $dataset );
		}
		else
		{
			foreach my $field (values %{$before->{$datasetid}->{fields}})
			{
				if( !$repo->dataset( $datasetid )->has_field( $field->name ) )
				{
					$db->remove_field( $dataset, $field );
				}
			}
		}
	}
	
	return 1;
}

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

