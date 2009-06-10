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
#     the perl config files
#
#  $self->{class}
#     The package to which the config functions belong.
#
#  $self->{id}
#     The id of this repository.
#
#  $self->{langs}
#     A hash containing EPrints::Language objects for this repository,
#     keyed by iso lang id.
#
#  $self->{citation_style}
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
use EPrints::XML::EPC;

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
			print STDERR "$file has been modified since the repository config was loaded: reloading!\n";
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

	unless( defined $self->{config} )
	{
		print STDERR "Could not load repository config perl files for $id\n";
		return;
	}


	$self->{class} = "EPrints::Config::$id";

	$self->{id} = $id;
	$self->{xmldoc} = EPrints::XML::make_document();

	$self->_add_http_paths;

	# If loading any of the XML config files then 
	# abort loading the config for this repository.
	unless( $noxml )
	{
		# $self->generate_dtd() || return;
		$self->_load_storage() || return;
		$self->_load_workflows() || return;
		$self->_load_namedsets() || return;
		$self->_load_datasets() || return;
		$self->_load_languages() || return;
		$self->_load_templates() || return;
		$self->_load_citation_specs() || return;
	}

	$self->_load_plugins() || return;

	# Map OAI plugins to functions, namespaces etc.
	$self->_map_oai_plugins() || return;

	$self->{field_defaults} = {};

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
		EPrints::abort( "Can't load EPrints repository: $repoid" );
	}
	$repository->check_secure_dirs( $request );

	return $repository;
}

######################################################################
#
# $repository->check_secure_dirs( $request );
#
# This method triggers an abort if the secure dirs specified in 
# the apache conf don't match those EPrints is using. This prevents
# the risk of a security breach after moving directories.
#
######################################################################

sub check_secure_dirs
{
	my( $self, $request ) = @_;

	my $real_secured_cgi = EPrints::Config::get( "cgi_path" )."/users";
	my $real_documents_path = $self->get_conf( "documents_path" );

	my $apacheconf_secured_cgi = $request->dir_config( "EPrints_Dir_SecuredCGI" );
	my $apacheconf_documents_path = $request->dir_config( "EPrints_Dir_Documents" );

	if( $real_secured_cgi ne $apacheconf_secured_cgi )
	{
		EPrints::abort( <<END );
Document path is: $real_secured_cgi 
but apache conf is securiing: $apacheconf_secured_cgi
You probably need to run generate_apacheconf!
END
	}
	if( $real_documents_path ne $apacheconf_documents_path )
	{
		EPrints::abort( <<END );
Document path is: $real_documents_path 
but apache conf is securiing: $apacheconf_documents_path
You probably need to run generate_apacheconf!
END
	}
}

sub _add_http_paths
{
	my( $self ) = @_;

	my $config = $self->{config};

	# Backwards-compatibility: http is fairly simple, https may go wrong
	if( !defined($config->{"http_root"}) )
	{
		my $u = URI->new( $config->{"base_url"} );
		$config->{"http_root"} = $u->path;
		$u = URI->new( $config->{"perl_url"} );
		$config->{"http_cgiroot"} = $u->path;
		if( $config->{"securehost"} )
		{
			$config->{"secureport"} ||= 443;
			$config->{"https_root"} = $config->{"securepath"}
				if !defined($config->{"https_root"});
			$config->{"https_cgiroot"} = $config->{"https_root"} . $config->{"http_cgiroot"}
				if !defined($config->{"https_cgiroot"});
		}
	}

}
 
sub _load_storage
{
	my( $self ) = @_;

	$self->{storage} = {};

	EPrints::Storage::load_all( 
		$self->get_conf( "lib_path" )."/storage",
		$self->{storage} );

	EPrints::Storage::load_all( 
		$self->get_conf( "config_path" )."/storage",
		$self->{storage} );

	return 1;
}

