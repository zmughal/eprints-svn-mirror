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

EPrints::Plugins::load();

######################################################################
=pod

=item EPrints::Plugins::load()

Load all system plugins

=cut
######################################################################

sub load
{
	# no opts

	my $dir = $EPrints::SystemSettings::conf->{base_path}."/perl_lib/EPrints/Plugin";

	load_dir( $EPrints::Plugins::REGISTRY, $dir, "EPrints::Plugin" );
}


######################################################################
=pod

=item EPrints::Plugins::load_dir( $reg, $path, $baseclass, @prefix )

Load plugins in this directory and recurse through subdirectories.

$reg is a pointer to a hash to store the lost of found plugins in.

=cut
######################################################################

sub load_dir
{
	my( $reg, $path, $baseclass, @prefix ) = @_;

	my $dh;
	opendir( $dh, $path ) || die "Could not open $path";
	while( my $fn = readdir( $dh ) )
	{
		next if( $fn =~ m/^\./ );
		next if( $fn eq "CVS" );
		my $filename = "$path/$fn";
		if( -d $filename )
		{
			load_dir( $reg, $filename, $baseclass, @prefix, $fn );
			next;
		}

		next unless( $fn =~ s/\.pm// );
		my $class = $baseclass."::".join("::",@prefix,$fn );
		
		eval "use $class";

		no strict "refs";
		my $absvar = $class.'::ABSTRACT';
		my $abstract = ${$absvar};
		use strict "refs";
		next if( $abstract );
		my $pluginid = $class->id;

		$reg->{$pluginid} = $class;
	}
	closedir( $dh );

}




######################################################################
=pod

=item @plugin_ids  = EPrints::Plugins::plugin_list()

Return either a list of all the ids of the system plugins.

=cut
######################################################################

sub plugin_list
{
	my( $self ) = @_;

	return keys %{$EPrints::Plugins::REGISTRY};
}





1;

######################################################################
=pod

=back

=cut
######################################################################

