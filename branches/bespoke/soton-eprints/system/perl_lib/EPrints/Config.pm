######################################################################
#
# EPrints::Config
#
######################################################################
#
#  This file is part of GNU EPrints 2.
#  
#  Copyright (c) 2000-2004 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 2 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 2 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 2; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################


=pod

=head1 NAME

B<EPrints::Config> - software configuration handler

=head1 DESCRIPTION

This module handles loading the main configuration for an instance
of the eprints software - such as the list of language id's and 
the top level configurations for archives - the XML files in /archives/

=over 4

=cut

######################################################################

#cjg SHOULD BE a way to configure an archive NOT to load the
# module except on demand (for buggy / testing ones )

package EPrints::Config;
use EPrints::Utils;
use EPrints::SystemSettings;
use EPrints::XML;
use EPrints::AnApache;

use Unicode::String qw(utf8 latin1);
use Data::Dumper;
use Cwd;

use strict;

BEGIN {
	use Carp qw(cluck);

	# Paranoia: This may annoy people, or help them... cjg

	# mod_perl will probably be running as root for the main httpd.
	# The sub processes should run as the same user as the one specified
	# in $EPrints::SystemSettings
	# An exception to this is running as root (uid==0) in which case
	# we can become the required user.
	unless( $ENV{MOD_PERL} ) 
	{
		#my $req($login,$pass,$uid,$gid) = getpwnam($user)
		my $req_username = $EPrints::SystemSettings::conf->{user};
		my $req_group = $EPrints::SystemSettings::conf->{group};
		my $req_uid = (getpwnam($req_username))[2];
		my $req_gid = (getgrnam($req_group))[2];

		my $username = (getpwuid($>))[0];
		if( $> == 0 )
		{
			# Special case: Running as root, we change the 
			# effective UID to be the one required in
			# EPrints::SystemSettings

			# remember kids, change the GID first 'cus you
			# can't after you change from root UID.
			$) = $( = $req_gid;
			$> = $< = $req_uid;
		}
		elsif( $username ne $req_username )
		{
			abort( 
"We appear to be running as user: ".$username."\n".
"We expect to be running as user: ".$req_username );
		}
		# otherwise ok.
	}

	# abort($err) Defined here so modules can abort even at startup
######################################################################
=pod

=item EPrints::Config::abort( $msg )

Print an error message and exit. If running under mod_perl then
print the error as a webpage and exit.

This subroutine is loaded before other modules so that it may be
used to report errors when initialising modules.

=cut
######################################################################

	sub abort
	{
		my( $errmsg ) = @_;

		my $r;
		if( $ENV{MOD_PERL} && $EPrints::SystemSettings::loaded)
		{
			$r = EPrints::AnApache::get_request();
		}
		if( defined $r )
		{
			# If we are running under MOD_PERL
			# AND this is actually a request, not startup,
			# then we should print an explanation to the
			# user in addition to logging to STDERR.

			$r->content_type( 'text/html' );
			EPrints::AnApache::send_http_header( $r );
			print <<END;
<html>
  <head>
    <title>EPrints System Error</title>
  </head>
  <body>
    <h1>EPrints System Error</h1>
    <p><tt>$errmsg</tt></p>
  </body>
</html>
END
		}

		
		print STDERR <<END;
	
------------------------------------------------------------------
---------------- EPrints System Error ----------------------------
------------------------------------------------------------------
$errmsg
------------------------------------------------------------------
END
		$@="";
		cluck( "EPrints System Error inducing stack dump\n" );
		exit;
		#exit;
	}
}

my %SYSTEMCONF;
my @LANGLIST;
my @SUPPORTEDLANGLIST;
my %LANGNAMES;
my %ARCHIVES;
#my %ARCHIVEMAP;
my $INIT = 0; 


