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

	my $table = $session->make_element( "table", border=>1, cellspacing=>0, cellpadding=>2 );
	my $tr = $session->make_element( "tr" );
	$table->appendChild( $tr );
	my $f = $self->get_property( "fields_cache" );
	foreach my $field_conf ( @{$f} )
	{
		my $fieldname = $field_conf->{name};
		my $field = $self->{dataset}->get_field( $fieldname );
		my $th = $session->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild( $field->render_name( $session ) );
	}

	foreach my $row ( @{$value} )
	{
		$table->appendChild( $self->render_single_value_row( $session, $row, $object ) );
	}
	return $table;
}

sub render_single_value_row
{
	my( $self, $session, $value, $object ) = @_;

	my $f = $self->get_property( "fields_cache" );

	if( !defined $object ) { EPrints::abort( "Object not defined in Metafield Compound render_single_value_row!" ); }

	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	my $tr = $session->make_element( "tr" );
	foreach my $field_conf ( @{$f} )
	{
		my $name = $field_conf->{name};
		my $td = $session->make_element( "td" );
		$tr->appendChild( $td );
		my $field = $object->get_dataset->get_field( $name );
		$td->appendChild( 
			$field->render_single_value( 
				$session, 
				$value->{$fieldname_to_alias{$name}}, 
				$object ) );
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

sub get_alias_to_fieldname
{
	my( $self ) = @_;

	my %addr = ();

	my $f = $self->get_property( "fields_cache" );
	foreach my $sub_field ( @{$f} )
	{
		$addr{$sub_field->{sub_name}} = $sub_field->{name};
	}

	return %addr;
}

sub get_fieldname_to_alias
{
	my( $self ) = @_;

	my %addr = $self->get_alias_to_fieldname;
	my %raddr = ();
	foreach( keys %addr )
	{
		$raddr{$addr{$_}} = $_;
	}
	return %raddr;
}

# Get the value of this field from the object. In this case this
# is quite complicated.
sub get_value
{
	my( $self, $object ) = @_;

	my $values = {};
	my %alias_to_fieldname = $self->get_alias_to_fieldname;
	foreach my $as ( keys %alias_to_fieldname )
	{
		$values->{$as} = $object->get_value_raw( $alias_to_fieldname{$as} );
	}

	if( !$self->get_property( "multiple" ) )
	{
		return $values;
	}

	my $lists = {};
	my $len = 0;
	foreach my $as ( keys %alias_to_fieldname )
	{
		$lists->{$as} = [];
		next unless defined $values->{$as};
		if( scalar @{$values->{$as}} > $len )
		{
			$len = scalar @{$values->{$as}};
		}
	}

	my $list = [];
	for( my $i=0; $i<$len; ++$i )
	{
		my $v = {};
		foreach my $as ( keys %alias_to_fieldname )
		{
			next if( !defined $values->{$as} );
			next if( !defined $values->{$as}->[$i] );
			$v->{$as} = $values->{$as}->[$i];
		}
		push @{$list}, $v;
	}

	return $list;
}


sub set_value
{
	my( $self, $object, $value ) = @_;

	my %alias_to_fieldname = $self->get_alias_to_fieldname;
	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	my $f = $self->get_property( "fields_cache" );
	my $values = {};
	foreach my $as ( keys %alias_to_fieldname )
	{
		$values->{$as} = [];
	}
	foreach my $row ( @{$value} )
	{
		foreach my $as ( keys %alias_to_fieldname )
		{
			push @{$values->{$alias_to_fieldname{$as}}}, $row->{$as};
		}
	}
	foreach my $fieldname ( keys %fieldname_to_alias )
	{
		my $field = $object->get_dataset->get_field( $fieldname );
		$field->set_value( $object, $values->{$fieldname} );
	}
}

sub get_input_col_titles
{
	my( $self, $session, $staff ) = @_;

	my @r  = ();
	my $f = $self->get_property( "fields_cache" );
	foreach my $field_conf ( @{$f} )
	{
		my $fieldname = $field_conf->{name};
		my $field = $self->{dataset}->get_field( $fieldname );
		my $sub_r = $field->get_input_col_titles( $session, $staff );

		if( !defined $sub_r )
		{
			$sub_r = [ $field->render_name( $session ) ];
		}

		push @r, @{$sub_r};
	}
	
	return \@r;
}

# assumes all basic input elements are 1 high, x wide.
sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $object ) = @_;

	if( !defined $object ) { EPrints::abort( "Object not defined in Metafield Compound get_basic_input_elements!" ); }

	my $f = $self->get_property( "fields_cache" );
	my $grid_row = [];

	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	foreach my $field_conf ( @{$f} )
	{
		my $fieldname = $field_conf->{name};
		my $alias = $fieldname_to_alias{$fieldname};
		my $field = $object->get_dataset->get_field( $fieldname );
		my $part_grid = $field->get_basic_input_elements( 
					$session, 
					$value->{$fieldname_to_alias{$fieldname}}, 
					$basename."_".$alias, 
					$staff, 
					$object );
		my $top_row = $part_grid->[0];
		push @{$grid_row}, @{$top_row};
	}

	return [ $grid_row ];
}

sub get_basic_input_ids
{
	my( $self, $session, $basename, $staff, $obj ) = @_;

	my @ids = ();

	my $f = $self->get_property( "fields_cache" );
	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	foreach my $field_conf ( @{$f} )
	{
		my $fieldname = $field_conf->{name};
		my $alias = $fieldname_to_alias{$fieldname};
		my $field = $obj->get_dataset->get_field( $fieldname );
		push @ids, $field->get_basic_input_ids( 
					$session, 
					$basename."_".$alias, 
					$staff, 
					$obj );
	}

	return( @ids );
}


sub form_value_basic
{
	my( $self, $session, $basename, $object ) = @_;
	
	if( !defined $object ) { EPrints::abort( "Object not defined in Metafield Compound form_value_basic!" ); }

	my $value = {};

	my $f = $self->get_property( "fields_cache" );
	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	foreach my $field_conf ( @{$f} )
	{
		my $fieldname = $field_conf->{name};
		my $alias = $fieldname_to_alias{$fieldname};
		my $field = $object->get_dataset->get_field( $fieldname );
		my $v = $field->form_value_basic( $session, $basename."_".$alias, $object );
		$value->{$alias} = $v;
	}

	return undef if( !EPrints::Utils::is_set( $value ) );

	return $value;
}

sub validate
{
	my( $self, $session, $value, $object ) = @_;

	my $f = $self->get_property( "fields_cache" );
	my @problems;
	foreach my $field_conf ( @{$f} )
	{
		push @problems, $object->validate_field( $field_conf->{name} );
	}
	return @problems;
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
	$defaults{fields_cache} = $EPrints::MetaField::REQUIRED;
	$defaults{show_in_fieldlist} = 0;
	$defaults{export_as_xml} = 0;
	$defaults{text_index} = 0;
	return %defaults;
}

######################################################################

######################################################################
1;
