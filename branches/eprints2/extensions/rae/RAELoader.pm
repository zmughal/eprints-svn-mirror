######################################################################
#
# Load RAE-specific configuration and phrases, and add them to the 
# loaded EPrints configuration.
#
######################################################################
#
# This file is part of the EPrints RAE module developed by the 
# Institutional Repositories and Research Assessment (IRRA) project,
# funded by JISC within the Digital Repositories programme.
#
# http://irra.eprints.org/
#
# The EPrints RAE module is free software; you can redistributet 
# and/or modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 of 
# the License, or (at your option) any later version.

# The EPrints RAE module is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty 
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
######################################################################

package RAELoader;

# TODO: Is EPrints::RAE::PHRASES unique for different archives?
# => EPrints::$archive_id::RAE::PHRASES instead

sub init_rae
{
	my ( $session ) = @_;

	my $archiveid = $session->get_archive->get_id;

	print STDERR "Initialising RAE\n";

	my $cfgpath = $session->get_archive->get_conf( "config_path" );
	my $phrasefile = $cfgpath . "/rae-phrases-" . $session->get_langid . ".xml";
	my $configfile = $cfgpath . "/ArchiveRAEConfig.pm";

	if( !defined $EPrints::RAE::PHRASES )
	{
		print STDERR "EPrints::RAE::PHRASES undef, loading.\n";
		init_rae_load_phrases( $session, $phrasefile );
	}
	else	
	{
		my @s = stat $phrasefile;
		if ($s[9]> $EPrints::RAE::PHRASES_TIME) {
			init_rae_load_phrases( $session, $phrasefile );
			print STDERR "$phrasefile has changed, reloading.\n";
		}
	}

	if( !defined $EPrints::RAE::CONFIG )
	{
		print STDERR "EPrints::RAE::CONFIG undef, loading.\n";
		init_rae_load_config( $session, $configfile );
	}
	else
	{
		my @s = stat $configfile;
		if ($s[9]> $EPrints::RAE::CONFIG_TIME) {
			init_rae_load_config( $session, $configfile ); 
			print STDERR "$configfile has changed, reloading.\n";
		}
	}
}
	
sub init_rae_load_phrases 
{
	my ( $session, $phrasefile ) = @_;
	$EPrints::RAE::PHRASES = $session->get_lang->_read_phrases($phrasefile, $session->get_archive);
	$EPrints::RAE::PHRASES_TIME = time;
	while(my ($key, $value) = each %$EPrints::RAE::PHRASES)
	{
		$session->get_lang->{archivedata}->{$key} = $value;
	}
}

sub init_rae_load_config
{
	my ( $session, $configfile ) = @_;
	unless (my $return = do $configfile) {
		warn "couldn't parse $configfile: $@" if $@;
		warn "couldn't do $configfile: $!" unless defined $return;
		warn "couldn't run $configfile" unless $return;
		return;
	}
	$EPrints::RAE::CONFIG = get_rae_conf();
	$EPrints::RAE::CONFIG_TIME = time;
	while(my ($key, $value) = each %$EPrints::RAE::CONFIG)
	{
		$session->get_archive->{config}{'rae'}{$key} = $value;
	}
}

1;
