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

=head1 METHODS

=head2 Deprecated Methods

=over 4

=item EPrints::Config::abort

Deprecated, use L<EPrints>::abort.

=item EPrints::Config::get_archive_config
=item EPrints::Config::get_archive_ids
=item EPrints::Config::load_archive_config_module

Deprecated, use *_repository_*.

=back

=head2 Normal Methods

=over 4

=cut

######################################################################

#cjg SHOULD BE a way to configure an repository NOT to load the
# module except on demand (for buggy / testing ones )

package EPrints::Config;

use warnings;
use strict;

my $SYSTEMCONF = $EPrints::SystemSettings::conf;
my @LANGLIST;
my @SUPPORTEDLANGLIST;
my %ARCHIVES;
#my %ARCHIVEMAP;

# deprecated support for abort()
sub abort { &EPrints::abort( @_ ) }

# deprecated
sub ensure_init {}

######################################################################
=pod

=item EPrints::Config::init()

Load the EPrints configuration.

Do not use this method directly, it will be automatically called
when using EPrints.

=cut
######################################################################

sub init
{
	# cjg Should these be hardwired? Probably they should.
	$SYSTEMCONF->{cgi_path} = $SYSTEMCONF->{base_path}."/cgi";
	$SYSTEMCONF->{cfg_path} = $SYSTEMCONF->{base_path}."/cfg";
	$SYSTEMCONF->{lib_path} = $SYSTEMCONF->{base_path}."/lib";
	$SYSTEMCONF->{arc_path} = $SYSTEMCONF->{base_path}."/archives";
	$SYSTEMCONF->{bin_path} = $SYSTEMCONF->{base_path}."/bin";
	$SYSTEMCONF->{var_path} = $SYSTEMCONF->{base_path}."/var";
	
	###############################################
	
	$SYSTEMCONF->{repository} = {};

	load_system_config();

	opendir( my $dh, $SYSTEMCONF->{arc_path} );
	my $id;
	while( $id = readdir( $dh ) )
	{
		next if( $id =~ m/^\./ );
		next if( !-d $SYSTEMCONF->{arc_path}."/".$id );
		next if $SYSTEMCONF->{repository}->{$id} && $SYSTEMCONF->{repository}->{$id}->{disabled};
		
		$ARCHIVES{$id} = {};
	}
	closedir( $dh );
}

=item EPrints::Config::load_system_config()

Load the system configuration files.

=cut

sub load_system_config
{
	my $syslibcfgd = $SYSTEMCONF->{"lib_path"}."/syscfg.d";
	my $syscfgd = $SYSTEMCONF->{"cfg_path"}."/cfg.d";

	$SYSTEMCONF->{set_in} = {};
	foreach my $conf_id ( keys %{$SYSTEMCONF} )
	{
		$SYSTEMCONF->{set_in}->{$conf_id} = "EPrints::SystemSettings";
	}

	my $files = {};

	foreach my $dir ( $syslibcfgd, $syscfgd )
	{
		opendir(my $dh, $dir) or EPrints::abort( "Error opening config directory $dir: $!" );
		foreach my $file (readdir($dh)) 
		{
			next if $file =~ m/^\./;
			next if $file !~ m/\.pl$/;
			$files->{$file} = "$dir/$file";
		}
		closedir($dh);
	}

	foreach my $file ( sort keys %{$files} )
	{	
		my $filepath = $files->{$file};

		open(my $fh, "<", $filepath) or EPrints::abort( "Error reading from $filepath: $!" );

		$EPrints::SystemSettings::tmp = {};
		my $perl = <<EOP;
package EPrints::SystemSettings;

use EPrints::Const;

our \$c = \$EPrints::SystemSettings::conf;

EOP
		$perl .= join "", <$fh>;
		close($fh);

		eval $perl;
		if( $@ )
		{
			my $errors = "error in $filepath:\n$@";
			print STDERR <<END;
------------------------------------------------------------------
---------------- EPrints System Error ----------------------------
------------------------------------------------------------------
Failed to load system config
Errors follow:
------------------------------------------------------------------
$errors
------------------------------------------------------------------
END
			exit(1);
		}

		foreach my $conf_id ( keys %{$EPrints::SystemSettings::tmp} )
		{
			if( !exists( $SYSTEMCONF->{set_in}->{$conf_id} ) )
			{
				$SYSTEMCONF->{set_in}->{$conf_id} = $filepath;
			}
		}
	}
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

	my $info = {};
	
	%$info = %$SYSTEMCONF;

	$info->{archiveroot} = $info->{arc_path}."/".$id;
	$info->{documents_path} = $info->{archiveroot}."/documents";
	$info->{config_path} = $info->{archiveroot}."/cfg";
	$info->{htdocs_path} = $info->{archiveroot}."/html";
	$info->{cgi_path} = $info->{archiveroot}."/cgi";

	if( !-d $info->{archiveroot} )
	{
		print STDERR "No repository named '$id' found in ".$info->{arc_path}.".\n\n";
		exit 1;
	}

	if( !exists $ARCHIVES{$id} )
	{
		print STDERR "Repository named '$id' disabled by configuration.\n";
		exit 1;
	}

	no strict 'refs';
	eval ' $EPrints::Config::'.$id.'::config = bless $info, "EPrints::RepositoryConfig"; ';
	use strict 'refs';

	my @oldinc = @INC;
	local @INC;
	@INC = (@oldinc, $info->{archiveroot} );

	my $libcfgd = $SYSTEMCONF->{"lib_path"}."/cfg.d";
	my $repcfgd = $info->{archiveroot}."/cfg/cfg.d";
	my %files_map = ();

	foreach my $dir ( $libcfgd, $repcfgd )
	{
		opendir( my $dh, $dir ) || EPrints::abort( "Can't read cfg.d config files from $dir: $!" );
		while( my $file = readdir( $dh ) )
		{
			next if $file =~ /^\./;
			next unless $file =~ /\.pl$/;
			$files_map{$file} = "$dir/$file";
		}
		closedir( $dh );
	}

	my @files = ();
	foreach my $file ( sort keys %files_map ) { push @files, $files_map{$file}; }

	my $metafield_pl = $info->{archiveroot}."/var/metafield.pl";
	if( -e $metafield_pl )
	{
		push @files, $metafield_pl;
	}

	$info->{set_in} = {};
	my $set = {};
	foreach( keys %$info ) { $set->{$_} = 1; }
		
	foreach my $filepath ( sort @files )
	{
		$@ = undef;
		my $err;
		unless( open( CFGFILE, $filepath ) )
		{
			EPrints::abort( "Could not open $filepath: $!" );
		}
		my $cfgfile = join('',<CFGFILE>);
		close CFGFILE;
	 	my $todo = <<END;
package EPrints::Config::$id; 
use EPrints::Const;
our \$c = \$EPrints::Config::${id}::config;
#line 1 "$filepath"
$cfgfile
END
#print STDERR "$filepath...\n";
		eval $todo;

		if( $@ )
		{
			my $errors = "error in $filepath:\n$@";
			print STDERR <<END;
------------------------------------------------------------------
---------------- EPrints System Warning --------------------------
------------------------------------------------------------------
Failed to load config module for $id
------------------------------------------------------------------
$errors
------------------------------------------------------------------
END
			return;
		}
		foreach( keys %$info )
		{
			next if defined $set->{$_};
			$set->{$_} = 1;
			$info->{set_in}->{$_} = \$filepath;
		}
	}

	return $info;
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

	return $SYSTEMCONF->{$confitem};
}

1;

######################################################################
=pod

=back

=cut

