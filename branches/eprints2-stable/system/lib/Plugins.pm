#!/usr/local/bin/perl5.8.0 -w -I/opt/ep2stable/perl_lib 

package EPrints::Plugins; 

use strict;

BEGIN { 
	$EPrints::Plugins::REGISTRY = {};

	sub EPrints::Plugins::register
	{
		my( $path, $func ) = @_;

		$EPrints::Plugins::REGISTRY->{$path} = $func;;
	}
}

use EPrints::Exporter;
my $plugins_dir = "/opt/ep2stable/perl_lib/EPrints/Plugins";
opendir( my $dir, $plugins_dir ) || EPrints::Config::abort( "could not read from $plugins_dir" );
while( my $plugin = readdir( $dir ) )
{
	next if( $plugin eq "CVS" );
	next if( $plugin =~ m/^\./ );
	print STDERR $plugin."\n";
	my $file =  $plugins_dir.'/'.$plugin;
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
Failed to load plugin 
$file
Errors follow:
------------------------------------------------------------------
$errors
------------------------------------------------------------------
END
		return;
	}
}
closedir( $dir );

#EPrints::Plugins::BibTeX::register_plugins();
#EPrints::Plugins::DC::register_plugins();
#EPrints::Plugins::XML::register_plugins();
#EPrints::Plugins::RSS1::register_plugins();


sub EPrints::Plugins::call
{
	my( $path, @params ) = @_;

	if( !defined $EPrints::Plugins::REGISTRY->{$path} )
	{
		EPrints::Config::abort( "Plugins does not exist: $path\n" );
	}

	return &{$EPrints::Plugins::REGISTRY->{$path}}( @params );
}

