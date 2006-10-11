######################################################################
#
# EPrints::MetaField::Email;
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

B<EPrints::MetaField::Email> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Email;

use EPrints::Session;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

sub render_single_value
{
	my( $self, $value, $dont_link ) = trim_params(@_);
	
	my $text = &SESSION->make_text( $value );

	return $text if( $dont_link );

	my $a = &SESSION->render_link( "mailto:".$value );
	$a->appendChild( $text );
	return $a;
}

######################################################################
1;