sub get_storage_config
{
	my( $self, $storageid ) = @_;

	my $r = EPrints::Storage::get_storage_config( 
		$storageid,
		$self->{storage} );

	return $r;
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

	$self->{workflows} = {};

	EPrints::Workflow::load_all( 
		$self->get_conf( "config_path" )."/workflows",
		$self->{workflows} );

	# load any remaining workflows from the generic level.
	# eg. saved searches
	EPrints::Workflow::load_all( 
		$self->get_conf( "lib_path" )."/workflows",
		$self->{workflows} );

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

	my $r = EPrints::Workflow::get_workflow_config( 
		$workflowid,
		$self->{workflows}->{$datasetid} );

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

	$self->{citation_style} = {};
	$self->{citation_type} = {};
	$self->_load_citation_dir( $self->get_conf( "config_path" )."/citations" );
	$self->_load_citation_dir( $self->get_conf( "lib_path" )."/citations" );
}

sub _load_citation_dir
{
	my( $self, $dir ) = @_;

	my $dh;
	opendir( $dh, $dir );
	my @dirs = ();
	while( my $fn = readdir( $dh ) )
	{
		next if $fn =~ m/^\./;
		push @dirs,$fn if( -d "$dir/$fn" );
	}
	close $dh;

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
		if( !defined $self->{citation_style}->{$dsid} )
		{
			$self->{citation_style}->{$dsid} = {};
		}
		if( !defined $self->{citation_type}->{$dsid} )
		{
			$self->{citation_type}->{$dsid} = {};
		}
		foreach my $file ( @files )
		{
			$self->_load_citation_file( 
				"$dir/$dsid/$file.xml",
				$dsid,
				$file,
			);
		}
	}

	return 1;
}

sub _load_citation_file
{
	my( $self, $file, $dsid, $fileid ) = @_;

	if( !-e $file )
	{
		if( $fileid eq "default" )
		{
			EPrints::abort( "Default citation file for '$dsid' does not exist." );
		}
		$self->log( "Citation file '$fileid' for '$dsid' does not exist." );
		return;
	}

	my $doc = $self->parse_xml( $file , 1 );
	if( !defined $doc )
	{
		$self->log( "Error parsing $file\n" );
		return;
	}

	my $citation = ($doc->getElementsByTagName( "citation" ))[0];
	if( !defined $citation )
	{
		$self->log(  "Missing <citations> tag in $file\n" );
		EPrints::XML::dispose( $doc );
		return;
	}
	my $type = $citation->getAttribute( "type" );
	$type = "default" unless defined $type;
	$self->{citation_type}->{$dsid}->{$fileid} = $type;

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

	$self->{citation_style}->{$dsid}->{$fileid} = $frag;

	$self->{citation_sourcefile}->{$dsid}->{$fileid} = $file;
	$self->{citation_mtime}->{$dsid}->{$fileid} = EPrints::Utils::mtime( $file );

}

sub freshen_citation
{
	my( $self, $dsid, $fileid ) = @_;

	# this only really needs to be done once per file per session, but we
	# don't have a handle on the current session

	my $file = $self->{citation_sourcefile}->{$dsid}->{$fileid};
	my $mtime = EPrints::Utils::mtime( $file );

	my $old_mtime = $self->{citation_mtime}->{$dsid}->{$fileid};
	if( defined $old_mtime && $old_mtime == $mtime )
	{
		return;
	}

	$self->_load_citation_file( $file, $dsid, $fileid );
}

######################################################################
# =pod
# 
# =item $citation = $repository->get_citation_spec( $dsid, [$style] )
# 
# Returns the DOM citation style for the given type of object. This
# is the origional and should be cloned before you alter it.
# 
# If $style is specified then returns a certain style if available, 
# otherwise the default.
#
# dsid = user,eprint etc.
# 
# =cut
######################################################################