sub ensure_init
{
	return if( $INIT );
	init();
}


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
	$SYSTEMCONF{arc_path} = $SYSTEMCONF{base_path}."/archives";
	$SYSTEMCONF{phr_path} = $SYSTEMCONF{base_path}."/cfg";
	$SYSTEMCONF{sys_path} = $SYSTEMCONF{base_path}."/cfg";
	$SYSTEMCONF{bin_path} = $SYSTEMCONF{base_path}."/bin";
	$SYSTEMCONF{var_path} = $SYSTEMCONF{base_path}."/var";
	

	foreach my $dir ( $SYSTEMCONF{base_path}."/var" )
	{
		next if( -d $dir );
			mkdir( $dir, 0755 );
	}
	#chown( $uid, $gid, $dir );


	###############################################

	my $file = $SYSTEMCONF{cfg_path}."/languages.xml";
	my $lang_doc = EPrints::XML::parse_xml( $file );
	my $top_tag = ($lang_doc->getElementsByTagName( "languages" ))[0];
	if( !defined $top_tag )
	{
		EPrints::Config::abort( "Missing <languages> tag in $file" );
	}
	foreach my $lang_tag ( $top_tag->getElementsByTagName( "lang" ) )
	{
		my $id = $lang_tag->getAttribute( "id" );
		my $supported = ($lang_tag->getAttribute( "supported" ) eq "yes" );
		my $val = EPrints::Utils::tree_to_utf8( $lang_tag );
		push @LANGLIST,$id;
		if( $supported )
		{
			push @SUPPORTEDLANGLIST,$id;
		}
		$LANGNAMES{$id} = $val;
	}
	EPrints::XML::dispose( $lang_doc );
	
	###############################################
	
	opendir( CFG, $SYSTEMCONF{arc_path} );
	while( $file = readdir( CFG ) )
	{
		next unless( $file=~m/^(.*)\.xml$/ );
		
		my $id = $1;
	
		$ARCHIVES{$id} = load_archive_config( $id );
	}
	closedir( CFG );
}

	
sub load_archive_config
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
			"host", "urlpath", "configmodule", "port", 
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
	unless( $ainfo->{configmodule}=~m#^/# )
	{
		$ainfo->{configmodule}= $ainfo->{archiveroot}."/".$ainfo->{configmodule};
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

=item $archive = EPrints::Config::get_archive_config( $id )

Returns a hash of the basic configuration for the archive with the
given id. This hash will include the properties from SystemSettings. 

=cut
######################################################################

sub get_archive_config
{
	my( $id ) = @_;

	ensure_init();

	return $ARCHIVES{$id};
}


######################################################################
=pod

=item @languages = EPrints::Config::get_languages

Return a list of all known languages ids (from languages.xml).

=cut
######################################################################

sub get_languages
{
	ensure_init();

	return @LANGLIST;
}


######################################################################
=pod

=item @languages = EPrints::Config::get_supported_languages

Return a list of ids of all supported languages. 

EPrints does not yet formally support languages other then "en". You
have to configure others yourself. This will be fixed in a later 
version.

=cut
######################################################################

sub get_supported_languages
{
	ensure_init();

	return @SUPPORTEDLANGLIST;
}


######################################################################
=pod

=item @ids = EPrints::Config::get_archive_ids( get_archive_ids )

Return a list of ids of all archives belonging to this instance of
the eprints software.

=cut
######################################################################

sub get_archive_ids
{
	ensure_init();

	return keys %ARCHIVES;
}



######################################################################
=pod

=item $arc_conf = EPrints::Config::load_archive_config_module( $id )

Load the full configuration for the specified archive unless the 
it has already been loaded.

Return a reference to a hash containing the full archive configuration. 

=cut
######################################################################

sub load_archive_config_module
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

	my $file = $info->{configmodule};
	@! = $@ = undef;
	my $return = do $file;
	unless( $return )
	{
		my $errors = "couldn't run $file";
		$errors = "couldn't do $file:\n$!" unless defined $return;
		$errors = "couldn't parse $file:\n$@" if $@;
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
	

	my $function = \&{"EPrints::Config::".$id."::get_conf"};
	my $config = &$function( $info );

	##########################################################
	#
	# Change old configs into 2.3 format...
	#

	foreach my $stype ( "simple", "advanced" )
	{
		next if( defined $config->{"search"}->{$stype} );

		$config->{"search"}->{$stype} = {
			fieldnames => $config->{$stype."_search_fields"},
			# don't make search_fields yet!
			citation => $config->{$stype."_search_citation"} };
		if( $stype eq "simple" )
		{
			$config->{"search"}->{$stype}->{preamble_phrase} =
						 "cgi/search:preamble";
			$config->{"search"}->{$stype}->{title_phrase} =
						 "cgi/search:simple_search";
		}
		if( $stype eq "advanced" )
		{
			$config->{"search"}->{$stype}->{preamble_phrase} =
						 "cgi/advsearch:preamble";
			$config->{"search"}->{$stype}->{title_phrase} =
						 "cgi/advsearch:adv_search";
		}
	}

	foreach my $ds_id ( "inbox", "buffer", "archive", "deletion" )
	{
		my $stype = $ds_id;
		next if( defined $config->{"search"}->{$stype} );
		$config->{search}->{$stype} = {
			title_phrase => "cgi/users/eprint_search:title_".$stype,
			staff => 1,
			dataset_id => $ds_id,
			citation => $config->{"search"}->{"advanced"}->{"citation"}
		};
		if( defined $config->{"search"}->{"advanced"}->{"fieldnames"} )
		{
			my @fnames = ( 
					"eprintid", 
					"userid", 
					"dir", 
					@{$config->{"search"}->{"advanced"}->{"fieldnames"}} );
			$config->{search}->{$stype}->{"fieldnames"} = \@fnames;
		}
		else
		{
			my @sfields = ( 
					{ meta_fields => ["eprintid"] }, 
					{ meta_fields => ["userid"] }, 
					{ meta_fields => ["dir"] },
					@{$config->{"search"}->{"advanced"}->{"search_fields"}} );
			$config->{search}->{$stype}->{"search_fields"} = \@sfields;
		}
	}

	if( !defined $config->{"search"}->{"users"} )
	{
		$config->{search}->{"users"} = {
			title_phrase => "cgi/users/user_search:simple_search",
			preamble_phrase => "cgi/users/user_search:preamble",
			staff => 1,
			dataset_id => "user",
			fieldnames => $config->{"user_search_fields"}
		};
	}


	if( !defined $config->{field_defaults}->{hide_honourific} )
	{
		$config->{field_defaults}->{hide_honourific} = $config->{hide_honourific};
	}
	if( !defined $config->{field_defaults}->{hide_lineage} )
	{
		$config->{field_defaults}->{hide_lineage} = $config->{hide_lineage};
	}

	#
	# Defaults for >2.3.11
	#

	if( !defined $config->{allow_reset_password} )
	{
		$config->{allow_reset_password} = 1;
	}

	#
	# End of config updater
	#
	##########################################################


	return $config;
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

