######################################################################
#
# EPrints::RequestWrapper
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

B<EPrints::RequestWrapper> - Pretends to be an apache request.

=head1 DESCRIPTION

A EPrints::RequestWrapper is created from a real apache request and
a hash of "dir_config" options. It will pass all methods straight
through to the origional apache request except for dir_config()
which it will return its own config instead.

It's a hack used by EPrints::Auth - you really do not want to go
near it!

This is the version for use with Apache 1.3. EPrints::Auth will
pick which to use based on EPrints::SystemSettings 

=over 4

=cut



package EPrints::RequestWrapper;

use strict;
use Apache;


sub new
{
	my( $class , $real_request , $conf ) = @_;
	my $self ={};
	bless $self,$class;
	$self->{real_request} = $real_request;
	$self->{conf} = $conf;
	return $self;
}


sub dir_config 
{
	my( $self, $key ) = @_; 
	if( defined $self->{conf}->{$key} )
	{
		return $self->{conf}->{$key};
	}
	return $self->{real_request}->dir_config( $key ); 
}

my $thing;
foreach $thing ( keys %Apache:: )
{
	next if( $thing eq "new" || 
		 $thing eq "dir_config" ||
		 $thing eq "import" );
	my $sub = '';
	$sub.= 'sub '.$thing;
	$sub.= '{ ';
	$sub.= '   my( $self , @args ) = @_; ';
	$sub.= '   return $self->{real_request}->'.$thing.'( @args ); ';
	$sub.= '}';
	eval $sub;
}


1;
######################################################################
=pod

=back

=cut

