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

=item %defaults = EPrints::Plugin::defaults;

Return a hash of the default parameters for this plugin.

=cut
######################################################################

sub defaults
{
	return ();
}

1;

######################################################################
=pod

=back

=cut
######################################################################

