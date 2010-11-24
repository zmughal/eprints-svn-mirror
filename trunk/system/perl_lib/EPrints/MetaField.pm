######################################################################
#
# EPrints::MetaField
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

=for Pod2Wiki

=head1 NAME

B<EPrints::MetaField> - A single metadata field.

=head1 DESCRIPTION

Theis object represents a single metadata field, not the value of
that field. A field belongs (usually) to a dataset and has a large
number of properties. Optional and required properties vary between 
types.

"type" is the most important property, it is the type of the metadata
field. For example: "text", "name" or "date".

A full description of metadata types and properties is in the eprints
documentation and will not be duplicated here.

=head1 PROPERTIES

=over 4

=item provenance => "core" or "config"

Indiciates where the field was initialised from. "core" fields are defined in L<DataObj> classes while "config" fields are defined in cfg.d files.

=item replace_core => 0

Normally any attempt to define two fields with the same name will fail. However, you can replace a core system field by specifying the "replace_core" property. This should be used very carefully!

=back

=head1 METHODS

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{confid}
#     The conf-id of the dataset to which this field belongs. If this
#     field is not part of a dataset then this is just a string used 
#     to find config info about this field. Most importantly the name
#     and other information from the phrase file.
#
#  $self->{repository}
#     The repository to which this field belongs.
#
# The rest of the instance variables are the properties of the field.
# The most important properties (which are always required) are:
#
#  $self->{name}
#     The name of this field.
#
#  $self->{type}
#     The type of this field.
#
######################################################################

package EPrints::MetaField;

use EPrints::Const qw( :metafield );

use strict;

use Text::Unidecode qw();

$EPrints::MetaField::VARCHAR_SIZE 	= 255;

$EPrints::MetaField::FROM_CONFIG = EP_PROPERTY_FROM_CONFIG;
$EPrints::MetaField::NO_CHANGE   = EP_PROPERTY_NO_CHANGE;
$EPrints::MetaField::REQUIRED    = EP_PROPERTY_REQUIRED;
$EPrints::MetaField::UNDEF       = EP_PROPERTY_UNDEF;

######################################################################
=pod

=item $field = EPrints::MetaField->new( %properties )

Create a new metafield. %properties is a hash of the properties of the 
field, with the addition of "dataset", or if "dataset" is not set then
"confid" and "repository" must be provided instead.

Some field types require certain properties to be explicitly set. See
the main documentation.

=cut
######################################################################

sub new
{
	my( $class, %properties ) = @_;

	# We'll inherit these from clone()
	delete $properties{".final"};
	delete $properties{"field_defaults"};

	###########################################
	#
	# Pre 2.4 compatibility 
	#

	# for when repository was called archive.
	if( defined $properties{archive} )
	{
		$properties{repository} = delete $properties{archive};
	}

	# end of 2.4
	###########################################

	# allow metafields to override new()
	my $realclass = "EPrints::MetaField::\u$properties{type}";
	if( $class ne $realclass )
	{
		if( !EPrints::Utils::require_if_exists( $realclass ) )
		{
			EPrints->abort( "couldn't parse $realclass: $@" );
		}
		return $realclass->new( %properties );
	}

	my $self = bless \%properties, $realclass;

	if( defined $properties{dataset} ) 
	{ 
		$self->{confid} = $properties{dataset}->{confid}; 
		$self->{repository} = $properties{dataset}->{repository};
	}

	if( !defined $self->{repository} )
	{
		EPrints->abort( "Tried to create a metafield without a dataset or an repository." );
	}

	my $repository = $self->{repository};

	if( defined &Scalar::Util::weaken )
	{
		Scalar::Util::weaken( $self->{dataset} );
		Scalar::Util::weaken( $self->{repository} );
	}

	my $field_defaults = $self->field_defaults;

	# warn of non-applicable parameters; handy for spotting
	# typos in the config file.
	foreach my $p_id (keys %$self)
	{
		next if $p_id eq "dataset";
		next if $p_id eq "repository";
		if( !exists $field_defaults->{$p_id} )
		{
			$self->{repository}->log( "Field '".$self->{dataset}->id.".".$self->{name}."' has invalid parameter:\n$p_id => $self->{$p_id}" );
		}
	}

	keys %{$field_defaults}; # Reset each position
	while(my( $p_id, $p_default ) = each %{$field_defaults})
	{
		next if defined $self->{$p_id};
		next if $p_default eq EP_PROPERTY_UNDEF;

		if( $p_default eq EP_PROPERTY_REQUIRED )
		{
			EPrints::abort( "Error in field property for ".$self->{dataset}->id.".".$self->{name}.": $p_id on a ".$self->{type}." metafield can't be undefined" );
		}
		elsif( $p_default ne EP_PROPERTY_NO_CHANGE )
		{
			$self->{$p_id} = $p_default;
		}
	}

	$self->{field_defaults} = $field_defaults;

	return $self;
}

=item $defaults = $field->field_defaults

Returns the default properties for this field as a hash reference.

=cut

sub field_defaults
{
	my( $self ) = @_;

	my $repository = $self->{repository};

	my $field_defaults = $repository->get_field_defaults( $self->{type} );
	return $field_defaults if defined $field_defaults;

	$field_defaults = {$self->get_property_defaults};
	while(my( $p_id, $p_default ) = each %$field_defaults)
	{
		next if !defined $p_default;
		next if $p_default ne EP_PROPERTY_FROM_CONFIG;
		$p_default = $repository->config( "field_defaults" )->{ $p_id };
		$p_default = EP_PROPERTY_UNDEF if !defined $p_default;
		$field_defaults->{$p_id} = $p_default;
	}
	$repository->set_field_defaults( $self->{type}, $field_defaults );

	return $field_defaults;
}

######################################################################
=pod

=item $field->final

This method tells the metafield that it is now read only. Any call to
set_property will produce a abort error.

=cut
######################################################################

sub final
{
	my( $self ) = @_;

	$self->{".final"} = 1;
}


######################################################################
=pod

=item $field->set_property( $property, $value )

Set the named property to the given value.

This should not be called on metafields unless they've been cloned
first.

This method will cause an abort error if the metafield is read only.

In these cases a cloned version of the field should be used.

=cut
######################################################################

sub set_property
{
	my( $self , $property , $value ) = @_;

	if( $self->{".final"} )
	{
		EPrints::abort( <<END );
Attempt to set property "$property" on a finalised metafield.
Field: $self->{name}, type: $self->{type}
END
	}

	if( !exists $self->{field_defaults}->{$property} )
	{
		EPrints::abort( <<END );
BAD METAFIELD get_property property name: "$property"
Field: $self->{name}, type: $self->{type}
END
	}

	if( defined $value )
	{
		$self->{$property} = $value;
		return;
	}

	if( $self->{field_defaults}->{$property} eq EP_PROPERTY_NO_CHANGE )
	{
		# don't set a default, just leave it alone
		return;
	}
	
	if( $self->{field_defaults}->{$property} eq EP_PROPERTY_REQUIRED )
	{
		EPrints::abort( "Error in field property for ".$self->{dataset}->id.".".$self->{name}.": $property on a ".$self->{type}." metafield can't be undefined" );
	}

	if( $self->{field_defaults}->{$property} eq EP_PROPERTY_UNDEF )
	{	
		$self->{$property} = undef;
		return;
	}

	$self->{$property} = $self->{field_defaults}->{$property};
}


