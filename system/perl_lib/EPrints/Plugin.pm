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

	my $self = bless \%params, $class;

	if( !defined $self->{repository} )
	{
		$self->{repository} = $self->{session} 
	}
	$self->{session} = $self->{repository};

	if( !defined $self->{id} )
	{
		$class =~ /^(?:EPrints::Plugin::)?(.*)$/;
		$self->{id} = $1;
	}

	return $self;
}

######################################################################
=pod

=item $value = EPrints::Plugin->local_uri

Return a unique ID for this plugin as it relates to the current 
repository. This can be used to distinguish that XML import for 
different repositories may have minor differences.

This URL will not resolve to anything useful.

=cut
######################################################################

sub local_uri
{
	my( $self ) = @_;

	my $id = $self->{id};
	$id =~ s!::!/!g;
	return $self->{repository}->get_conf( "http_url" )."/#Plugin/".$id;
}

######################################################################
=pod

=item $value = EPrints::Plugin->global_uri

Return a unique ID for this plugin, but not just in this repository
but for any repository. This can be used for fuzzier tools which do
not care about the minor differences between EPrints repositories.

This URL will not resolve to anything useful.

=cut
######################################################################

sub global_uri
{
	my( $self ) = @_;

	my $id = $self->{id};
	$id =~ s!::!/!g;
	return "http://eprints.org/eprints3/#Plugin/".$id;
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

Return the type of this plugin. eg. Export

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

=item $msg = $plugin->error_message

Return the error message, if this plugin can't be used.

=cut
######################################################################

sub error_message
{
	my( $self ) = @_;

	return $self->{error};
}


######################################################################
=pod

=item $boolean = $plugin->broken

Return the value of a parameter in the current plugin.

=cut
######################################################################

sub broken
{
	my( $self ) = @_;

	return defined $self->{error};
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
=pod

=item $value = $plugin->param( $paramid )

Return the parameter with the given id. This uses the hard wired
parameter unless an override has been configured for this archive.

=cut
######################################################################

sub param 
{
	my( $self, $paramid ) = @_;

	my $pconf = $self->{repository}->get_conf( "plugins", $self->{id} );

	if( defined $pconf->{params} && exists $pconf->{params}->{$paramid} )
	{
		return $pconf->{params}->{$paramid};
	}

	return $self->{$paramid};
}

######################################################################
=pod

=item $phraseid = $plugin->html_phrase_id( $id )

Returns the fully-qualified phrase identifier for the $id phrase for this
plugin.

=cut
######################################################################

sub html_phrase_id 
{
	my( $self, $id ) = @_;

	my $base = "Plugin/".$self->{id};
	$base =~ s/::/\//g;

	return $base . ':' . $id;
}

######################################################################
=pod

=item $xhtml = $plugin->html_phrase( $id, %bits )

Return the phrase belonging to this plugin, with the given id.

Returns a DOM tree.

=cut
######################################################################

sub html_phrase 
{
	my( $self, $id, %bits ) = @_;

#	my $base = substr( caller(0), 9 );
	my $base = "Plugin/".$self->{id};
	$base =~ s/::/\//g;

	return $self->{repository}->html_phrase( $base.":".$id, %bits );
}

######################################################################
=item $url = $plugin->icon_url

Returns the relative URL to the icon for this plugin.

=cut
######################################################################

sub icon_url
{
	my( $self ) = @_;

	my $icon = $self->{repository}->get_conf( "plugins", $self->{id}, "icon" );
	if( !defined( $icon ) )
	{
		$icon = $self->{icon};
	}

	return undef if !defined $icon;

	my $url = $self->{repository}->get_url( path => "images", $icon );

	return $url;
}

######################################################################
=pod

=item $utf8 = $plugin->phrase( $id, %bits )

Return the phrase belonging to this plugin, with the given id.

Returns a utf-8 encoded string.

=cut
######################################################################

sub phrase 
{
	my( $self, $id, %bits ) = @_;

	#my $base = substr( caller(0), 9 );
	my $base = "Plugin/".$self->{id};
	$base =~ s/::/\//g;

	return $self->{repository}->phrase( $base.":".$id, %bits );
}


1;

######################################################################
=pod

=back

=cut
######################################################################

