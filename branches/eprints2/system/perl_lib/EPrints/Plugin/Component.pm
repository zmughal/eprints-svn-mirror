
######################################################################
#
# EPrints::Component
#
######################################################################
#
#  This file is part of GNU EPrints 2.
#  
#  Copyright (c) 2000-2004 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 2 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 2 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 2; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################

=pod

=head1 NAME

B<EPrints::Component> - A single form component 

=cut

package EPrints::Plugin::Component;

# are these all needed?
use EPrints::Utils;
use EPrints::Session;
use EPrints::Subject;
use EPrints::Database;
use EPrints::SearchExpression;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Component::ABSTRACT = 1;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();
	$d{name} = "Base component plugin: This should have been subclassed";
	$d{type} = "component";
	$d{visible} = "all";
	return %d;
}

sub render
{
	my( $self, $defobj, %params ) = @_;
}

sub from_form
{
	my( $self, $modobj ) = @_;
}

sub validate
{
}

# all or ""
sub is_visible
{
	my( $plugin, $vis_level ) = @_;
	return( 1 ) unless( defined $vis_level );

	return( 0 ) unless( defined $plugin->{visible} );

	if( $vis_level eq "all" && $plugin->{visible} ne "all" ) {
		return 0;
	}

	return 1;
}

######################################################################
1;
