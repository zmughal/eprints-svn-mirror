######################################################################
#
# EPrints::MetaField::Year;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

EPrints::MetaField::Year - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Year;

use EPrints::MetaField::Int;
@ISA = qw( EPrints::MetaField::Int );

use strict;

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{maxlength} = 4; # Still running Perl in 10000?
	$defaults{regexp} = qr/\d{4}/;
	return %defaults;
}

sub should_reverse_order { return 1; }

######################################################################
1;

=back

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

