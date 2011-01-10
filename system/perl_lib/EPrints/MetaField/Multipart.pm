######################################################################
#
# EPrints::MetaField::Multipart;
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

B<EPrints::MetaField::Multipart> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Multipart;

use EPrints::MetaField;

@ISA = qw( EPrints::MetaField );

use strict;

sub new
{
	my( $class, %properties ) = @_;

	$properties{fields_cache} = [];
	$properties{fields_index} = {};

	my $self = $class->SUPER::new( %properties );

	foreach my $fconf (@{$self->property( "fields" )})
	{
		my $field = EPrints::MetaField->new(
				%$fconf,
				name => join('_', $self->name, $fconf->{sub_name}),
				repository => $self->{repository},
				dataset => $self->{dataset},
				parent => $self,
			);
		push @{$self->{fields_cache}}, $field;
		$self->{fields_index}->{$field->property( "sub_name" )} = $field;

		# avoid circular references if we can
		Scalar::Utils::weaken( $field->{parent} )
			if defined &Scalar::Utils::weaken;
	}

	return $self;
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{fields} = $EPrints::MetaField::REQUIRED;
	$defaults{fields_cache} = $EPrints::MetaField::REQUIRED;
	$defaults{fields_index} = {};
	return %defaults;
}

sub get_sql_names
{
	my( $self ) = @_;

	return map { $_->get_sql_names } @{$self->{fields_cache}};
}

sub value_from_sql_row
{
	my( $self, $session, $row ) = @_;

	my %value;

	for(@{$self->{fields_cache}})
	{
		$value{$_->property( "sub_name" )} =
			$_->value_from_sql_row( $session, $row );
	}

	return \%value;
}

sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	my @row;

	for(@{$self->{fields_cache}})
	{
		push @row,
			$_->sql_row_from_value( $session, $value->{$_->property( "sub_name" )} );
	}

	return @row;
}

sub get_sql_type
{
	my( $self, $session ) = @_;

	return map { $_->get_sql_type( $session ) } @{$self->{fields_cache}};
}

sub get_sql_index
{
	my( $self ) = @_;

	return () unless( $self->get_property( "sql_index" ) );

	return ($self->get_sql_names);
}
	
sub render_single_value
{
	my( $self, $session, $value ) = @_;

	no warnings; # suppress undef warnings
	return $session->make_text(join ', ', @{$value}{
		keys %{$self->{fields_index}}
	});
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	return $self->EPrints::MetaField::Compound::get_basic_input_elements(
		$session, $value, $basename, $staff, $obj
	);
}

sub get_basic_input_ids
{
	my( $self, $session, $basename, $staff, $obj ) = @_;

	my @ids;

	foreach my $field (@{$self->{fields_cache}})
	{
		push @ids, $field->get_basic_input_ids( $session, $basename, $staff, $obj );
	}

	return @ids;
}

sub get_input_col_titles
{
	my( $self, $session, $staff ) = @_;

	my @r;

	foreach my $field (@{$self->{fields_cache}})
	{
		push @r, $field->get_input_col_titles( $session, $staff );
	}

	return \@r;
}

sub form_value_basic
{
	my( $self, $session, $basename ) = @_;
	
	return $self->EPrints::MetaField::Compound::form_value_basic( $session, $basename );
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	return $self->render_single_value( $session, $value );
}

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	if( ref($value) ne "HASH" ) {
		EPrints::abort( "ordervalue_basic called on something other than a hash: $value" );
	}

	my @ov;
	foreach( @{$self->{fields_cache}} )
	{
		push @ov, $_->ordervalue_basic( $value->{$_->property( "sub_name" )} );
	}

	no warnings; # avoid undef warnings
	return join( "\t" , @ov );
}

sub split_search_value
{
	my( $self, $session, $value ) = @_;

	return $value;
}

sub render_search_value
{
	my( $self, $session, $value ) = @_;

	my @bits = $self->split_search_value( $session, $value );

	no warnings; # suppress undef warnings
	return $session->make_text( '"'.join( '", "', @bits).'"' );
}

sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge, $search_mode ) = @_;

	# we only know how to do a simple match
	return EPrints::Search::Condition->new(
		'=',
		$dataset,
		$self,
		$self->get_value_from_id( $session, $search_value )
	);
}

# INHERRITS get_search_conditions_not_ex, but it's not called.

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	return $session->get_database->get_values( $self, $dataset );
}