######################################################################
=pod

=item $newfield = $field->clone

Clone the field, so the clone can be edited without affecting the
original. Does not deep copy properties which are references - these
should be set to new values, rather than the contents altered. Eg.
don't push to a cloned options list, replace it.

=cut
######################################################################

sub clone
{
	my( $self ) = @_;

	return EPrints::MetaField->new( %{$self} );
}


=item $repository = $field->repository

Return the L<EPrints::Repository> to which this field belongs.

=cut

sub repository
{
	my( $self ) = @_;
	return $self->{repository};
}

######################################################################
=pod

=item $dataset = $field->dataset

Return the L<EPrints::DataSet> to which this field belongs, or undef.

=cut
######################################################################

sub get_dataset { shift->dataset( @_ ) }
sub dataset
{
	my( $self ) = @_;
	return $self->{dataset};
}

######################################################################
=pod

=item $xhtml = $field->render_name

Render the name of this field as an XHTML object.

=cut
######################################################################

sub render_name
{
	my( $self ) = @_;

	if( defined $self->{title_xhtml} )
	{
		return $self->{title_xhtml};
	}
	my $phrasename = $self->{confid}."_fieldname_".$self->{name};

	return $self->repository->html_phrase( $phrasename );
}

######################################################################
=pod

=item $label = $field->display_name( $session )

DEPRECATED! Can't be removed because it's used in 2.2's default
ArchiveRenderConfig.pm

Return the UTF-8 encoded name of this field, in the language of
the $session.

=cut
######################################################################

sub display_name
{
	my( $self, $session ) = @_;

#	print STDERR "CALLED DEPRECATED FUNCTION EPrints::MetaField::display_name\n";

	my $phrasename = $self->{confid}."_fieldname_".$self->{name};

	return $session->phrase( $phrasename );
}


######################################################################
=pod

=item $xhtml = $field->render_help

Return the help information for a user inputing some data for this
field as an XHTML chunk.

=cut
######################################################################

sub render_help
{
	my( $self ) = @_;

	if( defined $self->{help_xhtml} )
	{
		return $self->{help_xhtml};
	}
	my $phrasename = $self->{confid}."_fieldhelp_".$self->{name};

	return $self->repository->html_phrase( $phrasename );
}


######################################################################
=pod

=item $xhtml = $field->render_input_field( $session, $value, [$dataset], [$staff], [$hidden_fields], $obj, [$basename] )

Return the XHTML of the fields for an form which will allow a user
to input metadata to this field. $value is the default value for
this field.

The actual function called may be overridden from the config.

=cut
######################################################################

sub render_input_field
{
	my( $self, $session, $value, $dataset, $staff, $hidden_fields, $obj, $basename ) = @_;

	if( defined $basename )
	{
		$basename = $basename."_".$self->{name};
	}
	else
	{
		$basename = $self->{name};
	}

	if( defined $self->{toform} )
	{
		$value = $self->call_property( "toform", $value, $session );
	}

	if( defined $self->{render_input} )
	{
		return $self->call_property( "render_input",
			$self,
			$session, 
			$value, 
			$dataset, 
			$staff,
			$hidden_fields,
			$obj,
			$basename );
	}

	return $self->render_input_field_actual( 
			$session, 
			$value, 
			$dataset, 
			$staff,
			$hidden_fields,
			$obj,
			$basename );
}


######################################################################
=pod

=item $value = $field->form_value( $session, $object, [$prefix] )

Get a value for this field from the CGI parameters, assuming that
the form contained the input fields for this metadata field.

=cut
######################################################################

sub form_value
{
	my( $self, $session, $object, $prefix ) = @_;

	my $basename;
	if( defined $prefix )
	{
		$basename = $prefix."_".$self->{name};
	}
	else
	{
		$basename = $self->{name};
	}

	my $value = $self->form_value_actual( $session, $object, $basename );

	if( defined $self->{fromform} )
	{
		$value = $self->call_property( "fromform", $value, $session, $object, $basename );
	}

	return $value;
}


######################################################################
=pod

=item $name = $field->name

Return the name of this field.

=cut
######################################################################

sub get_name { shift->name( @_ ) }
sub name
{
	my( $self ) = @_;
	return $self->{name};
}


######################################################################
=pod

=item $type = $field->type

Return the type of this field.

=cut
######################################################################

sub get_type { shift->type( @_ ) }
sub type
{
	my( $self ) = @_;
	return $self->{type};
}



######################################################################
=pod

=item $value = $field->property( $property )

Return the value of the given property.

Special note about "required" property: It only indicates if the
field is always required. You must query the dataset to check if
it is required for a specific type.

=cut
######################################################################

sub get_property { shift->property( @_ ) }
sub property
{
	my( $self, $property ) = @_;

	if( !exists $self->{field_defaults}->{$property} )
	{
		EPrints::abort( <<END );
BAD METAFIELD get_property property name: "$property"
Field: $self->{name}, type: $self->{type}
END
	}

	return( $self->{$property} ); 
} 


######################################################################
=pod

=item $boolean = $field->is_type( @typenames )

Return true if the type of this field is one of @typenames.

=cut
######################################################################

sub is_type
{
	my( $self , @typenames ) = @_;

	foreach( @typenames )
	{
		return 1 if( $self->{type} eq $_ );
	}
	return 0;
}





######################################################################
=pod

=item $xhtml = $field->render_value( $session, $value, [$alllangs], [$nolink], $object )

Render the given value of this given string as XHTML DOM. If $alllangs 
is true and this is a multilang field then render all language versions,
not just the current language (for editorial checking). If $nolink is
true then don't make this field a link, for example subject fields 
might otherwise link to the subject view page.

If render_value or render_single_value properties are set then these
control the rendering instead.

=cut
######################################################################

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
			$nolink,
			$object );
	}

	return $self->render_value_actual( $session, $value, $alllangs, $nolink, $object );
}

sub render_value_actual
{
	my( $self, $session, $value, $alllangs, $nolink, $object ) = @_;

	unless( EPrints::Utils::is_set( $value ) )
	{
		if( $self->{render_quiet} )
		{
			return $session->make_doc_fragment;
		}
		else
		{
			# maybe should just return nothing
			return $session->html_phrase( 
				"lib/metafield:unspecified",
				fieldname => $self->render_name( $session ) );
		}
	}

	unless( $self->get_property( "multiple" ) )
	{
		return $self->render_value_no_multiple( 
			$session, 
			$value, 
			$alllangs, 
			$nolink,
			$object );
	}

	my @rendered_values = ();

	my $first = 1;
	my $html = $session->make_doc_fragment();
	
	for(my $i=0; $i<scalar(@$value); ++$i )
	{
		my $sv = $value->[$i];
		unless( $i == 0 )
		{
			my $phrase = "lib/metafield:join_".$self->get_type;
			my $basephrase = $phrase;
			if( $i == 1 && $session->get_lang->has_phrase( 
						$basephrase.".first", $session ) ) 
			{ 
				$phrase = $basephrase.".first";
			}
			if( $i == scalar(@$value)-1 && 
					$session->get_lang->has_phrase( 
						$basephrase.".last", $session ) ) 
			{ 
				$phrase = $basephrase.".last";
			}
			$html->appendChild( $session->html_phrase( $phrase ) );
		}
		$html->appendChild( 
			$self->render_value_no_multiple( 
				$session, 
				$sv, 
				$alllangs, 
				$nolink,
				$object ) );
	}
	return $html;

}