sub get_citation_spec
{
	my( $self, $dsid, $style  ) = @_;

	$style = "default" unless defined $style;

	my $spec = $self->{citation_style}->{$dsid}->{$style};
	if( !defined $spec )
	{
		$self->log( "Could not find citation style $dsid.$style. Using default instead." );
		$style = "default";
		$spec = $self->{citation_style}->{$dsid}->{$style};
	}
	
	$self->freshen_citation( $dsid, $style );

	return $spec;
}

sub get_citation_type
{
	my( $self, $dsid, $style  ) = @_;

	$style = "default" unless defined $style;

	my $type = $self->{citation_type}->{$dsid}->{$style};
	if( !defined $type )
	{
		$style = "default";
		$type = $self->{citation_type}->{$dsid}->{$style};
	}
	
	$self->freshen_citation( $dsid, $style );

	return $type;
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
		my $dir = $self->get_conf( "config_path" )."/lang/$langid/templates";
		my $dh;
		opendir( $dh, $dir );
		my @template_files = ();
		while( my $fn = readdir( $dh ) )
		{
			next if $fn=~m/^\./;
			push @template_files, $fn if $fn=~m/\.xml$/;
		}
		closedir( $dh );

		#my $tmp_session = EPrints::Session->new( 1, $self->{id} );
		#$tmp_session->terminate;

		foreach my $fn ( @template_files )
		{
			my $id = $fn;
			$id=~s/\.xml$//;
			$self->freshen_template( $langid, $id );
		}

		if( !defined $self->{html_templates}->{default}->{$langid} )
		{
			EPrints::abort( "Failed to load default template for language $langid" );
		}
	}
	return 1;
}

sub freshen_template
{
	my( $self, $langid, $id ) = @_;

	my $file = $self->get_conf( "config_path" ).
			"/lang/$langid/templates/$id.xml";
	my @filestat = stat( $file );
	my $mtime = $filestat[9];

	my $old_mtime = $self->{template_mtime}->{$id}->{$langid};
	if( defined $old_mtime && $old_mtime == $mtime )
	{
		return;
	}

	my $template = $self->_load_template( $file );
	if( !defined $template ) { return 0; }

	$self->{html_templates}->{$id}->{$langid} = $template;
	$self->{text_templates}->{$id}->{$langid} = _template_to_text( $template );
	$self->{template_mtime}->{$id}->{$langid} = $mtime;
}

sub _template_to_text
{
	my( $template ) = @_;

	my $doc = $template->ownerDocument;

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
		my $ref = "pin:".$pin->getAttribute( "ref" );
		if( defined $textonly && $textonly eq "yes" )
		{
			$ref.=":textonly";
		}
		my $textnode = $doc->createTextNode( $divide.$ref.$divide );
		$parent->replaceChild( $textnode, $pin );
	}

        my @prints = $template->getElementsByTagName("print");
	foreach my $print ( @prints )
	{
		my $parent = $print->getParentNode;
		my $ref = "print:".$print->getAttribute( "expr" );
		my $textnode = $doc->createTextNode( $divide.$ref.$divide );
		$parent->replaceChild( $textnode, $print );
	}

        my @phrases = $template->getElementsByTagName("phrase");
	foreach my $phrase ( @phrases )
	{
		my $parent = $phrase->getParentNode;
		my $ref = "phrase:".$phrase->getAttribute( "ref" );
		my $textnode = $doc->createTextNode( $divide.$ref.$divide );
		$parent->replaceChild( $textnode, $phrase );
	}

	_divide_attributes( $template, $doc, $divide );

	my @r = split( "$divide", EPrints::XML::to_string( $template,undef,1 ) );

	return \@r;
}

