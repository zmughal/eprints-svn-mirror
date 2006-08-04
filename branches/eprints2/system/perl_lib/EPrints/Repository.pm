######################################################################
#
# EPrints::Repository
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

B<EPrints::Repository> - A single eprint repository

=head1 DESCRIPTION

This class is a single eprint repository with its own configuration,
database and website.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{config}
#     The configuration. A refererence to a hash generated by
#     Config.pm
#
#  $self->{class}
#     The package to which the config functions belong.
#
#  $self->{id}
#     The id of this repository.
#
#  $self->{ruler}
#     An XHTML tree describing the horizontal ruler for this repository
#     website.
#
#  $self->{langs}
#     A hash containing EPrints::Language objects for this repository,
#     keyed by iso lang id.
#
#  $self->{cstyles}
#     A cache of all the DOM blocks describing citation styles. Key is 
#     a lang id. Value is another hash where key is citation type and
#     value is the actual DOM tree.
#
#  $self->{html_templates}
#     A cache of the webpage templates for this site. A hash keyed by
#     lang id.
#
#  $self->{text_templates}
#     A cache of the webpage templates for this site stored as strings
#     and pin id's.
#
#  $self->{datasets}
#     A cache of all the EPrints::DataSets belonging to this repository
#     keyed by dataset id.
#
#  $self->{field_defaults}
#     Cached hashes of the default parameters for each field type
#     eg Int, Text etc. (just to save having loads of identical 
#     structures in memory)
#
######################################################################

package EPrints::Repository;

use EPrints;

use File::Copy;

use strict;

my %ARCHIVE_CACHE = ();



######################################################################
=pod

=item $repository = EPrints::Repository->new( $id, [$noxml] )

