######################################################################
#
# EPrints::MetaField::Secret;
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

B<EPrints::MetaField::Secret> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Secret;

use strict;
use warnings;

BEGIN
{
	our( @ISA );
	
	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

sub get_sql_index
{
	my( $self ) = @_;

	return undef;
}


sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;

	return $session->make_text( "????" );
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff, $obj ) = @_;

	my $maxlength = $self->get_max_input_size;
	my $size = ( $maxlength > $self->{input_cols} ?
					$self->{input_cols} : 
					$maxlength );
	my $input = $session->make_element(
		"input",
		"accept-charset" => "utf-8",
		type => "password",
		name => $self->{name}.$suffix,
		value => $value,
		size => $size,
		maxlength => $maxlength );

	return [ [ { el=>$input } ] ];
}

sub is_browsable
{
	return( 0 );
}


sub from_search_form
{
	my( $self, $session, $prefix ) = @_;

	$session->get_archive()->log( "Attempt to search a \"secret\" type field." );

	return;
}

sub get_search_group { return 'secret'; }  #!! can't really search secret

# REALLY don't index passwords!
sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}

######################################################################

######################################################################
1;
