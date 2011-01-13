######################################################################
#
# EPrints::MetaField::Id;
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

B<EPrints::MetaField::Id> - an identifier string

=head1 DESCRIPTION

Use Id fields whenever you are storing textual data that needs to be matched exactly (e.g. filenames).

Characters that are not valid XML 1.0 code-points will be replaced with the Unicode replacement character.

=over 4

=cut

package EPrints::MetaField::Id;

use EPrints::MetaField;

@ISA = qw( EPrints::MetaField );

use strict;

######################################################################
=pod

=item $val = $field->value_from_sql_row( $session, $row )

Shift and return the utf8 value of this field from the database input $row.

=cut
######################################################################

sub value_from_sql_row
{
	my( $self, $session, $row ) = @_;

	if( ref($session->{database}) eq "EPrints::Database::mysql" )
	{
		utf8::decode( $row->[0] );
	}

	return shift @$row;
}

=item @row = $field->sql_row_from_value( $session, $value )

Returns the value as an appropriate value for the database.

Replaces invalid XML 1.0 code points with the Unicode substitution character (0xfffd), see http://www.w3.org/International/questions/qa-controls

Values are truncated if they are longer than maxlength.

=cut

sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	return( undef ) if !defined $value;

	$value =~ s/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/\x{fffd}/g;
	
	$value = substr( $value, 0, $self->{ "maxlength" } );

	return( $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	return(
		$self->SUPER::get_property_defaults,
		match => "EX",
		merge => "ALL",
	);
}

# id fields are searched whole, whether against the main table or in the index
sub get_index_codes_basic
{
       my( $self, $session, $value ) = @_;

       return( $value, [], [] );
}

######################################################################
1;
