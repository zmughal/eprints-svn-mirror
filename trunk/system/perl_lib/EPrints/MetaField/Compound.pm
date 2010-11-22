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

use EPrints::MetaField;
@ISA = qw( EPrints::MetaField );

use strict;

sub new
{
	my( $class, %properties ) = @_;

	$properties{fields_cache} = [];

	my $self = $class->SUPER::new( %properties );

	my %seen;
	foreach my $inner_field ( @{$properties{fields}}, $self->extra_subfields )
	{
		if( !EPrints::Utils::is_set( $inner_field->{sub_name} ) )
		{
			EPrints->abort( "Sub fields of ".$self->dataset->id.".".$self->name." need the sub_name property to be set." );
		}
		if( $seen{$inner_field->{sub_name}}++ )
		{
			EPrints->abort( $self->dataset->id.".".$self->name." already contains a sub-field called '$inner_field->{sub_name}'" );
		}
		my $field = EPrints::MetaField->new( 
			show_in_html => 0, # don't show the inner field separately
		# these properties can be overriden
			export_as_xml => $properties{ "export_as_xml" },
			import => $properties{ "import" },
		# inner field's properties
			%{$inner_field},
			name => join('_', $self->name, $inner_field->{sub_name}),
		# these properties must be the same as the compound
			parent => $self,
			parent_name => $self->get_name(),
			dataset => $self->get_dataset(), 
			provenance => $self->get_property( "provenance" ),
			multiple => $properties{ "multiple" },
			volatile => $properties{ "volatile" } );

		# avoid circular references if we can
		Scalar::Utils::weaken( $field->{parent} )
			if defined &Scalar::Utils::weaken;

		push @{$self->{fields_cache}}, $field;
	}

	return $self;
}

=item @epdata = $field->extra_subfields()

Returns a list of sub-field definitions that will be added to this compound field.

This method should be overridden by sub-classes.

=cut

sub extra_subfields
{
	my( $self ) = @_;

	return ();
}

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

	if( $self->get_property( "multiple" ) )
	{
		foreach my $row ( @{$value} )
		{
			$table->appendChild( $self->render_single_value_row( $session, $row, $object ) );
		}
	}
	else
	{
		$table->appendChild( $self->render_single_value_row( $session, $value, $object ) );
	}
	return $table;
}

