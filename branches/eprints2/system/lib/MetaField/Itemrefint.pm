######################################################################
#
# EPrints::MetaField::Itemrefint;
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

B<EPrints::MetaField::Itemrefint> - Reference to an object with an "int" type of ID field.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Itemrefint;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Int );
}

use EPrints::MetaField::Int;

my $file = $EPrints::SystemSettings::conf->{base_path}.
		"/perl_lib/EPrints/MetaField/itemrefutils.pm";
unless (my $return = do $file) { 
	warn "couldn't parse $file: $@" if $@;
	warn "couldn't do $file: $!"    unless defined $return;
	warn "couldn't run $file"       unless $return;
}


######################################################################
1;