######################################################################
=pod

=item $xhtml = $field->render_value_no_multiple( $session, $value, $alllangs, $nolink, $object )

Render the XHTML for a non-multiple value. Can be either a from
a non-multiple field, or a single value from a multiple field.

Usually just used internally.

=cut
######################################################################

sub render_value_no_multiple
{
	my( $self, $session, $value, $alllangs, $nolink, $object ) = @_;


	my $rendered = $self->render_value_withopts( $session, $value, $nolink, $object );

	if( !defined $self->{browse_link} || $nolink)
	{
		return $rendered;
	}

	my $url = $session->get_repository->get_conf(
			"http_url" );
	my $views = $session->get_repository->get_conf( "browse_views" );
	my $linkview;
	foreach my $view ( @{$views} )
	{
		if( $view->{id} eq $self->{browse_link} )
		{
			$linkview = $view;
		}
	}

	if( !defined $linkview )
	{
		$session->get_repository->log( "browse_link to view '".$self->{browse_link}."' not found for field '".$self->{name}."'\n" );
		return $rendered;
	}

	my $link_id = $self->get_id_from_value( $session, $value );

	if(
		(defined $linkview->{fields} && $linkview->{fields} =~ m/,/) ||
		(defined $linkview->{menus} && scalar(@{$linkview->{menus}}) > 1)
	  )
	{
		# has sub pages
		$url .= "/view/".$self->{browse_link}."/".
			EPrints::Utils::escape_filename( $link_id )."/";
	}
	else
	{
		# no sub pages
		$url .= "/view/".$self->{browse_link}."/".
			EPrints::Utils::escape_filename( $link_id ).
			".html";
	}

	my $a = $session->render_link( $url );
	$a->appendChild( $rendered );
	return $a;
}


######################################################################
=pod

=item $xhtml = $field->render_value_withopts( $session, $value, $nolink, $object )

Render a single value but adding the render_opts features.

This uses either the field specific render_single_value or, if one
is configured, the render_single_value specified in the config.

Usually just used internally.

=cut
######################################################################

sub render_value_withopts
{
	my( $self, $session, $value, $nolink, $object ) = @_;

	if( !EPrints::Utils::is_set( $value ) )
	{
		return $session->html_phrase( 
			"lib/metafield:unspecified",
			fieldname => $self->render_name( $session ) );
	}

	if( $self->{render_magicstop} )
	{
		# add a full stop if the vale does not end with ? ! or .
		$value =~ s/\s*$//;
		if( $value !~ m/[\?!\.]$/ )
		{
			$value .= '.';
		}
	}

	if( $self->{render_noreturn} )
	{
		# turn  all CR's and LF's to spaces
		$value =~ s/[\r\n]/ /g;
	}

	if( defined $self->{render_single_value} )
	{
		return $self->call_property( "render_single_value",
			$session, 
			$self, 
			$value,
			$object );
	}

	return $self->render_single_value( $session, $value, $object );
}


######################################################################
=pod

=item $out_list = $field->sort_values( $in_list, $langid )

Sorts the in_list into order, based on the "order values" of the 
values in the in_list. Assumes that the values are not a list of
multiple values. [ [], [], [] ], but rather a list of single values.

=cut
######################################################################

sub sort_values
{
	my( $self, $session, $in_list, $langid ) = @_;

	($in_list, $langid) = ($session, $in_list)
		if !UNIVERSAL::isa( $session, "EPrints::Repository" );

	my %ov;
	VALUE: for(@$in_list)
	{
		next if !defined $_;
		$ov{$_} = $self->ordervalue_single( $_, $self->{repository}, $langid );
	}

	my @out_list = sort { defined $a <=> defined $b || $ov{$a} cmp $ov{$b} } @$in_list;

	return \@out_list;
}


######################################################################
=pod

=item @values = $field->list_values( $value )

Return a list of every distinct value in this field. 

 - for simple fields: return ( $value )
 - for multiple fields: return @{$value}

This function is used by the item_matches method in Search.

=cut
######################################################################

sub list_values
{
	my( $self, $value ) = @_;

	if( !EPrints::Utils::is_set( $value ) )
	{
		return ();
	}

	if( $self->get_property( "multiple" ) )
	{
		return @{$value};
	}

	return $value;
}



######################################################################
=pod

=item $value = $field->most_local( $session, $value )

If this field is a multilang field then return the version of the 
value most useful for the language of the session. In order of
preference: The language of the session, the default language for
the repository, any language at all. If it is not a multilang field
then just return $value.

=cut
######################################################################

sub most_local
{
	my( $self, $session, $value ) = @_;

	my $bestvalue =  EPrints::Session::best_language( 
		$session->get_repository, $session->get_langid(), %{$value} );
	return $bestvalue;
}



######################################################################
=pod

=item $value2 = $field->call_property( $property, @args )

Call the method described by $property. Pass it the arguments and
return the result.

The property may contain either a code reference, or the scalar name
of a method.

=cut
######################################################################

sub call_property
{
	my( $self, $property, @args ) = @_;

	my $v = $self->{$property};

	return unless defined $v;

	if( ref( $v ) eq "CODE" || $v =~ m/::/ )
	{
		no strict 'refs';
		return &{$v}(@args);
	}	

	return $self->{repository}->call( $v, @args );
}

######################################################################
=pod

=item $val = $field->value_from_sql_row( $session, $row )

Shift and return the value of this field from the database input $row.

=cut
######################################################################

sub value_from_sql_row
{
	my( $self, $session, $row ) = @_;

	return shift @$row;
}

######################################################################
=pod

=item @row = $field->sql_row_from_value( $session, $value )

Return a list of values to insert into the database based on $value.

The values will normally be passed to L<DBI/bind_param>:

	$sth->bind_param( $idx, $row[0] )

If the value is an array ref it gets expanded:

	$sth->bind_param( $idx, @{$row[0]} )

This is necessary to support binding LOB data under various databases.

=cut
######################################################################

sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	return( $value );
}

######################################################################
=pod

=item %opts = $field->get_sql_properties( $session )

Map the relevant SQL properties for this field to options passed to L<EPrints::Database>::get_column_type().

=cut
######################################################################

sub get_sql_properties
{
	my( $self, $session ) = @_;

	return (
		index => $self->{ "sql_index" },
		langid => $self->{ "sql_langid" },
		sorted => $self->{ "sql_sorted" },
	);
}

######################################################################
=pod

=item @types = $field->get_sql_type( $session )

Return the SQL column types of this field, used for creating tables.

=cut
######################################################################

sub get_sql_type
{
	my( $self, $session ) = @_;

	my $database = $session->get_database;

	return $database->get_column_type(
		$self->get_sql_name,
		EPrints::Database::SQL_VARCHAR,
		!$self->get_property( "allow_null" ),
		$self->get_property( "maxlength" ),
		undef, # precision
		$self->get_sql_properties,
	);
}

######################################################################
=pod

=item $field = $field->create_ordervalues_field( $session [, $langid ] )

