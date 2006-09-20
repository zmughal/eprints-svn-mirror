######################################################################
#
# EPrints::Config
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

B<EPrints::Config> - software configuration handler

=head1 DESCRIPTION

This module handles loading the main configuration for an instance
of the eprints software - such as the list of language id's and 
the top level configurations for repositories - the XML files in /archives/

=over 4

=cut

######################################################################

#cjg SHOULD BE a way to configure an repository NOT to load the
# module except on demand (for buggy / testing ones )

package EPrints::Config;

use EPrints;

use Unicode::String qw(utf8 latin1);
use Data::Dumper;
use Cwd;

use strict;

BEGIN { sub abort { return EPrints::abort( @_ ); } }

my %SYSTEMCONF;
my @LANGLIST;
my @SUPPORTEDLANGLIST;
my %LANGNAMES;
my %ARCHIVES;
#my %ARCHIVEMAP;
my $INIT = 0; 


######################################################################
=pod

=item EPrints::Config::ensure_init()

If the init() method has not yet been called then call it, otherwise
do nothing.

=cut
######################################################################

sub ensure_init
{
	return if( $INIT );
	init();
}


######################################################################
=pod

=item EPrints::Config::init()

Load all the EPrints configuration files, first the general files
such as SystemSettings and then the configurations
for each repository.

=cut
######################################################################

sub init
{
	if( $INIT )
	{
		print STDERR "init() called after config already loaded\n";
		return;
	}

	$INIT = 1;

	foreach( keys %{$EPrints::SystemSettings::conf} )
	{
		$SYSTEMCONF{$_} = $EPrints::SystemSettings::conf->{$_};
	}
	# cjg Should these be hardwired? Probably they should.
	$SYSTEMCONF{cgi_path} = $SYSTEMCONF{base_path}."/cgi";
	$SYSTEMCONF{cfg_path} = $SYSTEMCONF{base_path}."/cfg";
	$SYSTEMCONF{lib_path} = $SYSTEMCONF{base_path}."/lib";
	$SYSTEMCONF{arc_path} = $SYSTEMCONF{base_path}."/archives";
	$SYSTEMCONF{bin_path} = $SYSTEMCONF{base_path}."/bin";
	$SYSTEMCONF{var_path} = $SYSTEMCONF{base_path}."/var";
	
	###############################################
	
	opendir( CFG, $SYSTEMCONF{arc_path} );
	my $file;
	while( $file = readdir( CFG ) )
	{
		next unless( $file=~m/^(.*)\.xml$/ );
		
		my $id = $1;
	
		$ARCHIVES{$id} = load_repository_config( $id );
	}
	closedir( CFG );
}

	
######################################################################
=pod

=item $arc_config = EPrints::Config::load_repository_config( $arc_id )

Load the configuration of the specified repository and return it as a 
data structure.

=cut
######################################################################
sub load_archive_config { return load_repository_config( @_ ); }

