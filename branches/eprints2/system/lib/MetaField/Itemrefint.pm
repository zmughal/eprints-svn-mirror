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
require EPrints::MetaField::itemrefutils;


######################################################################
1;