Return a new field object that this field can use to store order values, optionally for language $langid.

=cut
######################################################################

sub create_ordervalues_field
{
	my( $self, $session, $langid ) = @_;

	return EPrints::MetaField->new(
		repository => $session->get_repository,
		type => "longtext",
		name => $self->get_name,
		sql_sorted => 1,
		sql_langid => $langid,
	);
}

######################################################################
=pod

=item $sql = $field->get_sql_index

Return the columns that an index should be created over.

=cut
######################################################################

sub get_sql_index
{
	my( $self ) = @_;
	
	return () unless( $self->get_property( "sql_index" ) );

	return $self->get_sql_names;
}




######################################################################
=pod

=item $xhtml_dom = $field->render_single_value( $session, $value )

Returns the XHTML representation of the value. The value will be
non-multiple. Just the  simple value.

=cut
######################################################################

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	return $session->make_text( $value );
}


######################################################################
=pod

=item $xhtml = $field->render_input_field_actual( $session, $value, [$dataset], [$staff], [$hidden_fields], [$obj], [$basename] )

Return the XHTML of the fields for an form which will allow a user
to input metadata to this field. $value is the default value for
this field.

Unlike render_input_field, this function does not use the render_input
property, even if it's set.

The $obj is the current state of the object this field is associated 
with, if any.

=cut
######################################################################

sub render_input_field_actual
{
	my( $self, $session, $value, $dataset, $staff, $hidden_fields, $obj, $basename ) = @_;


	my $elements = $self->get_input_elements( $session, $value, $staff, $obj, $basename );

	# if there's only one element then lets not bother making
	# a table to put it in

	if( scalar @{$elements} == 1 && scalar @{$elements->[0]} == 1 )
	{
		return $elements->[0]->[0]->{el};
	}

	my $table = $session->make_element( "table", border=>0, cellpadding=>0, cellspacing=>0, class=>"ep_form_input_grid" );

	my $col_titles = $self->get_input_col_titles( $session, $staff );
	if( defined $col_titles )
	{
		my $tr = $session->make_element( "tr" );
		my $th;
		my $x = 0;
		if( $self->get_property( "multiple" ) && $self->{input_ordered})
		{
			$th = $session->make_element( "th", class=>"empty_heading", id=>$basename."_th_".$x++ );
			$tr->appendChild( $th );
		}

		if( !defined $col_titles )
		{
			$th = $session->make_element( "th", class=>"empty_heading", id=>$basename."_th_".$x++ );
			$tr->appendChild( $th );
		}	
		else
		{
			foreach my $col_title ( @{$col_titles} )
			{
				$th = $session->make_element( "th", id=>$basename."_th_".$x++ );
				$th->appendChild( $col_title );
				$tr->appendChild( $th );
			}
		}
		$table->appendChild( $tr );
	}

	my $y = 0;
	foreach my $row ( @{$elements} )
	{
		my $x = 0;
		my $tr = $session->make_element( "tr" );
		foreach my $item ( @{$row} )
		{
			my %opts = ( valign=>"top", id=>$basename."_cell_".$x++."_".$y );
			foreach my $prop ( keys %{$item} )
			{
				next if( $prop eq "el" );
				$opts{$prop} = $item->{$prop};
			}	
			my $td = $session->make_element( "td", %opts );
			if( defined $item->{el} )
			{
				$td->appendChild( $item->{el} );
			}
			$tr->appendChild( $td );
		}
		$table->appendChild( $tr );
		$y++;
	}

	return $table;
}

sub get_input_col_titles
{
	my( $self, $session, $staff ) = @_;
	return undef;
}


