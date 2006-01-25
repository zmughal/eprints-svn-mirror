######################################################################
#
# EPrints::RequestWrapper2
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

B<EPrints::RequestWrapper2> - Pretends to be an apache 2.0 request.

=head1 DESCRIPTION

A EPrints::RequestWrapper2 is created from a real apache request and
a hash of "dir_config" options. It will pass all methods straight
through to the origional apache request except for dir_config()
which it will return its own config instead.

It's a hack used by EPrints::Auth - you really do not want to go
near it!

This is the version for use with Apache 2.0. EPrints::Auth will
pick which to use based on EPrints::SystemSettings 



=over 4

=cut


package EPrints::RequestWrapper2;
use strict;

BEGIN { 
	$EPrints::RequestWrapper2::BaseModule = "?";
	if( $EPrints::AnApache::ModPerlAPI == 1 )
	{
		$EPrints::RequestWrapper2::BaseModule = "Apache::RequestRec";
	}
	if( $EPrints::AnApache::ModPerlAPI == 2 )
	{
		$EPrints::RequestWrapper2::BaseModule = "Apache2::RequestRec";
	}

	eval "use $EPrints::RequestWrapper2::BaseModule;";
};
our @ISA = ($EPrints::RequestWrapper2::BaseModule);


sub new
{
	my( $class , $real_request , $conf ) = @_;
	my $self = bless $real_request,$EPrints::RequestWrapper2::BaseModule;
	foreach my $confkey (keys %$conf)
	{
		$self->SUPER::dir_config( $confkey => $conf->{$confkey} );
	}
	return $self;
}

1;
######################################################################
=pod

=back

=cut

