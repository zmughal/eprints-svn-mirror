#!/usr/local/bin/perl5.8.0 -w -I/opt/ep2stable/perl_lib 

package EPrints::Plugins; 

use EPrints::SystemSettings;

use strict;

BEGIN { 
	$EPrints::Plugins::PLUGINS = {};
	$EPrints::Plugins::CONFIG = {};

	sub EPrints::Plugins::register
	{
		my( $path, $func ) = @_;
#print STDERR "Plugin: $path\n";
		$EPrints::Plugins::PLUGINS->{$path} = $func;
	}

	sub EPrints::Plugins::registerConfig
	{
		my( $path, $opt ) = @_;
print STDERR "config: $path:$opt\n";
		$EPrints::Plugins::CONFIG->{$path} = $opt;
	}
}


my $plugins_dir = $EPrints::SystemSettings::conf->{base_path}.
			"/perl_lib/EPrints/Plugins";
load_dir( $plugins_dir );

sub load_dir
{
	my( $dir ) = @_;

	my $dh;
	unless( opendir( $dh, $dir ) )
	{
		EPrints::Config::abort( "could not read from $dir" );
	}
	while( my $plugin = readdir( $dh ) )
	{
		next if( $plugin eq "CVS" );
		next if( $plugin =~ m/^\./ );
		my $file =  $dir.'/'.$plugin;
		EPrints::Plugins::load( $file );
	}
	closedir( $dh );
}

sub load
{
	my( $file ) = @_;

	@! = $@ = undef;
	my $ok = do $file;
	return if( $ok );

	my $errors = "couldn't run $file";
	$errors = "couldn't do $file:\n$!" unless defined $ok;
	$errors = "couldn't parse $file:\n$@" if $@;
	print STDERR <<END;
------------------------------------------------------------------
---------------- EPrints System Warning --------------------------
------------------------------------------------------------------
Failed to load plugin 
$file
Errors follow:
------------------------------------------------------------------
$errors
------------------------------------------------------------------
END
}


sub get_all
{
	return $EPrints::Plugins::PLUGINS;
}
sub getDefaultConfig
{
	return $EPrints::Plugins::CONFIG;
}