sub get_input_elements
{
	my( $self, $session, $value, $staff, $obj, $basename ) = @_;	

	my $assist;
	if( $self->{input_assist} )
	{
		$assist = $session->make_doc_fragment;
		$assist->appendChild( $session->render_internal_buttons(
			$self->{name}."_assist" => 
				$session->phrase( 
					"lib/metafield:assist" ) ) );
	}

	my $extra_params = "&dataset=".$self->{dataset}->id."&field=".$self->name;
	if( defined $obj )
	{
		$extra_params .= "&dataobj=".$obj->id;
	}
	if( defined $self->{input_lookup_params} ) 
	{
		$extra_params = "&".$self->{input_lookup_params};
	}

	unless( $self->get_property( "multiple" ) )
	{
		my $rows = $self->get_input_elements_single( 
				$session, 
				$value,
				$basename,
				$staff,
				$obj );
		if( defined $self->{input_advice_right} )
		{
			my $advice = $self->call_property( "input_advice_right", $session, $self, $value );
			my $row = pop @{$rows};
			push @{$row}, { el=>$advice };
			push @{$rows}, $row;
		}


		my $cols = scalar @{$rows->[0]};
		if( defined $self->{input_lookup_url} )
		{
			my $n = length( $basename) - length( $self->{name}) - 1;
			my $componentid = substr( $basename, 0, $n );
			my $lookup = $session->make_doc_fragment;
			my $drop_div = $session->make_element( "div", id=>$basename."_drop", class=>"ep_drop_target" );
			$lookup->appendChild( $drop_div );
			my $drop_loading_div = $session->make_element( "div", id=>$basename."_drop_loading", class=>"ep_drop_loading", style=>"display: none" );
			$drop_loading_div->appendChild( $session->html_phrase( "lib/metafield:drop_loading" ) );
			$lookup->appendChild( $drop_loading_div );

			my @ids = $self->get_basic_input_ids($session, $basename, $staff, $obj );
			my @code;
			foreach my $id ( @ids )
			{	
				my @wcells = ( $id );
				push @code, 'ep_autocompleter( "'.$id.'", "'.$basename.'_drop", "'.$self->{input_lookup_url}.'", {relative: "'.$basename.'", component: "'.$componentid.'" }, [ $("'.join('"),$("',@wcells).'")], [], "'.$extra_params.'" );'."\n";
			}
			my $script = $session->make_javascript( join "", @code );
			$lookup->appendChild( $script );
			push @{$rows}, [ {el=>$lookup,colspan=>$cols,class=>"ep_form_input_grid_wide"} ];
		}
		if( defined $self->{input_advice_below} )
		{
			my $advice = $self->call_property( "input_advice_below", $session, $self, $value );
			push @{$rows}, [ {el=>$advice,colspan=>$cols,class=>"ep_form_input_grid_wide"} ];
		}

		if( defined $assist )
		{
			push @{$rows}, [ {el=>$assist,colspan=>3,class=>"ep_form_input_grid_wide"} ];
		}
		return $rows;
	}

	# multiple field...

	my $boxcount = $session->param( $basename."_spaces" );
	if( !defined $boxcount )
	{
		$boxcount = $self->{input_boxes};
	}
	$value = [] if( !defined $value );
	my $cnt = scalar @{$value};
	#cjg hack hack hack
	if( $boxcount<=$cnt )
	{
		if( $self->{name} eq "editperms" )
		{
			$boxcount = $cnt;
		}	
		else
		{
			$boxcount = $cnt+$self->{input_add_boxes};
		}
	}

	my $imagesurl = $session->get_repository->get_conf( "rel_path" )."/style/images";
	
	my $rows = [];
	for( my $i=1 ; $i<=$boxcount ; ++$i )
	{
		my $section = $self->get_input_elements_single( 
				$session, 
				$value->[$i-1], 
				$basename."_".$i,
				$staff,
				$obj );
		my $first = 1;
		for my $n (0..(scalar @{$section})-1)
		{
			my $row =  [  @{$section->[$n]} ];
			my $col1 = {};
			my $lastcol = {};
			if( $n == 0 && $self->{input_ordered})
			{
				$col1 = { el=>$session->make_text( $i.". " ), class=>"ep_form_input_grid_pos" };
				my $arrows = $session->make_doc_fragment;
				$arrows->appendChild( $session->make_element(
					"input",
					type=>"image",
					src=> "$imagesurl/multi_down.png",
					alt=>"down",
					title=>"move down",
               				name=>"_internal_".$basename."_down_$i",
					value=>"1" ));
				if( $i > 1 )
				{
					$arrows->appendChild( $session->make_text( " " ) );
					$arrows->appendChild( $session->make_element(
						"input",
						type=>"image",
						alt=>"up",
						title=>"move up",
						src=> "$imagesurl/multi_up.png",
                				name=>"_internal_".$basename."_up_$i",
						value=>"1" ));
				}
				$lastcol = { el=>$arrows, valign=>"middle", class=>"ep_form_input_grid_arrows" };
				$row =  [ $col1, @{$section->[$n]}, $lastcol ];
			}
			if( defined $self->{input_advice_right} )
			{
				my $advice = $self->call_property( "input_advice_right", $session, $self, $value->[$i-1] );
				push @{$row}, { el=>$advice };
			}
			push @{$rows}, $row;

			# additional rows
			my $y = scalar @{$rows}-1;
			my $cols = scalar @{$row};
			if( defined $self->{input_lookup_url} )
			{
				my $n = length( $basename) - length( $self->{name}) - 1;
				my $componentid = substr( $basename, 0, $n );
				my $ibasename = $basename."_".$i;
				my $lookup = $session->make_doc_fragment;
				my $drop_div = $session->make_element( "div", id=>$ibasename."_drop", class=>"ep_drop_target" );
				$lookup->appendChild( $drop_div );
				my $drop_loading_div = $session->make_element( "div", id=>$ibasename."_drop_loading", class=>"ep_drop_loading", style=>"display: none" );
				$drop_loading_div->appendChild( $session->html_phrase( "lib/metafield:drop_loading" ) );
				$lookup->appendChild( $drop_loading_div );
				my @ids = $self->get_basic_input_ids( $session, $ibasename, $staff, $obj );
				my @code;
				foreach my $id ( @ids )
				{	
					my @wcells = ();
					for( 1..scalar(@{$row})-2 ) { push @wcells, $basename."_cell_".$_."_".$y; }
					my @relfields = ();
					foreach ( @ids )
					{
						my $id2 = $_; # prevent changing it!
						$id2=~s/^$ibasename//;
						push @relfields, $id2;
					}
					push @code, 'ep_autocompleter( "'.$id.'", "'.$ibasename.'_drop", "'.$self->{input_lookup_url}.'", { relative: "'.$ibasename.'", component: "'.$componentid.'" }, [$("'.join('"),$("',@wcells).'")], [ "'.join('","',@relfields).'"],"'.$extra_params.'" );'."\n";
				}
				my $script = $session->make_javascript( join "", @code );
				$lookup->appendChild( $script );
				my @row = ();
				push @row, {} if( $self->{input_ordered} );
				push @row, {el=>$lookup,colspan=>$cols-1, class=>"ep_form_input_grid_wide"};
				push @{$rows}, \@row;
			#, {afterUpdateElement: updated}); " ));
			}
			if( defined $self->{input_advice_below} )
			{
				my $advice = $self->call_property( "input_advice_below", $session, $self, $value->[$i-1] );
				push @{$rows}, [ {},{el=>$advice,colspan=>$cols-1, class=>"ep_form_input_grid_wide"} ];
			}
		}
	}
	if ($self->{input_add_boxes} > 0)
	{
		my $more = $session->make_doc_fragment;
		$more->appendChild( $session->render_hidden_field(
					        $basename."_spaces",
						$boxcount ) );
		$more->appendChild( $session->render_internal_buttons(
        		$basename."_morespaces" => 
			        $session->phrase( 
				        "lib/metafield:more_spaces" ) ) );
		if( defined $assist )
		{
			$more->appendChild( $assist );
		}
		my @row = ();
		push @row, {} if( $self->{input_ordered} );
		push @row, {el=>$more,colspan=>3,class=>"ep_form_input_grid_wide"};
		push @{$rows}, \@row;
	}

	return $rows;
}

=item $bool = $field->has_internal_action( $basename )

Returns true if this field has an internal action.

=cut

sub has_internal_action
{
	my( $self, $basename ) = @_;

	if( defined $basename )
	{
		$basename .= "_" . $self->{name}
	}
	else
	{
		$basename = $self->{name};
	}

	my $ibutton = $self->{repository}->get_internal_button;
	return
		$ibutton eq "${basename}_morespaces" ||
		$ibutton =~ /^${basename}_(?:up|down)_\d+$/
	;
}

=item $params = $field->get_state_params( $repo, $basename )

Returns a query string "&foo=bar&x=y" of parameters this field needs to render the effect of an internal action correctly.

Returns "" if no parameters are required.

=cut

sub get_state_params
{
	my( $self, $session, $basename ) = @_;

	if( defined $basename )
	{
		$basename .= "_" . $self->{name}
	}
	else
	{
		$basename = $self->{name};
	}

	my $params = "";

	my $ibutton = $session->get_internal_button;
	if( $ibutton eq $basename."_morespaces" ) 
	{
		my $spaces = $session->param( $basename."_spaces" );
		$spaces += $self->{input_add_boxes};
		$params.= "&".$basename."_spaces=$spaces";
	}

	return $params;
}





sub get_input_elements_single
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	return $self->get_basic_input_elements( 
			$session, 
			$value, 
			$basename, 
			$staff,
			$obj );
}	



sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	my $maxlength = $self->get_max_input_size;
	my $size = ( $maxlength > $self->{input_cols} ?
					$self->{input_cols} : 
					$maxlength );


	my $input;
	if( defined $self->{render_input} )
	{
		$input = $self->call_property( "render_input",
			$self,
			$session, 
			$value, 
			$self->{dataset}, 
			$staff,
			undef,
			$obj,
			$basename );
	}
	else
	{
		$input = $session->render_noenter_input_field(
			class=>"ep_form_text",
			name => $basename,
			id => $basename,
			value => $value,
			size => $size,
			maxlength => $maxlength );
	}

	return [ [ { el=>$input } ] ];
}

# array of all the ids of input fields

sub get_basic_input_ids
{
	my( $self, $session, $basename, $staff, $obj ) = @_;

	return( $basename );
}

sub get_max_input_size
{
	my( $self ) = @_;

	return $self->get_property( "maxlength" );
}





######################################################################
# 
# $foo = $field->form_value_actual( $session, $object, $basename )
#
# undocumented
#
######################################################################

