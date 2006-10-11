######################################################################
#
# EPrints::RequestWrapper
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
use Apache2; 
use Apache::RequestRec; 

our @ISA = ("Apache::RequestRec");

sub new
{
	my( $class , $real_request , $conf ) = @_;
	my $self = bless $real_request,"Apache::RequestRec";
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

