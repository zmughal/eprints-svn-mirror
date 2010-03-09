
package RAELoader;

# TODO: EPrints::RAE::PHRASES unique for different archives? (vs. EPrints::$archive_id::RAE::PHRASES)

sub init_rae
{
	my ( $session ) = @_;

	print STDERR "Initialising RAE\n";

	my $cfgpath = $session->get_archive->get_conf( "config_path" );
	my $phrasefile = $cfgpath . "/rae-phrases-" . $session->get_langid . ".xml";
	my $configfile = $cfgpath . "/ArchiveRAEConfig.pm";

	if( !defined $EPrints::RAE::PHRASES )
	{
		print STDERR "RAE::PHRASES undef, loading.\n";
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
		print STDERR "RAE::CONFIG undef, loading.\n";
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