sub form_value_actual
{
	my( $self, $session, $object, $basename ) = @_;

	if( $self->get_property( "multiple" ) )
	{
		my @values = ();
		my $boxcount = $session->param( $basename."_spaces" );
		$boxcount = 1 if( $boxcount < 1 );
		for( my $i=1; $i<=$boxcount; ++$i )
		{
			my $value = $self->form_value_single( $session, $basename."_".$i, $object );
			next unless( EPrints::Utils::is_set( $value ) );
			push @values, $value;
		}
		if( scalar @values == 0 )
		{
			return undef;
		}
		my $ibutton = $session->get_internal_button;
		if( $ibutton =~ m/^${basename}_down_(\d+)$/ && $1 < @values )
		{
			@values[$1-1, $1] = @values[$1, $1-1];
		}
		elsif( $ibutton =~ m/^${basename}_up_(\d+)$/ && $1 > 1 )
		{
			@values[$1-1, $1-2] = @values[$1-2, $1-1];
		}
		return \@values;
	}

	return $self->form_value_single( $session, $basename, $object );
}

######################################################################
# 
# $foo = $field->form_value_single( $session, $n, $object )
#
# undocumented
#
######################################################################

sub form_value_single
{
	my( $self, $session, $basename, $object ) = @_;

	my $value = $self->form_value_basic( $session, $basename, $object );
	return undef unless( EPrints::Utils::is_set( $value ) );
	return $value;
}

######################################################################
# 
# $foo = $field->form_value_basic( $session, $basename, $object )
#
# undocumented
#
######################################################################

sub form_value_basic
{
	my( $self, $session, $basename, $object ) = @_;
	
	my $value = $session->param( $basename );

	return undef if( !EPrints::Utils::is_set( $value ) );

	# strip line breaks (turn them to "space")
	$value=~s/[\n\r]+/ /gs;

	return $value;
}

######################################################################
=pod

=item @sqlnames = $field->get_sql_names

Return the names of this field's columns as they appear in a SQL table.

=cut
######################################################################

sub get_sql_names
{
	my( $self ) = @_;

	return( $self->{name} );
}

# Utility/backwards compatibility
sub get_sql_name
{
	my( $self ) = @_;

	return $self->{ name };
}

######################################################################
=pod

=item $boolean = $field->is_browsable

Return true if this field can be "browsed". ie. Used as a view.

=cut
######################################################################

sub is_browsable
{
	return( 1 );
}


######################################################################
=pod

=item $values = $field->all_values( %opts )

Return a reference to an array of all the values of this field. 
For fields like "subject" or "set"
it returns all the variations. For fields like "text" return all 
the distinct values from the database.

Results are sorted according to the ordervalues of the current session.

=cut
######################################################################

sub all_values
{
	my( $self, %opts ) = @_;

	my $dataset = exists $opts{dataset} ? $opts{dataset} : $self->dataset;

	return $self->get_values( $self->repository, $dataset, %opts );
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

	return $self->sort_values( $unsorted_values, $langid );
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	return $session->get_database->get_values( $self, $dataset );
}

sub get_ids_by_value
{
	my( $self, $session, $dataset, %opts ) = @_;

	return $session->get_database->get_ids_by_field_values( $self, $dataset, %opts );
}

######################################################################
=pod

=item $id = $field->get_id_from_value( $session, $value )

Returns a key based on $value that can be used in a view.

E.g. if "render_res" is "year" then the key of "2005-03-02" would be "2005".

Returns "NULL" if $value is undefined.

=cut
######################################################################

sub get_id_from_value
{
	my( $self, $session, $value ) = @_;

	return defined($value) ? $value : "NULL";
}

######################################################################
=pod

=item $value = $field->get_value_from_id( $session, $id )

Returns the value from $id or undef if $id is "NULL".

=cut
######################################################################

sub get_value_from_id
{
	my( $self, $session, $id ) = @_;

	return $id eq "NULL" ? undef : $id;
}

######################################################################
=pod

=item $xhtml = $field->render_value_label( $value )

Return an XHTML DOM object describing the given value. Normally this
is just the value, but in the case of something like a "set" field 
this returns the name of the option in the current language.

=cut
######################################################################

sub render_value_label
{
	my( $self, $value ) = @_;
	return $self->get_value_label( $self->repository, $value );
}
sub get_value_label
{
	my( $self, $session, $value ) = @_;

	return $session->make_text( $value );
}



#	if( $self->is_type( "id" ) )
#	{
#		return $session->get_repository->call( 
#			"id_label", 
#			$self, 
#			$session, 
#			$value );
#	}


######################################################################
=pod

=item $ov = $field->ordervalue( $value, $session, $langid, $dataset )

Return a string representing this value which can be used to sort
it into order by comparing it alphabetically.

=cut
######################################################################

sub ordervalue
{
	my( $self , $value , $session , $langid , $dataset ) = @_;

	return "" if( !EPrints::Utils::is_set( $value ) );

	if( defined $self->{make_value_orderkey} )
	{
		no strict "refs";
		return $self->call_property( "make_value_orderkey",
			$self, 
			$value, 
			$session, 
			$langid,
			$dataset );
	}

	my $parent = $self->property( "parent" );
	if( $self->property( "multiple" ) && defined $parent && $parent->isa( "EPrints::MetaField::Multilang" ) )
	{
		my $langs = $parent->property( "languages" );

		my %values = map {
				$langs->[$_] => $value->[$_]
			} 0..$#$langs;
		$value = $session->best_language( $langid, %values );

		return $session->get_database->quote_ordervalue($self, $self->ordervalue_single( $value , $session , $langid, $dataset ));
	}

	if( !$self->get_property( "multiple" ) )
	{
		return $session->get_database->quote_ordervalue($self, $self->ordervalue_single( $value , $session , $langid, $dataset ));
	}

	my @r = ();	
	foreach( @$value )
	{
		push @r, $self->ordervalue_single( $_ , $session , $langid, $dataset );
	}
	return $session->get_database->quote_ordervalue($self, join( ":", @r ));
}


######################################################################
# 
# $ov = $field->ordervalue_single( $value, $session, $langid, $dataset )
# 
# undocumented
# 
######################################################################

sub ordervalue_single
{
	my( $self , $value , $session , $langid, $dataset ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	if( defined $self->{make_single_value_orderkey} )
	{
		return $self->call_property( "make_single_value_orderkey",
			$self, 
			$value, 
			$dataset ); 
	}

	return $self->ordervalue_basic( $value, $session, $langid );
}


######################################################################
# 
# $ov = $field->ordervalue_basic( $value )
# 
# undocumented
# 
######################################################################

sub ordervalue_basic
{
	my( $self, $value, $session, $langid ) = @_;

	return $value;
}

# XML output methods

sub to_xml
{
	my( $self, $value, %opts ) = @_;

	my $builder = EPrints::XML::SAX::Builder->new(
		repository => $self->{session}
	);
	$builder->start_document({});
	$builder->xml_decl({
		Version => '1.0',
		Encoding => 'utf-8',
	});
	$builder->start_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$self->to_sax( $value, %opts, Handler => $builder );

	$builder->end_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$builder->end_document({});

	return $builder->result()->documentElement;
}

sub to_sax
{
	my( $self, $value, %opts ) = @_;

	# MetaField::Compound relies on testing this specific attribute
	return if defined $self->{parent_name};

	return if !$opts{show_empty} && !EPrints::Utils::is_set( $value );

	my $handler = $opts{Handler};
	my $name = $self->name;

	$handler->start_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
		Attributes => {},
	});

	if( ref($value) eq "ARRAY" )
	{
		foreach my $v (@$value)
		{
			$handler->start_element( {
				Prefix => '',
				LocalName => "item",
				Name => "item",
				NamespaceURI => EPrints::Const::EP_NS_DATA,
				Attributes => {},
			});
			$self->to_sax_basic( $v, %opts );
			$handler->end_element( {
				Prefix => '',
				LocalName => "item",
				Name => "item",
				NamespaceURI => EPrints::Const::EP_NS_DATA,
			});
		}
	}
	else
	{
		$self->to_sax_basic( $value, %opts );
	}

	$handler->end_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
}

