######################################################################
#
# EPrints::MetaField::Itemreftext;
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

B<EPrints::MetaField::Itemreftext> - Reference to an object with an "text" type of ID field.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Itemreftext;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;
require EPrints::MetaField::itemrefutils;


######################################################################
1;
