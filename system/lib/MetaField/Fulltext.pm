######################################################################
#
# EPrints::MetaField::Longtext;
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

B<EPrints::MetaField::Fulltext> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Fulltext;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

sub is_browsable
{
	return( 0 );
}

sub get_value
{
	my( $self, $object ) = @_;

	my @docs = $object->get_all_documents;
	my $r = [];
	foreach my $doc ( @docs )
	{
		my $text = $doc->get_text;
		push @{$r}, $text;
	}
	return $r;
}



######################################################################
1;
