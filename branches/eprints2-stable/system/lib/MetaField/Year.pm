######################################################################
#
# EPrints::MetaField::Year;
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

B<EPrints::MetaField::Year> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Year;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Int );
}

use EPrints::MetaField::Int;



# INHERIT: get_sql_type

# INHERIT: is_text_indexable

# INHERIT: render_single_value

sub get_digits
{
	return( 4 );
}

sub render_search_input
{
	my( $self, $session, $searchfield ) = @_;
	
	return $session->make_element( "input",
				"accept-charset" => "utf-8",
				name=>$searchfield->get_form_prefix,
				value=>$searchfield->get_value,
				size=>9,
				maxlength=>9 );
}

sub from_search_form
{
	my( $self, $session, $prefix ) = @_;

	my $val = $session->param( $prefix );
	return unless defined $val;

	if( $val =~ m/^(\d\d\d\d)?\-?(\d\d\d\d)?/ )
	{
		return( $val );
	}
			
	return( undef,undef,undef, $session->phrase( "lib/searchfield:year_err" ) );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{digits} = 4;
	return %defaults;
}


######################################################################
1;
