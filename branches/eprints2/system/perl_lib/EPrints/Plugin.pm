######################################################################
#
# EPrints::Plugin
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

B<EPrints::Plugin> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

package EPrints::Plugin;

use strict;

######################################################################
=pod

=item $plugin = EPrints::Plugin->new( %params );

undocumented

=cut
######################################################################

sub new
{
	my( $class, %params ) = @_;

	my $self = EPrints::Utils::clone( \%params );
	bless $self, $class;

	my %d = $self->defaults;
	foreach( keys %d )
	{
		next if defined $self->{$_};
		$self->{$_} = $d{$_};
	}		

	return $self;
}

######################################################################
=pod

=item %defaults = EPrints::Plugin->defaults; [static]

Return a hash of the default parameters for this plugin.

=cut
######################################################################

sub defaults
{
	return ();
}

######################################################################
=pod

=item $value = EPrints::Plugin->param( $key )

Return the value of a parameter in the current plugin.

=cut
######################################################################

sub param
{
	my( $self, $key ) = @_;

	return $self->{$key};
}





######################################################################
# STATIC METHODS
######################################################################
=pod

=back

=head2 Static Methods

=over 4

=cut
######################################################################



use EPrints::Archive;
use EPrints::SystemSettings;
$EPrints::Plugin::REGISTRY = {};

EPrints::Plugin::load();

######################################################################
=pod

=item EPrints::Plugin::load() [static]

Load all system plugins 

=cut
######################################################################

sub load
{
	# no opts

	my $dir = $EPrints::SystemSettings::conf->{base_path}."/perl_lib/EPrints/Plugin";

	load_dir( $EPrints::Plugin::REGISTRY, $dir, "EPrints::Plugin" );
}


######################################################################
=pod

=item EPrints::Plugin::load_dir( $reg, $path, $baseclass, @prefix ) [static]

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
		
		eval "use $class;";
		if( $@ ne "" )
		{
			print STDERR "Error with plugin $class... $@\n";
			next;
		}

		no strict "refs";
		my $absvar = $class.'::ABSTRACT';
		my $abstract = ${$absvar};
		my %defaults = $class->defaults();
		use strict "refs";
		next if( $abstract );

		my $pluginid = $defaults{"id"};
		if( !defined $pluginid )
		{
			print STDERR "Warning: plugin $class has no ID set.\n";
			next;
		}
		$reg->{$pluginid} = $class;
	}
	closedir( $dh );

}




######################################################################
=pod

=item @plugin_ids  = EPrints::Plugin::plugin_list() [static]

Return either a list of all the ids of the system plugins.

=cut
######################################################################

sub plugin_list
{
	my( $self ) = @_;

	return keys %{$EPrints::Plugin::REGISTRY};
}





1;

######################################################################
=pod

=back

=cut
######################################################################

