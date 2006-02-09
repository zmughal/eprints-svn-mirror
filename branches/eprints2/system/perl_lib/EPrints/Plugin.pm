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

B<EPrints::Plugin> - Base class of all EPrints Plugins

=head1 DESCRIPTION

This class provides the basic methods used by all EPrints Plugins.

=over 4

=cut

package EPrints::Plugin;

use strict;

######################################################################
=pod

=item $plugin = EPrints::Plugin->new( %params );

Create a new instance of a plugin with the given parameters.

=cut
######################################################################

sub new
{
	my( $class, %params ) = @_;

	my $self = EPrints::Utils::clone( \%params );
	bless $self, $class;

	$self->{id} = $class;
	$self->{id} =~ s/^EPrints::Plugin:://;
	$self->{id} =~ s/^EPrints::LocalPlugin::([^:]*):://;

	return $self;
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
=pod

=item $id = $plugin->get_id

Return the ID of this plugin.

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;

	return $self->{id};
}

######################################################################
=pod

=item $name = $plugin->get_name

Return the ID of this plugin.

=cut
######################################################################

sub get_name
{
	my( $self ) = @_;

	return $self->{name};
}

######################################################################
=pod

=item $name = $plugin->get_type

Return the type of this plugin. eg. Output

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	$self->{id} =~ m/^([^:]*)/;

	return $1;
}

######################################################################
=pod

=item $name = $plugin->get_subtype

Return the sub-type of this plugin. eg. BibTex

This is the ID with the type stripped from the front.

=cut
######################################################################

sub get_subtype
{
	my( $self ) = @_;

	$self->{id} =~ m/^[^:]*::(.*)/;

	return $1;
}

######################################################################
=pod

=item $name = $plugin->matches( $test, $param )

Return true if this plugin matches the test, false otherwise. If the
test is not known then return false.

=cut
######################################################################

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "type" )
	{
		my $l = length( $param );
		my $start = substr( $self->{id}, 0, $l );
		return( $start eq $param );
	}

	# didn't understand this match 
	return 0;
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
		next if( $fn eq ".svn" );
		my $filename = "$path/$fn";
		if( -d $filename )
		{
			load_dir( $reg, $filename, $baseclass, @prefix, $fn );
			next;
		}
		next unless( $fn =~ s/\.pm// );
		my $class = $baseclass."::".join("::",@prefix,$fn );
		#print STDERR "loading $class\n"; 
		my $return = eval "use $class";

		no strict "refs";
		my $absvar = $class.'::ABSTRACT';
		my $abstract = ${$absvar};
		my $plugin = $class->new();
		#my %defaults = $class->defaults();
		use strict "refs";
		next if( $abstract );

		my $pluginid = $plugin->{"id"};
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