sub to_sax_basic
{
	my( $self, $value, %opts ) = @_;

	$opts{Handler}->characters( { Data => $value } );
}

sub empty_value
{
	return "";
}

sub start_element
{
	my( $self, $data, $epdata, $state ) = @_;

	++$state->{depth};

	if( $state->{depth} == 1 )
	{
		$epdata->{$self->name} = $self->property( "multiple" ) ? [] : $self->empty_value;
		$state->{in_value} = !$self->property( "multiple" );
	}
	elsif(
		$state->{depth} == 2 &&
		$self->property( "multiple" )
	  )
	{
		if( $data->{LocalName} eq "item" )
		{
			push @{$epdata->{$self->name}}, $self->empty_value;
			$state->{in_value} = 0;
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

	if( $state->{depth} == 1 || ($state->{depth} == 2 && $self->property( "multiple" )) )
	{
		$state->{in_value} = 0;
	}

	--$state->{depth};
}

sub characters
{
	my( $self, $data, $epdata, $state ) = @_;

	return if !$state->{in_value};

	my $value = $epdata->{$self->name};
	if( $state->{depth} == 2 ) # <foo><item>XXX
	{
		$value->[-1] .= $data->{Data};
	}
	elsif( $state->{depth} == 1 ) # <foo>XXX
	{
		$epdata->{$self->name} = $value . $data->{Data};
	}
}

sub render_xml_schema
{
	my( $self, $session ) = @_;

	my $element = $session->make_element( "xs:element", name => $self->get_name );

	my $phraseid = $self->{dataset}->confid . "_fieldname_" . $self->get_name;
	my $helpid = $self->{dataset}->confid . "_fieldhelp_" . $self->get_name;
	if( $session->get_lang->has_phrase( $phraseid, $session ) )
	{
		my $annotation = $session->make_element( "xs:annotation" );
		$element->appendChild( $annotation );
		my $documentation = $session->make_element( "xs:documentation" );
		$annotation->appendChild( $documentation );
		$documentation->appendChild( $session->make_text( "\n" ) );
		$documentation->appendChild( $session->make_text( $session->phrase( $phraseid ) ) );
		if( $session->get_lang->has_phrase( $helpid, $session ) )
		{
			$documentation->appendChild( $session->make_text( "\n\n" ) );
			$documentation->appendChild( $session->make_text( $session->phrase( $helpid ) ) );
		}
		$documentation->appendChild( $session->make_text( "\n" ) );
	}

	if( $self->get_property( "multiple" ) )
	{
		my $complexType = $session->make_element( "xs:complexType" );
		$element->appendChild( $complexType );
		my $sequence = $session->make_element( "xs:sequence" );
		$complexType->appendChild( $sequence );
		my $item = $session->make_element( "xs:element", name => "item", type => $self->get_xml_schema_type(), minOccurs => "0", maxOccurs => "unbounded" );
		$sequence->appendChild( $item );
	}
	else
	{
		$element->setAttribute( type => $self->get_xml_schema_type() );
	}

	if( !$self->get_property( "required" ) )
	{
		$element->setAttribute( minOccurs => 0 );
	}

	return $element;
}

sub get_xml_schema_type
{
	my( $self ) = @_;

	return $self->get_property( "type" );
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	my $type = $session->make_element( "xs:simpleType", name => $self->get_xml_schema_type );

	my $restriction = $session->make_element( "xs:restriction", base => "xs:string" );
	$type->appendChild( $restriction );
	my $length = $session->make_element( "xs:maxLength", value => $self->get_max_input_size );
	$restriction->appendChild( $length );

	return $type;
}

sub render_search_input
{
	my( $self, $session, $searchfield ) = @_;
	
	my $frag = $session->make_doc_fragment;

	# complex text types
	my @text_tags = ( "ALL", "ANY" );
	my %text_labels = ( 
		"ANY" => $session->phrase( "lib/searchfield:text_any" ),
		"ALL" => $session->phrase( "lib/searchfield:text_all" ) );
	$frag->appendChild( 
		$session->render_option_list(
			name=>$searchfield->get_form_prefix."_merge",
			values=>\@text_tags,
			default=>$searchfield->get_merge,
			labels=>\%text_labels ) );
	$frag->appendChild( $session->make_text(" ") );
	$frag->appendChild(
		$session->render_input_field(
			class => "ep_form_text",
			type => "text",
			name => $searchfield->get_form_prefix,
			value => $searchfield->get_value,
			size => $self->get_property( "search_cols" ),
			maxlength => 256 ) );
	my $match = $searchfield->get_match;
	if( defined $match && $match ne $self->default_web_search_match_code )
	{
		$frag->appendChild(
			$session->xhtml->input_field( 
				$searchfield->get_form_prefix."_match",
				$match,
				type => "hidden" ) );
	}
	return $frag;
}

sub default_web_search_match_code { return "IN"; }
sub default_web_search_merge_code { return "ALL"; }

sub from_search_form
{
	my( $self, $session, $basename ) = @_;

	# complex text types

	my $val = $session->param( $basename );
	return unless defined $val;

	my $search_type = $session->param( $basename."_merge" );
	my $search_match = $session->param( $basename."_match" );
		
	# Default search type if none supplied (to allow searches 
	# using simple HTTP GETs)
	$search_type = "ALL" unless defined( $search_type );
	$search_match = "IN" unless defined( $search_match );
		
	return unless( defined $val );

	return( $val, $search_type, $search_match );	
}		


sub render_search_description
{
	my( $self, $session, $sfname, $value, $merge, $match ) = @_;

	my( $phraseid );
	if( $match eq "EQ" || $match eq "EX" )
	{
		$phraseid = "lib/searchfield:desc_is";
	}
	elsif( $merge eq "ANY" ) # match = "IN"
	{
		$phraseid = "lib/searchfield:desc_any_in";
	}
	else
	{
		$phraseid = "lib/searchfield:desc_all_in";
	}

	my $valuedesc = $self->render_search_value(
		$session,
		$value );
	
	return $session->html_phrase(
		$phraseid,
		name => $sfname, 
		value => $valuedesc );
}

sub render_search_value
{
	my( $self, $session, $value ) = @_;

	return $session->make_text( '"'.$value.'"' );
}	

sub get_search_group { return 'basic'; } 


# return system defaults for this field type
sub get_property_defaults
{
	return (
		provenance => EP_PROPERTY_FROM_CONFIG,
		replace_core => EP_PROPERTY_FALSE,
		allow_null 	=> EP_PROPERTY_TRUE,
		browse_link 	=> EP_PROPERTY_UNDEF,
		can_clone 	=> EP_PROPERTY_TRUE,
		confid 		=> EP_PROPERTY_NO_CHANGE,
		export_as_xml 	=> EP_PROPERTY_TRUE,
		fromform 	=> EP_PROPERTY_UNDEF,
		import		=> EP_PROPERTY_TRUE,
		input_add_boxes => EP_PROPERTY_FROM_CONFIG,
		input_advice_right => EP_PROPERTY_UNDEF,
		input_advice_below => EP_PROPERTY_UNDEF,
		input_assist	=> EP_PROPERTY_FALSE,
		input_boxes 	=> EP_PROPERTY_FROM_CONFIG,
		input_cols 	=> EP_PROPERTY_FROM_CONFIG,
		input_lookup_url 	=> EP_PROPERTY_UNDEF,
		input_lookup_params 	=> EP_PROPERTY_UNDEF,
		input_ordered 	=> EP_PROPERTY_TRUE,
		make_single_value_orderkey 	=> EP_PROPERTY_UNDEF,
		make_value_orderkey 		=> EP_PROPERTY_UNDEF,
		show_in_fieldlist	=> EP_PROPERTY_TRUE,
		maxlength 	=> $EPrints::MetaField::VARCHAR_SIZE,
		multiple 	=> EP_PROPERTY_FALSE,
		name 		=> EP_PROPERTY_REQUIRED,
		show_in_html	=> EP_PROPERTY_TRUE,
		render_input 	=> EP_PROPERTY_UNDEF,
		render_single_value 	=> EP_PROPERTY_UNDEF,
		render_quiet	=> EP_PROPERTY_FALSE,
		render_magicstop	=> EP_PROPERTY_FALSE,
		render_noreturn	=> EP_PROPERTY_FALSE,
		render_dont_link	=> EP_PROPERTY_FALSE,
		render_value 	=> EP_PROPERTY_UNDEF,
		required 	=> EP_PROPERTY_FALSE,
		requiredlangs 	=> [],
		search_cols 	=> EP_PROPERTY_FROM_CONFIG,
		sql_index 	=> EP_PROPERTY_TRUE,
		sql_langid 	=> EP_PROPERTY_UNDEF,
		sql_sorted	=> EP_PROPERTY_FALSE,
		text_index 	=> EP_PROPERTY_FALSE,
		toform 		=> EP_PROPERTY_UNDEF,
		type 		=> EP_PROPERTY_REQUIRED,
		sub_name	=> EP_PROPERTY_UNDEF,
		parent_name	=> EP_PROPERTY_UNDEF,
		parent		=> EP_PROPERTY_UNDEF,
		volatile	=> EP_PROPERTY_FALSE,
		virtual		=> EP_PROPERTY_FALSE,
		default_value => EP_PROPERTY_UNDEF,

		help_xhtml	=> EP_PROPERTY_UNDEF,
		title_xhtml	=> EP_PROPERTY_UNDEF,
		join_path	=> EP_PROPERTY_UNDEF,
);
}

=item $value = $field->get_default_value( $session )

Return the default value for this field. This is only applicable to very simple
cases such as timestamps, auto-incremented values etc.

Any complex initialisation should be done in the "set_eprint_automatic_fields"
callback (or the equivalent for the given object).

=cut

sub get_default_value
{
	my( $self, $session ) = @_;

	return $self->get_property( "default_value" );
}

=item ( $terms, $grep_terms, $ignored ) = $field->get_index_codes( $session, $value )

Get indexable terms from $value. $terms is a reference to an array of strings to index. $grep_terms is a reference to an array of terms to add to the grep index. $ignored is a reference to an array of terms that should be ignored (e.g. stop words in a free-text field).

=cut

sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	if( !$self->get_property( "multiple" ) )
	{
		return $self->get_index_codes_basic( $session, $value );
	}
	my( $codes, $grepcodes, $ignored ) = ( [], [], [] );
	foreach my $v (@{$value} )
	{		
		my( $c,$g,$i ) = $self->get_index_codes_basic( $session, $v );
		push @{$codes},@{$c};
		push @{$grepcodes},@{$g};
		push @{$ignored},@{$i};
	}

	return( $codes, $grepcodes, $ignored );
}

sub get_index_codes_basic
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}