Returns the repository with the given repository ID. If $noxml is specified
then it skips loading the XML based configuration files (this is
needed when creating an repository as it first has to create the DTD
files, and if it can't start you have a catch 22 situtation).

=cut
######################################################################
sub new_archive_by_id { my $class= shift; return $class->new( @_ ); }

sub new
{
	my( $class, $id, $noxml ) = @_;

	if( !defined $id )
	{
		print STDERR "No Archive ID specified.\n\n";
		return;
	}
	if( $id !~ m/^[a-zA-Z0-9_]+$/ )
	{
		print STDERR "Archive ID illegal: $id\n\n";
		return;
	}
	
	if( defined $ARCHIVE_CACHE{$id} )
	{
		my $self = $ARCHIVE_CACHE{$id};
		my $file = $self->get_conf( "variables_path" )."/last_changed.timestamp";
		my $poketime = (stat( $file ))[9];
		# If the /cfg/.changed file was touched since the config
		# for this repository was loaded then we will reload it.
		# This is not as handy as it sounds as we'll have to reload
		# it each time the main server forks.
		if( defined $poketime && $poketime > $self->{loadtime} )
		{
			$self->log( "$file has been modified since the repository config was loaded: reloading!" );
		}
		else
		{
			return $self;
		}
	}
	
	#print STDERR "Loading: $id\n";

	my $self = {};
	bless $self, $class;

	$self->{config} = EPrints::Config::load_repository_config_module( $id );

	$self->{loadtime} = time;

	return unless( defined $self->{config} );

	$self->{class} = "EPrints::Config::$id";

	$self->{id} = $id;
	$self->{xmldoc} = EPrints::XML::make_document();

	# If loading any of the XML config files then 
	# abort loading the config for this repository.
	unless( $noxml )
	{
		$self->generate_dtd() || return;
		$self->get_ruler() || return;
		$self->_load_workflows() || return;
		$self->_load_datasets() || return;
		$self->_load_languages() || return;
		$self->_load_templates() || return;
		$self->_load_citation_specs() || return;
	}

	# Load repository plugins
	$self->_load_plugins() || return;
	
	# Map OAI plugins to functions, namespaces etc.
	$self->_map_oai_plugins() || return;

	$self->{field_defaults} = {};

	# The var directory was added in version 2.3, create it
	# if it does not already exist
	# and tidy up some stuff from cfg which has moved into
	# var
	
	my $var_dir = $self->get_conf( "variables_path" );
	if( !-d $var_dir )
	{
                mkdir( $var_dir, 0755 );
		my $cfg_dir = $self->get_conf( "config_path" );
		foreach( "daily", "weekly", "monthly", ".changed" )
		{
			my $file = $cfg_dir."/".$_;
			unlink( $file ) if( -e $file );
		}
	}
		


	$ARCHIVE_CACHE{$id} = $self;
	return $self;
}

######################################################################
=pod

=item $repository = EPrints::Repository->new_from_request( $request )

This creates a new repository object. It looks at the given Apache
request object and decides which repository to load based on the 
value of the PerlVar "EPrints_ArchiveID".

Aborts with an error if this is not possible.

=cut
######################################################################

sub new_from_request
{
	my( $class, $request ) = @_;
		
	my $repoid = $request->dir_config( "EPrints_ArchiveID" );

	my $repository = EPrints::Repository->new( $repoid );

	if( !defined $repository )
	{
		EPrints::Config::abort( "Can't load EPrints repository: $repoid" );
	}

	return $repository;
}


######################################################################
=pod

=item $xhtml = $repository->get_ruler

Returns the ruler as specified in ruler.xml - it caches the result
so the XML file only has to be loaded once.

=cut
######################################################################

sub get_ruler
{
	my( $self ) = @_;

	if( defined $self->{ruler} )
	{
		return $self->{ruler};
	}

	my $file = $self->get_conf( "config_path" )."/ruler.xml";
	
	my $doc = $self->parse_xml( $file );
	if( !defined $doc )
	{
		$self->log( "Error loading: $file\n" );
		return undef;
	}
	my $ruler = ($doc->getElementsByTagName( "ruler" ))[0];
	return undef if( !defined $ruler );

	$self->{ruler} = $self->{xmldoc}->createDocumentFragment();
	foreach( $ruler->getChildNodes )
	{
		$self->{ruler}->appendChild( 
			EPrints::XML::clone_and_own( $_, $self->{xmldoc} ) );
	}
	EPrints::XML::dispose( $doc );

	return $self->{ruler};
}	
 
######################################################################
#=pod
#
#=item $success = $repository->_load_workflows
#
# Attempts to load and cache the workflows for this repository
#
#=cut
######################################################################

sub _load_workflows
{
	my( $self ) = @_;

	$self->{workflows} = EPrints::Workflow::load_all( $self->get_conf( "config_path" )."/workflows" );

	if( !defined $self->{workflows} )
	{
		return 0;
	}
	return 1;
}

	
######################################################################
# 
# $workflow_xml = $repository->get_workflow_config( $datasetid, $workflowid )
#
# Return the XML of the requested workflow
#
######################################################################

sub get_workflow_config
{
	my( $self, $datasetid, $workflowid ) = @_;

	my $r = $self->{workflows}->{$datasetid}->{$workflowid};

	return $r;
}

######################################################################
# 
# $success = $repository->_load_languages
#
# Attempts to load and cache all the phrase files for this repository.
#
######################################################################

sub _load_languages
{
	my( $self ) = @_;
	
	my $defaultid = $self->get_conf( "defaultlanguage" );
	$self->{langs}->{$defaultid} = EPrints::Language->new( 
		$defaultid, 
		$self );

	if( !defined $self->{langs}->{$defaultid} )
	{
		return 0;
	}

	my $langid;
	foreach $langid ( @{$self->get_conf( "languages" )} )
	{
		next if( $langid eq $defaultid );	
		$self->{langs}->{$langid} =
			 EPrints::Language->new( 
				$langid , 
				$self , 
				$self->{langs}->{$defaultid} );
		if( !defined $self->{langs}->{$langid} )
		{
			return 0;
		}
	}
	return 1;
}


######################################################################
=pod

=item $language = $repository->get_language( [$langid] )

Returns the EPrints::Language for the requested language id (or the
default for this repository if $langid is not specified). 

=cut
######################################################################

sub get_language
{
	my( $self , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = $self->get_conf( "defaultlanguage" );
	}
	return $self->{langs}->{$langid};
}

######################################################################
# 
# $success = $repository->_load_citation_specs
#
# Attempts to load and cache all the citation styles for this repository.
#
######################################################################

sub _load_citation_specs
{
	my( $self ) = @_;

	my $langid;
	foreach $langid ( @{$self->get_conf( "languages" )} )
	{
		my $dir = $self->get_conf( "config_path" ).
				"/$langid/citations";
		my $dh;
		opendir( $dh, $dir );
		my @dirs = ();
		while( my $fn = readdir( $dh ) )
		{
			next if $fn =~ m/^\./;
			push @dirs,$fn if( -d "$dir/$fn" );
		}
		close $dh;

		$self->{cstyles}->{$langid} = {};
		# for each dataset dir
		foreach my $dsid ( @dirs )
		{
			opendir( $dh, "$dir/$dsid" );
			my @files = ();
			while( my $fn = readdir( $dh ) )
			{
				next if $fn =~ m/^\./;
				next unless $fn =~ s/\.xml$//;
				push @files,$fn;
			}
			close $dh;
			$self->{cstyles}->{$langid}->{$dsid} = {};
			foreach my $file ( @files )
			{
				$self->{cstyles}->{$langid}->{$dsid}->{$file} = 
					$self->_parse_citation_file( "$dir/$dsid/$file.xml" );
			}
		}
	}
	return 1;
}

sub _parse_citation_file
{
	my( $self, $file ) = @_;

	my $doc = $self->parse_xml( $file , 1 );
	if( !defined $doc )
	{
		$self->log( "Error parsing $file\n" );
		return undef;
	}

	my $citation = ($doc->getElementsByTagName( "citation" ))[0];
	if( !defined $citation )
	{
		$self->log(  "Missing <citations> tag in $file\n" );
		EPrints::XML::dispose( $doc );
		return undef;
	}

	# is this cloning really needed?
	my( $frag ) = $self->{xmldoc}->createDocumentFragment();
	foreach( $citation->getChildNodes )
	{
		$frag->appendChild( 
			EPrints::XML::clone_and_own(
				$_,
				$self->{xmldoc},
				1 ) );
	}

	EPrints::XML::dispose( $doc );

	return $frag;
}

######################################################################
# =pod
# 
# =item $citation = $repository->get_citation_spec( $langid, $type, [$style] )
# 
# Returns the DOM citation style for the given language and type. This
# is the origional and should be cloned before you alter it.
# 
# If $style is specified then returns a certain style if available, 
# otherwise the default.
# 
# =cut
######################################################################

sub get_citation_spec
{
	my( $self, $langid, $type, $style  ) = @_;

	$style = "default" unless defined $style;

	my $spec = $self->{cstyles}->{$langid}->{$type}->{$style};
	if( !defined $spec )
	{
		$spec = $self->{cstyles}->{$langid}->{$type}->{default};
	}
	
	return $spec;
}

######################################################################
# 
# $success = $repository->_load_templates
#
# Loads and caches all the html template files for this repository.
#
######################################################################

sub _load_templates
{
	my( $self ) = @_;

	foreach my $langid ( @{$self->get_conf( "languages" )} )
	{
		my $dir = $self->get_conf( "config_path" )."/$langid/templates";
		my $dh;
		opendir( $dh, $dir );
		my @template_files = ();
		while( my $fn = readdir( $dh ) )
		{
			next if $fn=~m/^\./;
			push @template_files, $fn if $fn=~m/\.xml$/;
		}
		closedir( $dh );

		foreach my $fn ( @template_files )
		{
			my $file = $self->get_conf( "config_path" ).
				"/$langid/templates/$fn";
			my $id = $fn;
			$id=~s/\.xml$//;

			my $template = $self->_load_template( $file );
			if( !defined $template ) { return 0; }

			$self->{html_templates}->{$id}->{$langid} = $template;
			$self->{text_templates}->{$id}->{$langid} = _template_to_text( $template );
		}

		if( !defined $self->{html_templates}->{default}->{$langid} )
		{
			EPrints::abort( "Failed to load default template for language $langid" );
		}
	}
	return 1;
}

sub _template_to_text
{
	my( $template ) = @_;

	my $doc = $template->getOwnerDocument;
	my @r = ( "fnord" );	

	$template = EPrints::XML::clone_and_own( 
			$template,
			$doc,
			1 );

	my $divide = "61fbfe1a470b4799264feccbbeb7a5ef";
        my @pins = $template->getElementsByTagName("pin");
	foreach my $pin ( @pins )
	{
		#$template
		my $parent = $pin->getParentNode;
		my $textonly = $pin->getAttribute( "textonly" );
		my $ref = $pin->getAttribute( "ref" );
		if( defined $textonly && $textonly eq "yes" )
		{
			$ref.=":textonly";
		}
		my $textnode = $doc->createTextNode( $divide.$ref.$divide );
		$parent->replaceChild( $textnode, $pin );
	}
	@r = split( "$divide", $template->toString );

	return \@r;
}

sub _load_template
{
	my( $self, $file ) = @_;
	my $doc = $self->parse_xml( $file );
	if( !defined $doc ) { return undef; }
	my $html = ($doc->getElementsByTagName( "html" ))[0];
	my $rvalue;
	if( !defined $html )
	{
		print STDERR "Missing <html> tag in $file\n";
	}
	else
	{
		$rvalue = EPrints::XML::clone_and_own( 
			$html,
			$self->{xmldoc},
			1 );
	}
	EPrints::XML::dispose( $doc );
	return $rvalue;
}


######################################################################
=pod

=item $template = $repository->get_template_parts( $langid, [$template_id] )

Returns an array of utf-8 strings alternating between XML and the id
of a pin to replace. This is used for the faster template construction.

=cut
######################################################################

sub get_template_parts
{
	my( $self, $langid, $tempid ) = @_;
  
	if( !defined $tempid ) { $tempid = 'default'; }
	my $t = $self->{text_templates}->{$tempid}->{$langid};
	if( !defined $t ) 
	{
		EPrints::Config::abort( <<END );
Error. Template not loaded.
Language: $langid
Template ID: $tempid
END
	}

	return $t;
}
######################################################################
=pod

=item $template = $repository->get_template( $langid, [$template_id] )

Returns the DOM document which is the webpage template for the given
language. Do not modify the template without cloning it first.

=cut
######################################################################

sub get_template
{
	my( $self, $langid, $tempid ) = @_;
  
	if( !defined $tempid ) { $tempid = 'default'; }
	my $t = $self->{html_templates}->{$tempid}->{$langid};
	if( !defined $t ) 
	{
		EPrints::Config::abort( <<END );
Error. Template not loaded.
Language: $langid
Template ID: $tempid
END
	}

	return $t;
}

######################################################################
# 
# $success = $repository->_load_datasets
#
# Loads and caches all the EPrints::DataSet objects belonging to this
# repository. Loads information from metadata-types.xml to pass to the
# DataSet constructor about what types are available.
#
######################################################################

sub _load_datasets
{
	my( $self ) = @_;


	# read config data from metadata-types.xml

	my $file = $self->get_conf( "config_path" ).
			"/metadata-types.xml";
	my $doc = $self->parse_xml( $file );
	if( !defined $doc )
	{
		return 0;
	}

	my $types_tag = ($doc->getElementsByTagName( "metadatatypes" ))[0];
	if( !defined $types_tag )
	{
		EPrints::XML::dispose( $doc );
		print STDERR "Missing <metadatatypes> tag in $file\n";
		return 0;
	}

	my $dsconf = {};
	my $ds_tag;	
	foreach $ds_tag ( $types_tag->getElementsByTagName( "dataset" ) )
	{
		my $ds_id = $ds_tag->getAttribute( "name" );
		my $type_tag;
		$dsconf->{$ds_id} = [];
		foreach $type_tag ( $ds_tag->getElementsByTagName( "type" ) )
		{
			my $type_id = $type_tag->getAttribute( "name" );
			push @{$dsconf->{$ds_id}}, $type_id;
		}
	}

	# read config data from workflow (if there is one).

	$self->{datasets} = {};
	foreach my $ds_id ( EPrints::DataSet::get_dataset_ids() )
	{
		$self->{datasets}->{$ds_id} = EPrints::DataSet->new( $self, $ds_id, $dsconf );
	}

	EPrints::XML::dispose( $doc );
	return 1;
}


######################################################################
=pod

=item $dataset = $repository->get_dataset( $setname )

Returns the cached EPrints::DataSet with the given dataset id name.

=cut
######################################################################

sub get_dataset
{
	my( $self , $setname ) = @_;

	my $ds = $self->{datasets}->{$setname};
	if( !defined $ds )
	{
		$self->log( "Unknown dataset: ".$setname );
	}

	return $ds;
}

######################################################################
# 
# $success = $repository->_map_oai_plugins
#
# The OAI interface now uses plugins. This checks each OAI plugin and
# stores its namespace, and a function to render with it.
#
######################################################################

sub _map_oai_plugins
{
	my( $self ) = @_;
	
	my $plugin_list = $self->{config}->{oai}->{v2}->{output_plugins};
	
	return( 1 ) unless( defined $plugin_list );

	foreach my $plugin_id ( keys %{$plugin_list} )
	{
		my $full_plugin_id = "Export::".$plugin_list->{$plugin_id};
		my $class = $self->plugin_class( $full_plugin_id );
		if( !defined $class )
		{
			$self->log( "OAI Export plugin: $plugin_id not found." );
			next;
		}
		my $plugin = $class->new();
		$self->{config}->{oai}->{v2}->{metadata_namespaces}->{$plugin_id} = $plugin->{xmlns};
		$self->{config}->{oai}->{v2}->{metadata_schemas}->{$plugin_id} = $plugin->{schemaLocation};
		$self->{config}->{oai}->{v2}->{metadata_functions}->{$plugin_id} = sub {
			my( $eprint, $session ) = @_;

			my $plugin = $session->plugin( $full_plugin_id );
			my $xml = $plugin->xml_dataobj( $eprint );
			return $xml;
		};
	}

	return 1;
}


######################################################################
# 
# $success = $repository->_load_plugins
#
# Loads and caches all the plugins for this repository by loading 
# everything in the plugins directory.
#
######################################################################

sub _load_plugins
{
	my( $self ) = @_;

	my $src = $self->get_conf( "config_path" )."/Plugin";

	$self->{plugins} = { %{$EPrints::Plugin::REGISTRY} };

	if( !-e $src )
	{
		$self->log( "No plugins loaded. $src does not exist." );
		return 1; # just a warning
	}

	my $tgt = $EPrints::SystemSettings::conf->{base_path}."/perl_lib/EPrints/LocalPlugin/".$self->{id};

	$self->_plugin_dir_copy( $src, $tgt );

	EPrints::Plugin::load_dir( $self->{plugins}, $tgt, "EPrints::LocalPlugin::".$self->{id} );

	return 1;
}

######################################################################
=pod

=item $repository->_plugin_dir_copy( $source, $target )

Ensure that all the repository plugins are copied into the perl path.

=cut
######################################################################

sub _plugin_dir_copy
{
	my( $self, $source, $target ) = @_;

	unless( -e $source )
	{
		EPrints::Config::abort( "$source does not exist" );
	}

	unless( -e $target )
	{
		mkdir( $target, 0711 ) || EPrints::Config::abort( "can't make dir $target: $!" );
	}

	if( -e $target && !-d $target )
	{
		EPrints::Config::abort( "$target is not a directory" );
	}

	my $tfiles = {};
	my $dh;
	opendir( $dh, $target ) ||  EPrints::Config::abort( "can't read directory $target" );
	while( my $file = readdir( $dh ) ) { $tfiles->{$file} = 1; }
	closedir( $dh );
	
	my $baseclass = "EPrints::LocalPlugin::".$self->{id};

	opendir( $dh, $source ) ||  EPrints::Config::abort( "can't read directory $source" );
	while( my $file = readdir( $dh ) )
	{
		delete $tfiles->{$file} if( defined $tfiles->{$file} );
		next if( $file =~ m/^\./ );
		next if( $file eq "CVS" );
		next if( $file eq ".svn" );
		if( -d "$source/$file" )
		{
			$self->_plugin_dir_copy( "$source/$file", "$target/$file" );
			next;
		}
		my $from = "$source/$file";
		my $to = "$target/$file";
		open( FROM, $from ) ||  EPrints::Config::abort( "can't read file $from: $!" );
		open( TO, ">$to" ) ||  EPrints::Config::abort( "can't write file $to: $!" );
		print TO <<END;
#
#  DO NOT EDIT THIS FILE
# 
#  This file has been generated from:
#  $from
#
#  Modify that file instead!
#


END

		while( <FROM> )
		{
			s/__PLUGIN__/$baseclass/g;
			print TO $_;
		}
		close TO;
		close FROM;
	}
	closedir( $dh );

	foreach my $doomed_file ( keys %{$tfiles} )
	{
		my $fp = "$target/$doomed_file";
		if( -d $fp ) 
		{
			rmdir( $fp ) || EPrints::Config::abort( "Can't remove dir: $fp" );
		}
		else
		{
			unlink( $fp ) || EPrints::Config::abort( "Can't remove file: $fp" );
		}
	}
}


######################################################################
=pod

=item @plugin_ids  = $repository->plugin_list()

Return a list of all the ids of the repository specific plugins.

=cut
######################################################################

sub plugin_list
{
	my( $self ) = @_;

	return keys %{$self->{plugins}};
}


######################################################################
=pod

=item $class  = $repository->plugin_class( $pluginid )

Return the Perl class of the given $pluginid as a string.

=cut
######################################################################

sub plugin_class
{
	my( $self , $pluginid ) = @_;

	return $self->{plugins}->{$pluginid};
}




######################################################################
=pod

=item $confitem = $repository->get_conf( $key, [@subkeys] )

Returns a named configuration setting. Probably set in ArchiveConfig.pm

$repository->get_conf( "stuff", "en", "foo" )

is equivalent to 

$repository->get_conf( "stuff" )->{en}->{foo} 

=cut
######################################################################

sub get_conf
{
	my( $self, $key, @subkeys ) = @_;

	my $val = $self->{config}->{$key};
	foreach( @subkeys )
	{
		return undef unless defined $val;
		$val = $val->{$_};
	} 


	# handle defaults
	if( !defined $val )
	{
		if( $key eq "variables_path" )
		{
			$val = $self->get_conf( 'archiveroot' )."/var";
		}

	}

	return $val;
}


######################################################################
=pod

=item $repository->log( $msg )

Calls the log method from ArchiveConfig.pm for this repository with the 
given parameters. Basically logs the comments wherever the site admin
wants them to go. Printed to STDERR by default.

=cut
######################################################################

sub log
{
	my( $self , $msg) = @_;

	if( $self->get_conf( 'show_ids_in_log' ) )
	{
		my @m2 = ();
		foreach my $line ( split( '\n', $msg ) )
		{
			push @m2,"[".$self->{id}."] ".$line;
		}
		$msg = join("\n",@m2);
	}

	$self->call( 'log', $self, $msg );
}


######################################################################
=pod

=item $result = $repository->call( $cmd, @params )

Calls the subroutine named $cmd from the configuration perl modules
for this repository with the given params and returns the result.

=cut
######################################################################

sub call
{
	my( $self, $cmd, @params ) = @_;

	my $fn = \&{$self->{class}."::".$cmd};
	return &$fn( @params );
}

######################################################################
=pod

=item $boolean = $repository->can_call( $cmd )

Return true if the given subroutine exists in this repository's config
package.

=cut
######################################################################

sub can_call($$)
{
	my( $self, $cmd ) = @_;

	# We're going to be turning strings into references
	no strict 'refs';

	my %namespace = %{$self->{class}."::"};

	# Is there anything in the namespace called $cmd?
	return( 0 ) unless( defined $namespace{$cmd} );

	# is it a code reference?
	return( 0 ) unless( defined *{$namespace{$cmd}}{CODE} );

	return 1;
}

######################################################################
=pod

=item $result = $repository->try_call( $cmd, @params )

Calls the subroutine named $cmd from the configuration perl modules
for this repository with the given params and returns the result.

If the subroutine does not exist then quietly returns undef.

This is used to call deprecated callback subroutines.

=cut
######################################################################

sub try_call
{
	my( $self, $cmd, @params ) = @_;

	return unless $self->can_call( $cmd );

	return $self->call( $cmd, @params );
}

######################################################################
=pod

=item @dirs = $repository->get_store_dirs

Returns a list of directories available for storing documents. These
may well be symlinks to other hard drives.

=cut
######################################################################

sub get_store_dirs
{
	my( $self ) = @_;

	my $docroot = $self->get_conf( "documents_path" );

	opendir( DOCSTORE, $docroot ) || return undef;

	my( @dirs, $dir );
	while( $dir = readdir( DOCSTORE ) )
	{
		next if( $dir =~ m/^\./ );
		next unless( -d $docroot."/".$dir );
		push @dirs, $dir;	
	}

	closedir( DOCSTORE );

	return @dirs;
}


######################################################################
=pod

=item $size = $repository->get_store_dir_size( $dir )

Returns the current storage (in bytes) used by a given documents dir.
$dir should be one of the values returned by $repository->get_store_dirs.

This should not be called if disable_df is set in SystemSettings.

=cut
######################################################################

sub get_store_dir_size
{
	my( $self , $dir ) = @_;

	my $filepath = $self->get_conf( "documents_path" )."/".$dir;

	if( ! -d $filepath )
	{
		return undef;
	}

	my @retval = EPrints::Utils::df_dir $filepath;
	return undef unless @retval;
	return (@retval)[3];
} 




######################################################################
=pod

=item $domdocument = $repository->parse_xml( $file, $no_expand );

Turns the given $file into a XML DOM/GDOME document. If $no_expand
is true then load &entities; but do not expand them to the values in
the DTD.

This function also sets the path in which the Parser will look for 
DTD files to the repository's config directory.

=cut
######################################################################

sub parse_xml
{
	my( $self, $file, $no_expand ) = @_;

	my $doc = EPrints::XML::parse_xml( 
		$file, 
		$self->get_conf( "variables_path" )."/",
		$no_expand );
	if( !defined $doc )
	{
		$self->log( "Failed to parse XML file: $file" );
	}
	return $doc;
}


######################################################################
=pod

=item $id = $repository->get_id 

Returns the id string of this repository.

=cut
######################################################################

sub get_id 
{
	my( $self ) = @_;

	return $self->{id};
}


######################################################################
=pod

=item $returncode = $repository->exec( $cmd_id, %map )

Executes a system command. $cmd_id is the id of the command as
set in SystemSettings and %map contains a list of things to "fill in
the blanks" in the invocation line in SystemSettings. 

=cut
######################################################################

sub exec
{
	my( $self, $cmd_id, %map ) = @_;

	my $command = $self->invocation( $cmd_id, %map );

	$self->log( "Executing command: $command" );	

	my $rc = 0xffff & system $command;

	return $rc;
}	


######################################################################
=pod

=item $commandstring = $repository->invocation( $cmd_id, %map )

Finds the invocation for the specified command from SystemSetting and
fills in the blanks using %map. Returns a string which may be executed
as a system call.

=cut
######################################################################

sub invocation
{
	my( $self, $cmd_id, %map ) = @_;

	my $execs = $self->get_conf( "executables" );
	foreach( keys %{$execs} )
	{
		$map{$_} = $execs->{$_};
	}

	my $command = $self->get_conf( "invocation" )->{ $cmd_id };

	$command =~ s/\$\(([a-z]*)\)/$map{$1}/gei;

	return $command;
}

######################################################################
=pod

=item $defaults = $repository->get_field_defaults( $fieldtype )

Return the cached default properties for this metadata field type.
or undef.

=cut
######################################################################

sub get_field_defaults
{
	my( $self, $fieldtype ) = @_;

	return $self->{field_defaults}->{$fieldtype};
}

######################################################################
=pod

=item $repository->set_field_defaults( $fieldtype, $defaults )

Cache the default properties for this metadata field type.

=cut
######################################################################

sub set_field_defaults
{
	my( $self, $fieldtype, $defaults ) = @_;

	$self->{field_defaults}->{$fieldtype} = $defaults;
}



######################################################################
=pod

=item $success = $repository->generate_dtd

Regenerate the DTD file for each language. This file is used when
loading some of the XML files. It contains entities such as &ruler;
and &adminemail; which make maintaining the XML files easier.

The entites in the DTD file are configured by get_entities in the
ArchiveConfig.pm module.

Returns true. Might return false on error (not checking yet).

=cut
######################################################################

sub generate_dtd
{
	my( $self ) = @_;

	my $dtdfile = $self->get_conf( "lib_path")."/xhtml-entities.dtd";
	open( XHTMLENTITIES, $dtdfile ) ||
		die "Failed to open system DTD ($dtdfile) to include ".
			"in repository DTD";
	my $xhtmlentities = join( "", <XHTMLENTITIES> );
	close XHTMLENTITIES;
	my $langid;
	foreach $langid ( @{$self->get_conf( "languages" )} )
	{	
		my %entities = $self->call( "get_entities", $self, $langid );
		my $file = $self->get_conf( "variables_path" )."/entities-$langid.dtd";
		my $tmpfile = $file.".".$$;
		open( DTD, ">$tmpfile" ) || die "Failed to open $tmpfile for writing";

		my $siteid = $self->{id};
	
		print DTD <<END;
<!-- 
	Entities file for $siteid, language ID "$langid"

	*** DO NOT EDIT, This is auto-generated ***
-->

END
		foreach( keys %entities )
		{
			my $value = $entities{$_};
			$value=~s/&/&#x26;/g;
			$value=~s/"/&#x22;/g;
			$value=~s/%/&#x25;/g;
			print DTD "<!ENTITY $_ \"$value\" >\n";
		}
		print DTD <<END;

<!--
	Generic XHTML entities 
-->

END
		print DTD $xhtmlentities;
		close DTD;
		move( $tmpfile, $file );
	}

	return 1;
}


1;

######################################################################
=pod

=back

=cut
######################################################################