sub get_index_codes_basic
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}	

sub get_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $langid = $opts{langid};
	$langid = $session->get_langid unless( defined $langid );

	my $unsorted_values = $self->get_unsorted_values( 
		$session,
		$dataset,	
		%opts );

	my %orderkeys = ();
	my @values;
	foreach my $value ( @{$unsorted_values} )
	{
		my $v2 = $value;
		$v2 = {} unless( defined $value );
		push @values, $v2;

		# uses function _basic because value will NEVER be multiple
		my $orderkey = $self->ordervalue_basic(
			$value, 
			$session, 
			$langid );
		$orderkeys{$self->get_id_from_value($session, $v2)} = $orderkey;
	}

	my @outvalues = sort {$orderkeys{$self->get_id_from_value($session, $a)} cmp $orderkeys{$self->get_id_from_value($session, $b)}} @values;
	return \@outvalues;
}

sub get_id_from_value
{
	my( $self, $session, $value ) = @_;

	return "NULL" if !defined $value;

	return join(":",
		map { URI::Escape::uri_escape($_, ":%") }
		map { defined($_) ? $_ : "NULL" }
		map { $value->{$_->property( "sub_name" )} } @{$self->{fields_cache}}
	);
}

sub get_value_from_id
{
	my( $self, $session, $id ) = @_;

	return undef if $id eq "NULL";

	my %value;

	my @parts = split /:/, $id, scalar(@{$self->{fields_cache}});
	foreach my $field (@{$self->{fields_cache}})
	{
		my $part = shift @parts;
		$part = URI::Escape::uri_unescape( $part );
		next if $part eq "NULL";
		$value{$field->property( "sub_name" )} = $part;
	}

	return \%value;
}

sub to_sax_basic
{
	my( $self, $value, %opts ) = @_;

	return if !$opts{show_empty} && !EPrints::Utils::is_set( $value );

	my $handler = $opts{Handler};
	my $dataset = $self->dataset;
	my $name = $self->name;

	foreach my $field (@{$self->{fields_cache}})
	{
		my $alias = $field->property( "sub_name" );
		my $v = $value->{$alias};
		next unless EPrints::Utils::is_set( $v );
		$handler->start_element( {
			Prefix => '',
			LocalName => $alias,
			Name => $alias,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
			Attributes => {},
		});
		$self->SUPER::to_sax_basic( $v, %opts );
		$handler->end_element( {
			Prefix => '',
			LocalName => $alias,
			Name => $alias,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
		});
	}
}

sub empty_value
{
	return {};
}

sub start_element
{
	my( $self, $data, $epdata, $state ) = @_;

	$self->SUPER::start_element( $data, $epdata, $state );

	if(
		($state->{depth} == 2 && !$self->property( "multiple" )) ||
		($state->{depth} == 3 && $self->property( "multiple" ))
	  )
	{
		if( exists $self->{fields_index}->{$data->{LocalName}} )
		{
			$state->{alias} = $data->{LocalName};
		}
		else
		{
			$state->{Handler}->message( "warning", $self->repository->xml->create_text_node( "Invalid XML element: $data->{LocalName}" ) )
				if defined $state->{Handler};
		}
	}
}

sub end_element
{
	my( $self, $data, $epdata, $state ) = @_;

	if(
		($state->{depth} == 2 && !$self->property( "multiple" )) ||
		($state->{depth} == 3 && $self->property( "multiple" ))
	  )
	{
		delete $state->{alias};
	}

	$self->SUPER::end_element( $data, $epdata, $state );
}

sub characters
{
	my( $self, $data, $epdata, $state ) = @_;

	my $alias = $state->{alias};
	return if !defined $alias;

	my $value = $epdata->{$self->name};

	if( $state->{depth} == 3 ) # <name><item><family>XXX
	{
		$value->[-1]->{$alias} .= $data->{Data};
	}
	elsif( $state->{depth} == 2 ) # <name><family>XXX
	{
		$value->{$alias} .= $data->{Data};
	}
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	my $type = $session->make_element( "xs:complexType", name => $self->get_xml_schema_type );

	my $all = $session->make_element( "xs:all" );
	$type->appendChild( $all );
	foreach my $field (@{$self->{fields_cache}})
	{
		$all->appendChild( $field->render_xml_schema_type( $session ) );
	}

	return $type;
}



######################################################################
1;