sub render_single_value_row
{
	my( $self, $session, $value, $object ) = @_;

	my $f = $self->get_property( "fields_cache" );

	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	my $tr = $session->make_element( "tr" );
	foreach my $field ( @{$f} )
	{
		my $name = $field->get_name;
		my $td = $session->make_element( "td" );
		$tr->appendChild( $td );
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

sub to_sax_basic
{
	my( $self, $value, %opts ) = @_;

	return if !EPrints::Utils::is_set( $value );

	my $f = $self->property( "fields_cache" );
	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	foreach my $field ( @{$f} )
	{
		next if !$field->property( "export_as_xml" );

		my $alias = $fieldname_to_alias{$field->name};
		my $v = $value->{$alias};
		# cause the sub-field to behave like it's a normal field
		local $field->{multiple} = 0;
		local $field->{parent_name};
		local $field->{name} = $field->{sub_name};
		$field->to_sax( $v, %opts );
	}
}

sub empty_value
{
	return {};
}

sub start_element
{
	my( $self, $data, $epdata, $state ) = @_;

	++$state->{depth};

	my %a_to_f = $self->get_alias_to_fieldname;

	# if we're inside a sub-field just call it
	if( defined(my $field = $state->{handler}) )
	{
		$field->start_element( $data, $epdata, $state->{$field} );
	}
	# or initialise all fields at <creators>
	elsif( $state->{depth} == 1 )
	{
		foreach my $field (@{$self->property( "fields_cache" )})
		{
			local $data->{LocalName} = $field->property( "sub_name" );
			$state->{$field} = {%$state,
				depth => 0,
			};
			$field->start_element( $data, $epdata, $state->{$field} );
		}
	}
	# add a new empty value for each sub-field at <item>
	elsif( $state->{depth} == 2 && $self->property( "multiple" ) )
	{
		foreach my $field (@{$self->property( "fields_cache" )})
		{
			$field->start_element( $data, $epdata, $state->{$field} );
		}
	}
	# otherwise we must be starting a new sub-field value
	else
	{
		$state->{handler} = $self->{dataset}->field( $a_to_f{$data->{LocalName}} );
	}
}

sub end_element
{
	my( $self, $data, $epdata, $state ) = @_;

	# finish all fields
	if( $state->{depth} == 1 )
	{
		my $value = $epdata->{$self->name} = $self->property( "multiple" ) ? [] : $self->empty_value;

		foreach my $field (@{$self->property( "fields_cache" )})
		{
			local $data->{LocalName} = $field->property( "sub_name" );
			$field->end_element( $data, $epdata, $state->{$field} );

			my $v = delete $epdata->{$field->name};
			if( ref($value) eq "ARRAY" )
			{
				foreach my $i (0..$#$v)
				{
					$value->[$i]->{$field->property( "sub_name" )} = $v->[$i];
				}
			}
			else
			{
				$value->{$field->property( "sub_name" )} = $v;
			}

			delete $state->{$field};
		}
	}
	# end a new <item> for every field
	elsif( $state->{depth} == 2 && $self->property( "multiple" ) )
	{
		foreach my $field (@{$self->property( "fields_cache" )})
		{
			$field->end_element( $data, $epdata, $state->{$field} );
		}
	}
	# end of a sub-field's content
	elsif( $state->{depth} == 2 || ($state->{depth} == 3 && $self->property( "multiple" )) )
	{
		delete $state->{handler};
	}
	# otherwise call the sub-field
	elsif( defined(my $field = $state->{handler}) )
	{
		$field->end_element( $data, $epdata, $state->{$field} );
	}

	--$state->{depth};
}

sub characters
{
	my( $self, $data, $epdata, $state ) = @_;

	if( defined(my $field = $state->{handler}) )
	{
		$field->characters( $data, $epdata, $state->{$field} );
	}
}

# This type of field is virtual.
sub is_virtual
{
	my( $self ) = @_;

	return 1;
}

sub get_sql_type
{
	my( $self, $session ) = @_;

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
	if( $self->get_property( "multiple" ) )
	{
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
	}
	else
	{
		foreach my $as ( keys %alias_to_fieldname )
		{
			$values->{$alias_to_fieldname{$as}} = $value->{$as};
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
	foreach my $field ( @{$f} )
	{
		my $fieldname = $field->get_name;
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

	my $f = $self->get_property( "fields_cache" );
	my $grid_row = [];

	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	foreach my $field ( @{$f} )
	{
		my $fieldname = $field->get_name;
		my $alias = $fieldname_to_alias{$fieldname};
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
	
	my $value = {};

	my $f = $self->get_property( "fields_cache" );
	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	foreach my $field ( @{$f} )
	{
		my $fieldname = $field->get_name;
		my $alias = $fieldname_to_alias{$fieldname};
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
	$defaults{export_as_xml} = 1;
	$defaults{text_index} = 0;
	return %defaults;
}

sub get_xml_schema_type
{
	my( $self ) = @_;

	return $self->get_property( "type" ) . "_" . $self->{dataset}->confid . "_" . $self->get_name;
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	my $type = $session->make_element( "xs:complexType", name => $self->get_xml_schema_type );

	my $sequence = $session->make_element( "xs:sequence" );
	$type->appendChild( $sequence );
	foreach my $field (@{$self->{fields_cache}})
	{
		my $name = $field->{sub_name};
		my $element = $session->make_element( "xs:element", name => $name, type => $field->get_xml_schema_type() );
		$sequence->appendChild( $element );
	}

	return $type;
}

sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	if( $match eq "EX" )
	{
		return EPrints::Search::Condition->new(
			'=',
			$dataset,
			$self,
			$self->get_value_from_id( $session, $search_value )
		);
	}

	EPrints::abort( "Attempt to search compound field. Repository ID=".$session->get_repository->get_id.", dataset=". $self->{dataset}->confid . ", field=" . $self->get_name );
}

# don't know how to turn a compound into a order value
sub ordervalue_single
{
	my( $self, $value, $session, $langid, $dataset ) = @_;

	return "";
}

sub get_value_from_id
{
	my( $self, $session, $id ) = @_;

	return {} if $id eq "NULL";

	my $value = {};

	my @parts = 
		map { URI::Escape::uri_unescape($_) }
		split /:/, $id, scalar(@{$self->property( "fields_cache" )});

	foreach my $field (@{$self->property( "fields_cache" )})
	{
		my $v = $field->get_value_from_id( $session, shift @parts );
		$value->{$field->property( "sub_name" )} = $v;
	}

	return $value;
}

sub get_id_from_value
{
	my( $self, $session, $value ) = @_;

	return "NULL" if !defined $value;

	my @parts;
	foreach my $field (@{$self->property( "fields_cache" )})
	{
		push @parts, $field->get_id_from_value(
			$session,
			$value->{$field->property( "sub_name" )}
		);
	}

	return join(":",
		map { URI::Escape::uri_escape($_, ":%") }
		@parts);
}

######################################################################

######################################################################
1;