=item @terms = $field->split_search_value( $session, $value )

Split $value into terms that can be used to search against this field.

=cut

sub split_search_value
{
	my( $self, $session, $value ) = @_;

#	return EPrints::Index::split_words( 
#			$session,
#			EPrints::Index::apply_mapping( $session, $value ) );

	return split /\s+/, $value;
}

=item $cond = $field->get_search_conditions( $session, $dataset, $value, $match, $merge, $mode )

Return a L<Search::Condition> for $value based on this field.

=cut

sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	if( $match eq "EX" )
	{
		if( $search_value eq "" )
		{	
			return EPrints::Search::Condition->new( 
					'is_null', 
					$dataset, 
					$self );
		}

		return EPrints::Search::Condition->new( 
				'=', 
				$dataset, 
				$self, 
				$search_value );
	}

	return $self->get_search_conditions_not_ex(
			$session, 
			$dataset, 
			$search_value, 
			$match, 
			$merge, 
			$search_mode );
}

=item $cond = $field->get_search_conditions_not_ex( $session, $dataset, $value, $match, $merge, $mode )

Return the search condition for a search which is not-exact ($match ne "EX").

=cut

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	if( $match eq "EQ" )
	{
		return EPrints::Search::Condition->new( 
			'=', 
			$dataset,
			$self, 
			$search_value );
	}

	# free text!

	# apply stemming and stuff
	# codes, grep_terms, bad
	my( $codes, undef, undef ) = $self->get_index_codes( $session,
		$self->property( "multiple" ) ? [$search_value] : $search_value );

	# Just go "yeah" if stemming removed the word
	if( !EPrints::Utils::is_set( $codes->[0] ) )
	{
		return EPrints::Search::Condition->new( "PASS" );
	}

	if( $search_value =~ s/\*$// )
	{
		return EPrints::Search::Condition::IndexStart->new( 
				$dataset,
				$self, 
				$codes->[0] );
	}
	else
	{
		return EPrints::Search::Condition::Index->new( 
				$dataset,
				$self, 
				$codes->[0] );
	}
}

sub get_value
{
	my( $self, $object ) = @_;

	return $object->get_value_raw( $self->{name} );
}
sub set_value
{
	my( $self, $object, $value ) = @_;

	return $object->set_value_raw( $self->{name},$value );
}

# return true if this is a virtual field which does not exist in the
# database.
sub is_virtual
{
	my( $self ) = @_;
	return $self->{virtual};
}

# if ordering by this field, should we sort highest first?
sub should_reverse_order { return 0; }


=item @problems = $field->validate( $session, $value, $dataobj )

Returns an array of DOM problems with $value for this field.

=cut

sub validate
{
	my( $self, $session, $value, $object ) = @_;

	my @problems = $session->get_repository->call(
		"validate_field",
		$self,
		$value,
		$session );

	$self->{repository}->run_trigger( EPrints::Const::EP_TRIGGER_VALIDATE_FIELD(),
		field => $self,
		dataobj => $object,
		value => $value,
		problems => \@problems,
	);

	return @problems;
}



######################################################################

1;

=pod

=back

=cut

