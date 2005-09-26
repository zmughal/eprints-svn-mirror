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

=item $plugin = EPrints::Plugin->new( $params, $session )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $params, $session ) = @_;

	my $self = EPrints::Utils::clone( $params );

	if( defined $params->{parent} )
	{
		my $parent = $session->plugin( $params->{parent} );

		foreach my $key ( keys %{$parent} )
		{
			next if defined $self->{$key};
			$self->{$key} = $parent->{$key};
		}
	}
	$self->{session} = $session;

	bless $self, $class;

	return $self;
}


######################################################################
=pod

=item $thing = $plugin->call( $methodid, @params )

Calls the named method of this plugin, passing the parameters and
returning what the method returns.

=cut
######################################################################

sub call
{
	my( $self, $methodid, @params ) = @_;

	my $method = $self->{$methodid};

	if( !defined $method )
	{
		# cjg bad warning code
		print STDERR "Unknown method on plugin ".$self->{id}.": $methodid\n";
		return undef;
	}

	return &{$method}( $self, @params );
}

1;

######################################################################
=pod

=back

=cut
######################################################################

