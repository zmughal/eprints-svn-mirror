######################################################################
#
# EPrints::Plugins
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

B<EPrints::Plugins> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

package EPrints::Plugins;

use EPrints::Archive;
use EPrints::SystemSettings;

use strict;

$EPrints::Plugins::REGISTRY = {};



######################################################################
=pod

=item EPrints::Plugins::load()

Load all system plugins

=cut
######################################################################

sub load
{
	# no opts

	# cjg bad dir!
	my $dir = $EPrints::SystemSettings::conf->{base_path}."/plugins";

	set_register_target( $EPrints::Plugins::REGISTRY );
	load_dir( $dir, "EPrints::Archives::Plugins" );
}

######################################################################
=pod

=item EPrints::Plugins::set_register_target( $hash )

Set the hash to which new plugins are registered.

=cut
######################################################################

sub set_register_target
{
	my( $newtarget ) = @_;

	$EPrints::Plugins::REGISTER_TARGET = $newtarget;
}

######################################################################
=pod

=item EPrints::Plugins::load_dir( $path, $baseclass, @prefix )

Load plugins in this directory and recurse through subdirectories.

=cut
######################################################################

sub load_dir
{
	my( $path, $baseclass, @prefix ) = @_;

print STDERR "LOADING PLUGIN DIR: $path (".join( ",",@prefix).")\n";

	my $dh;
	opendir( $dh, $path ) || die "Could not open $path";
	while( my $fn = readdir( $dh ) )
	{
		next if( $fn =~ m/^\./ );
		next if( $fn eq "CVS" );
		my $filename = "$path/$fn";
		if( -d $filename )
		{
			load_dir( $filename, $baseclass, @prefix, $fn );
			next;
		}

		my $class = $baseclass."::".join("::",@prefix,$fn );
		open( PLUGIN, $filename ) || die "Can't open $filename.";
		my $eval_str = <<END;
package $class;

use strict;

use EPrints::Plugins;

END
		$eval_str.= join( "",<PLUGIN> )."\n1\n";
		close PLUGIN;

		my $return = eval $eval_str;

		unless ( $return ) {
			# the 6 lines above screw the error message. This puts it to
			# the correct value for the _file_ not the eval.
			if( $@ )
			{
				$@ =~ s/line (\d+)/"line ".($1-6)/eg;
			}
			warn "couldn't parse plugin $filename: $@" if $@;
			warn "couldn't eval plugin $filename: $!"    unless defined $return;
			warn "couldn't run plugin $filename"       unless $return;
		}
	}
	closedir( $dh );

}


######################################################################
=pod

=item EPrints::Plugins::register( %parameters );

Required parameter is "id".

=cut
######################################################################

sub register
{
	my( %params ) = @_;

	$EPrints::Plugins::REGISTER_TARGET->{$params{id}} = \%params;
}

#######################################################################
#=pod
#
#=item $thing = EPrints::Plugins::call( $pluginid, $method, @params );
#
#Calls a $method on a plugin with id $pluginid. Passes @params to
#the method and returns whatever the method returns.
#
#=cut
#######################################################################
#
#sub call
#{
#	my( $pluginid, $methodid, @params ) = @_;
#
#	my $plugin = plugin( $pluginid );
#	
#	return $plugin->call( $methodid, @params );
#}

######################################################################
=pod

=item $plugin_conf = EPrints::Plugins::get_plugin_conf( $pluginid )

Return the system plugin with the given pluginid

=cut
######################################################################

sub get_plugin_conf
{
	my( $pluginid ) = @_;

	return $EPrints::Plugins::REGISTRY->{$pluginid};
}



1;

######################################################################
=pod

=back

=cut
######################################################################

