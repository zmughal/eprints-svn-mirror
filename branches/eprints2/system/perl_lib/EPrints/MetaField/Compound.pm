######################################################################
#
# EPrints::MetaField::Compound;
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

B<EPrints::MetaField::Compound> - Magic type of field which actually 
combines several other fields into a data structure.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Compound;

use strict;
use warnings;

BEGIN
{
	our( @ISA );
	
	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField::Text;

sub render_value
{
	my( $self, $session, $value, $alllangs, $nolink, $object ) = @_;

	if( defined $self->{render_value} )
	{
		return $self->call_property( "render_value",
			$session, 
			$self, 
			$value, 
			$alllangs, 
			$nolink );
	}

	my $table = $session->make_element( "table", border=>1 );
	foreach my $row ( @{$value} )
	{
		$table->appendChild( $self->render_single_value_row( $session, $row, $object ) );
	}
	return $table;
}

sub render_single_value_row
{
	my( $self, $session, $value, $object ) = @_;

	my $f = $self->get_property( "fields" );

	if( !defined $object ) { EPrints::abort( "Object not defined in Metafield Compound render_single_value_row!" ); }

	my $tr = $session->make_element( "tr" );
	foreach my $part_id ( sort keys %{$f} )
	{
		my $td = $session->make_element( "td" );
		$tr->appendChild( $td );
		my $field = $object->get_dataset->get_field( $f->{$part_id} );
		$td->appendChild( $field->render_single_value( $session, $value->{$part_id}, $object ) );
	}

	return $tr;
}

sub render_single_value
{
	my( $self, $session, $value, $object ) = @_;

	my $table = $session->make_element( "table", border=>1 );
	$table->appendChild( $self->render_single_value_row( $session, $value, $object ) );
	return $table;
}

# This type of field is virtual.
sub is_virtual
{
	my( $self ) = @_;

	return 1;
}

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return undef;
}


# Get the value of this field from the object. In this case this
# is quite complicated.
sub get_value
{
	my( $self, $object ) = @_;

	my $f = $self->get_property( "fields" );
	my $values = {};
	foreach my $part_id ( keys %{$f} )
	{
		$values->{$part_id} = $object->get_value_raw( $f->{$part_id} );
	}

	if( !$self->get_property( "multiple" ) )
	{
		return $values;
	}

	my $lists = {};
	my $len = 0;
	foreach my $part_id ( keys %{$f} )
	{
		$lists->{$part_id} = [];
		next unless defined $values->{$part_id};
		if( scalar @{$values->{$part_id}} > $len )
		{
			$len = scalar @{$values->{$part_id}};
		}
	}

	my $list = [];
	for( my $i=0; $i<$len; ++$i )
	{
		my $v = {};
		foreach my $part_id ( keys %{$f} )
		{
			next if( !defined $values->{$part_id} );
			next if( !defined $values->{$part_id}->[$i] );
			$v->{$part_id} = $values->{$part_id}->[$i];
		}
		push @{$list}, $v;
	}

	return $list;
}


sub set_value
{
	my( $self, $object, $value ) = @_;

	my $f = $self->get_property( "fields" );
	my $values = {};
	foreach my $part_id ( keys %{$f} )
	{
		$values->{$part_id} = [];
	}
	foreach my $row ( @{$value} )
	{
		foreach my $part_id ( keys %{$f} )
		{
			push @{$values->{$part_id}}, $row->{$part_id};
		}
	}
	foreach my $part_id ( keys %{$f} )
	{
		my $field = $object->get_dataset->get_field( $f->{$part_id} );
		$field->set_value( $object, $values->{$part_id} );
	}
}

# assumes all basic input elements are 1 high, x wide.
sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff, $object ) = @_;

	if( !defined $object ) { EPrints::abort( "Object not defined in Metafield Compound get_basic_input_elements!" ); }

	my $f = $self->get_property( "fields" );
	my $grid_row = [];

	foreach my $part_id ( keys %{$f} )
	{
		my $field = $object->get_dataset->get_field( $f->{$part_id} );
		my $part_grid = $field->get_basic_input_elements( $session, $value->{$part_id}, $suffix, $staff, $object );
		my $top_row = $part_grid->[0];
		push @{$grid_row}, @{$top_row};
	}

	return [ $grid_row ];
}

sub form_value_basic
{
	my( $self, $session, $suffix, $object ) = @_;
	
	if( !defined $object ) { EPrints::abort( "Object not defined in Metafield Compound form_value_basic!" ); }

	my $value = {};

	my $f = $self->get_property( "fields" );
	foreach my $part_id ( keys %{$f} )
	{
		my $field = $object->get_dataset->get_field( $f->{$part_id} );
		my $v = $field->form_value_basic( $session, $suffix, $object );
		$value->{$part_id} = $v;
	}

	return undef if( !EPrints::Utils::is_set( $value ) );

	return $value;
}


sub is_browsable
{
	return( 0 );
}


# don't index
sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{fields} = $EPrints::MetaField::REQUIRED;
	$defaults{export_as_xml} = 0;
	$defaults{text_index} = 0;
	return %defaults;
}

######################################################################

######################################################################
1;
