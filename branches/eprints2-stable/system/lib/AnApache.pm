######################################################################
#
# EPrints::AnApache
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

B<EPrints::AnApache> - Load appropriate Apache Module

=head1 DESCRIPTION

Handy way of loading Apache or Apache2 depending on value in SystemSettings.

Plus functions to paper over the cracks between the two interfaces.

=over 4

=cut
######################################################################

package EPrints::AnApache;

use strict;

BEGIN
{
	use Exporter;
	our (@ISA, @EXPORT );
	@ISA	 = qw(Exporter);
	@EXPORT  = qw( OK FORBIDDEN AUTH_REQUIRED DONE DECLINED NOT_FOUND );
}


use EPrints::SystemSettings;

my $av =  $EPrints::SystemSettings::conf->{apache};
if( defined $av && $av eq "2" )
{
	# Apache 2
	eval "require EPrints::RequestWrapper2"; if( $@ ) { die $@; }
	eval "require Apache::AuthDBI"; if( $@ ) { die $@; }
	eval "require ModPerl::Registry"; if( $@ ) { die $@; }
	eval "require Apache::Const;"; if( $@ ) { die $@; }
	$EPrints::AnApache::RequestWrapper = "EPrints::RequestWrapper2"; 
}
else
{
	# Apache 1.3
	eval "require EPrints::RequestWrapper"; if( $@ ) { die $@; }
	eval "require Apache::AuthDBI"; if( $@ ) { die $@; }
	eval "require Apache::Registry"; if( $@ ) { die $@; }
	eval "require Apache::Constants; import Apache::Constants qw( OK AUTH_REQUIRED FORBIDDEN DECLINED SERVER_ERROR DONE )"; if( $@ ) { die $@; }
	$EPrints::AnApache::RequestWrapper = "EPrints::RequestWrapper"; 
}


1;