sub _divide_attributes
{
	my( $node, $doc, $divide ) = @_;

	return unless( EPrints::XML::is_dom( $node, "Element" ) );

	foreach my $kid ( $node->getChildNodes )
	{
		_divide_attributes( $kid, $doc, $divide );
	}
	
	my $attrs = $node->attributes;

	return unless defined $attrs;
	
	for( my $i = 0; $i < $attrs->length; ++$i )
	{
		my $attr = $attrs->item( $i );
		my $v = $attr->nodeValue;
		next unless( $v =~ m/\{/ );
		my $name = $attr->nodeName;
		my @r = EPrints::XML::EPC::split_script_attribute( $v, $name );
		my @r2 = ();
		for( my $i = 0; $i<scalar @r; ++$i )
		{
			if( $i % 2 == 0 )
			{
				push @r2, $r[$i];
			}
			else
			{
				push @r2, "print:".$r[$i];
			}
		}
		if( scalar @r % 2 == 0 )
		{
			push @r2, "";
		}
		
		my $newv = join( $divide, @r2 );
		$attr->setValue( $newv );
	}

	return;
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
	$self->freshen_template( $langid, $tempid );
	my $t = $self->{text_templates}->{$tempid}->{$langid};
	if( !defined $t ) 
	{
		EPrints::abort( <<END );
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
	$self->freshen_template( $langid, $tempid );
	my $t = $self->{html_templates}->{$tempid}->{$langid};
	if( !defined $t ) 
	{
		EPrints::abort( <<END );
Error. Template not loaded.
Language: $langid
Template ID: $tempid
END
	}

	return $t;
}

######################################################################
# 
# $success = $repository->_load_namedsets
#
# Loads and caches all the named set lists from the cfg/namedsets/ directory.
#
######################################################################

sub _load_namedsets
{
	my( $self ) = @_;


	# load /namedsets/* 

	my $dir = $self->get_conf( "config_path" )."/namedsets";
	my $dh;
	opendir( $dh, $dir );
	my @type_files = ();
	while( my $fn = readdir( $dh ) )
	{
		next if $fn=~m/^\./;
		push @type_files, $fn;
	}
	closedir( $dh );

	foreach my $tfile ( @type_files )
	{
		my $file = $dir."/".$tfile;

		my $type_set = $tfile;	
		open( FILE, $file ) || EPrints::abort( "Could not read $file" );

		my @types = ();
		foreach my $line (<FILE>)
		{
			$line =~ s/\015?\012?$//s;
			$line =~ s/#.*$//;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next if $line eq "";
			push @types, $line;
		}
		close FILE;

		$self->{types}->{$type_set} = \@types;
	}

	return 1;
}

######################################################################
=pod

=item @type_ids = $repository->get_types( $type_set )

Return an array of keys for the named set. Comes from 
/cfg/types/foo.xml

=cut
######################################################################

sub get_types
{
	my( $self, $type_set ) = @_;

	if( !defined $self->{types}->{$type_set} )
	{
		$self->log( "Request for unknown named set: $type_set" );
		return ();
	}

	return @{$self->{types}->{$type_set}};
}

######################################################################
# 
# $success = $repository->_load_datasets
#
# Loads and caches all the EPrints::DataSet objects belonging to this
# repository.
#
######################################################################

sub _load_datasets
{
	my( $self ) = @_;

	$self->{datasets} = {};

	# system datasets
	my %info = %{EPrints::DataSet::get_system_dataset_info()};

	# repository-specific datasets
	my $repository_datasets = $self->get_conf( "datasets" );
	foreach my $ds_id ( keys %{$repository_datasets||{}} )
	{
		$info{$ds_id} = $repository_datasets->{$ds_id};
	}

	# sort the datasets so that derived datasets follow (and hence share
	# their fields)
	foreach my $ds_id (
		sort { defined $info{$a}->{confid} <=> defined $info{$b}->{confid} }
		keys %info
		)
	{
		$self->{datasets}->{$ds_id} = EPrints::DataSet->new(
			repository => $self,
			name => $ds_id,
			%{$info{$ds_id}}
			);
	}

	return 1;
}

######################################################################
=pod

=item @dataset_ids = $repository->get_dataset_ids()

Returns a list of dataset ids in this repository.

=cut
######################################################################

sub get_dataset_ids
{
	my( $self ) = @_;

	return keys %{$self->{datasets}};
}

######################################################################
=pod

=item @dataset_ids = $repository->get_sql_dataset_ids()

Returns a list of dataset ids that have database tables.

=cut
######################################################################

sub get_sql_dataset_ids
{
	my( $self ) = @_;

	my @dataset_ids = $self->get_dataset_ids();

	return grep { !$self->get_dataset( $_ )->is_virtual } @dataset_ids;
}

######################################################################
=pod

=item @counter_ids = $repository->get_sql_counter_ids()

Returns a list of counter ids generated by the database.

=cut
######################################################################

sub get_sql_counter_ids
{
	my( $self ) = @_;

	my @counter_ids;

	foreach my $ds_id ($self->get_sql_dataset_ids)
	{
		my $dataset = $self->get_dataset( $ds_id );
		foreach my $field ($dataset->get_fields)
		{
			next unless $field->isa( "EPrints::MetaField::Counter" );
			my $c_id = $field->get_property( "sql_counter" );
			push @counter_ids, $c_id if defined $c_id;
		}
	}

	return @counter_ids;
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
# $success = $repository->_load_plugins
#
# Load any plugins distinct to this repository.
#
######################################################################

sub _load_plugins
{
	my( $self ) = @_;

	$self->{plugins} = EPrints::PluginFactory->new( $self );

	return defined $self->{plugins};
}

=item $plugins = $repository->get_plugin_factory()

Return the plugins factory object.

=cut

sub get_plugin_factory
{
	my( $self ) = @_;

	return $self->{plugins};
}

######################################################################
# 
# $classname = $repository->get_plugin_class
#
# Returns the perl module for a plugin with this id, using global
# and repository-sepcific plugins.
#
######################################################################

sub get_plugin_class
{
	my( $self, $pluginid ) = @_;

	return $self->{plugins}->get_plugin_class( $pluginid );
}

######################################################################
# 
# @list = $repository->get_plugin_ids
#
# Returns a list of plugin ids available to this repository.
#
######################################################################

sub get_plugin_ids
{
	my( $self ) = @_;

	return
		map { $_->get_id() }
		$self->{plugins}->get_plugin_factory();
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
		my $plugin = $self->{plugins}->get_plugin( $full_plugin_id );
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
	
	my $fn;
	if( ref $cmd eq "ARRAY" )
	{
		$fn = $self->get_conf( @$cmd );
		$cmd = join( "->",@{$cmd} );
	}
	else
	{
		$fn = $self->get_conf( $cmd );
	}

	if( !defined $fn || ref $fn ne "CODE" )
	{
		# Can't log, as that could cause a loop.
		print STDERR "Undefined or invalid function: $cmd\n";
		return;
	}

	my( $r, @r );
	if( wantarray )
	{
		@r = eval { return &$fn( @params ) };
	}
	else
	{
		$r = eval { return &$fn( @params ) };
	}
	if( $@ )
	{
		print "$@\n";
		exit 1;
	}
	return wantarray ? @r : $r;
}

######################################################################
=pod

=item $boolean = $repository->can_call( @cmd_conf_path )

Return true if the given subroutine exists in this repository's config
package.

=cut
######################################################################

sub can_call
{
	my( $self, @cmd_conf_path ) = @_;
	
	my $fn = $self->get_conf( @cmd_conf_path );
	return( 0 ) unless( defined $fn );

	return( 0 ) unless( ref $fn eq "CODE" );

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

	return EPrints::Platform::free_space( $filepath );
} 




######################################################################
=pod

=item $domdocument = $repository->parse_xml( $file, $no_expand );

Turns the given $file into a XML DOM document. If $no_expand
is true then load &entities; but do not expand them to the values in
the DTD.

This function also sets the path in which the Parser will look for 
DTD files to the repository's config directory.

Returns undef if an error occurs during parsing.

=cut
######################################################################

sub parse_xml
{
	my( $self, $file, $no_expand ) = @_;

	my $doc;
	eval {
		$doc = EPrints::XML::parse_xml( 
			$file, 
			$self->get_conf( "lib_path" ) . "/",
			$no_expand );
	};
	if( !defined $doc )
	{
		$self->log( "Failed to parse XML file: $file: $@" );
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

	return EPrints::Platform::exec( $self, $cmd_id, %map );
}

sub can_execute
{
	my( $self, $cmd_id ) = @_;

	my $cmd = $self->get_conf( "executables", $cmd_id );

	return ($cmd and $cmd ne "NOTFOUND") ? 1 : 0;
}

sub can_invoke
{
	my( $self, $cmd_id, %map ) = @_;

	my $execs = $self->get_conf( "executables" );

	foreach( keys %{$execs} )
	{
		$map{$_} = $execs->{$_} unless $execs->{$_} eq "NOTFOUND";
	}

	my $command = $self->get_conf( "invocation" )->{ $cmd_id };
	
	return 0 if( !defined $command );

	$command =~ s/\$\(([a-z]*)\)/quotemeta($map{$1})/gei;

	return 0 if( $command =~ /\$\([a-z]*\)/i );

	return 1;
}

######################################################################
=pod

=item $commandstring = $repository->invocation( $cmd_id, %map )

Finds the invocation for the specified command from SystemSetting and
fills in the blanks using %map. Returns a string which may be executed
as a system call.

All arguments are ESCAPED using quotemeta() before being used (i.e. don't
pre-escape arguments in %map).

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

	$command =~ s/\$\(([a-z]*)\)/quotemeta($map{$1})/gei;

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

DEPRECATED

=cut
######################################################################

sub generate_dtd
{
	my( $self ) = @_;

	my $src_dtdfile = $self->get_conf("lib_path")."/xhtml-entities.dtd";
	my $tgt_dtdfile = $self->get_conf( "variables_path" )."/entities.dtd";

	my $src_mtime = EPrints::Utils::mtime( $src_dtdfile );
	my $tgt_mtime = EPrints::Utils::mtime( $tgt_dtdfile );
	if( $tgt_mtime > $src_mtime )
	{
		# as this file doesn't change anymore, except possibly after an
		# upgrade, only update the var/entities.dtd file if the one in
		# the lib directory is newer.
		return 1;
	}

	open( XHTMLENTITIES, "<", $src_dtdfile ) ||
		die "Failed to open system DTD ($src_dtdfile) to include ".
			"in repository DTD";
	my $xhtmlentities = join( "", <XHTMLENTITIES> );
	close XHTMLENTITIES;

	my $tmpfile = File::Temp->new;

	print $tmpfile <<END;
<!-- 
	XHTML Entities

	*** DO NOT EDIT, This is auto-generated ***
-->
<!--
	Generic XHTML entities 
-->

END
	print $tmpfile $xhtmlentities;
	close $tmpfile;

	copy( "$tmpfile", $tgt_dtdfile );

	EPrints::Utils::chown_for_eprints( $tgt_dtdfile );

	return 1;
}



######################################################################
=pod

=item ( $returncode, $output) = $repository->test_config

This runs "epadmin test" as an external script to test if the current
configuraion on disk loads OK. This can be used by the web interface
to test if changes to config. files may be saved, or not.

$returncode will be zero if everything seems OK.

If not, then $output will contain the output of epadmin test 

=cut
######################################################################

sub test_config
{
	my( $self ) = @_;

	my $rc = 0;
	my $output = "";

	my $tmp = File::Temp->new;

	$rc = EPrints::Platform::read_perl_script( $self, $tmp, "-e", "use EPrints qw( no_check_user );" );

	while(<$tmp>)
	{
		$output .= $_;
	}

	return ($rc/256, $output);
}



1;

######################################################################
=pod

=back

=cut
######################################################################