sub load_repository_config
{
	my( $id ) = @_;

	my $fpath = $SYSTEMCONF{arc_path}."/".$id.".xml";

	my $conf_doc = EPrints::XML::parse_xml( $fpath );
	if( !defined $conf_doc )
	{
		print STDERR "Error parsing file: $fpath\n";
		next;
	}
	my $conf_tag = ($conf_doc->getElementsByTagName( "archive" ))[0];
	if( !defined $conf_tag )
	{
		print STDERR "In file: $fpath there is no <archive> tag.\n";
		EPrints::XML::dispose( $conf_doc );
		next;
	}
	if( $id ne $conf_tag->getAttribute( "id" ) )
	{
		print STDERR "In file: $fpath id is not $id\n";
		EPrints::XML::dispose( $conf_doc );
		next;
	}
	my $ainfo = {};
	foreach( keys %SYSTEMCONF ) { $ainfo->{$_} = $SYSTEMCONF{$_}; }
	my $tagname;
	foreach $tagname ( 
			"host", "urlpath", "port", 
			"archiveroot", "dbname", "dbhost", "dbport",
			"dbsock", "dbuser", "dbpass", "defaultlanguage",
			"adminemail", "securehost", "securepath", "index" )
	{
		my $tag = ($conf_tag->getElementsByTagName( $tagname ))[0];
		if( !defined $tag )
		{
			next if(  $tagname eq "securehost" );
			next if(  $tagname eq "securepath" );
			next if(  $tagname eq "index" );

			EPrints::Config::abort( "In file: $fpath the $tagname tag is missing." );
		}
		my $val = "";
		foreach( $tag->getChildNodes ) { $val.=EPrints::XML::to_string( $_ ); }
		$ainfo->{$tagname} = $val;
	}
	unless( $ainfo->{archiveroot}=~m#^/# )
	{
		$ainfo->{archiveroot}= $SYSTEMCONF{base_path}."/".$ainfo->{archiveroot};
	}

	# remove any trailing slash from the urlpath
	$ainfo->{urlpath} =~ s#/$##;

#cjg clean this out later
#	$ARCHIVEMAP{$ainfo->{host}.$ainfo->{urlpath}} = $id;
#	if( EPrints::Utils::is_set( $ainfo->{securehost} ) )
#	{
#		$ARCHIVEMAP{$ainfo->{securehost}.$ainfo->{securepath}} = $id;
#	}
	$ainfo->{aliases} = [];
	foreach my $tag ( $conf_tag->getElementsByTagName( "alias" ) )
	{
		my $alias = {};
		my $val = "";
		foreach( $tag->getChildNodes ) { $val.=EPrints::XML::to_string( $_ ); }
		$alias->{name} = $val; 
		$alias->{redirect} = ( $tag->getAttribute( "redirect" ) eq "yes" );
		push @{$ainfo->{aliases}},$alias;
#		$ARCHIVEMAP{$alias->{name}.$ainfo->{urlpath}} = $id;
	}
	$ainfo->{languages} = [];
	foreach my $tag ( $conf_tag->getElementsByTagName( "language" ) )
	{
		my $val = "";
		foreach( $tag->getChildNodes ) { $val.=EPrints::XML::to_string( $_ ); }
		push @{$ainfo->{languages}},$val;
	}
	foreach my $tag ( $conf_tag->getElementsByTagName( "archivename" ) )
	{
		my $val = "";
		foreach( $tag->getChildNodes ) { $val.=EPrints::XML::to_string( $_ ); }
		my $langid = $tag->getAttribute( "language" );
		$ainfo->{archivename}->{$langid} = $val;
	}

	# clean up boolean "index" option
	$ainfo->{index} = !( defined $ainfo->{index} && "\L$ainfo->{index}" eq "no" );

	EPrints::XML::dispose( $conf_doc );

	return $ainfo;
}
	



######################################################################
=pod

=item $repository = EPrints::Config::get_repository_config( $id )

Returns a hash of the basic configuration for the repository with the
given id. This hash will include the properties from SystemSettings.

=cut
######################################################################
sub get_archive_config { return get_repository_config( @_ ); }

sub get_repository_config
{
	my( $id ) = @_;

	ensure_init();

	return $ARCHIVES{$id};
}




######################################################################
=pod

=item @ids = EPrints::Config::get_repository_ids()

Return a list of ids of all repositories belonging to this instance of
the eprints software.

=cut
######################################################################
sub get_archive_ids { return get_repository_ids(); }

sub get_repository_ids
{
	ensure_init();

	return keys %ARCHIVES;
}



######################################################################
=pod

=item $arc_conf = EPrints::Config::load_repository_config_module( $id )

Load the full configuration for the specified repository unless the 
it has already been loaded.

Return a reference to a hash containing the full repository configuration. 

=cut
######################################################################
sub load_archive_config_module { return load_repository_config_module( @_ ); }

sub load_repository_config_module
{
	my( $id ) = @_;

	ensure_init();

	my $info = $ARCHIVES{$id};
	return unless( defined $info );

	my @oldinc = @INC;
	local @INC;
	@INC = (@oldinc, $info->{archiveroot} );

	#my $prev_dir =  EPrints::Utils::untaint_dir( getcwd );
	#chdir EPrints::Utils::untaint_dir( $info->{archiveroot} );
	#my $return = do $file;
	#chdir $prev_dir;

	my $dir = $info->{archiveroot}."/cfg/cfg.d";
	my $dh;
	opendir( $dh, $dir ) || EPrints::abort( "Can't read cfg.d config files: $!" );
	my @files = ();
	while( my $file = readdir( $dh ) )
	{
		next if $file =~ /^\./;
		push @files, $file;
	}
	closedir( $dh );

	eval '$EPrints::Config::'.$id.'::config = $info';
	foreach my $file ( sort @files )
	{
		$@ = undef;
		my $filepath = "$dir/$file";
		my $err;
		unless( open( CFGFILE, $filepath ) )
		{
			EPrints::abort( "Could not open $filepath: $!" );
		}
		my $cfgfile = join('',<CFGFILE>);
		close CFGFILE;
	 	my $todo = 'package EPrints::Config::'.$id.'; our $c = $EPrints::Config::'.$id.'::config; '.$cfgfile;
		eval $todo;

		if( $@ )
		{
			my $errors = "error in $filepath:\n$@";
			print STDERR <<END;
------------------------------------------------------------------
---------------- EPrints System Warning --------------------------
------------------------------------------------------------------
Failed to load config module for $id
Main Config File: $info->{configmodule}
Errors follow:
------------------------------------------------------------------
$errors
------------------------------------------------------------------
END
			return;
		}
	}
	
	return eval '$EPrints::Config::'.$id.'::config';
}


######################################################################
=pod

=item $title = EPrints::Config::lang_title( $id )

Return the title of a given language as a UTF-8 encoded string. 

For example: "en" would return "English".

=cut
######################################################################

sub lang_title
{
	my( $id, $session ) = @_;

	ensure_init();

	return $LANGNAMES{$id};
}


######################################################################
=pod

=item $value = EPrints::Config::get( $confitem )

Return the value of a given eprints configuration item. These
values are obtained from SystemSettings plus a few extras for
paths.

=cut
######################################################################

sub get
{
	my( $confitem ) = @_;

	ensure_init();

	return $SYSTEMCONF{$confitem};
}

1;

######################################################################
=pod

=back

=cut

