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

use strict;

use Unicode::String qw( utf8 );

$EPrints::MetaField::VARCHAR_SIZE 	= 255;
# get the default value from field defaults in the config
$EPrints::MetaField::FROM_CONFIG 	= "272b7aa107d30cfa9c67c4bdfca7005d_FROM_CONFIG";
# don't use a default, the code may have already set this value. setting it to undef
# has no effect rather than setting it to default value.
$EPrints::MetaField::NO_CHANGE	 	= "272b7aa107d30cfa9c67c4bdfca7005d_NO_CHANGE";
# this field must be explicitly set
$EPrints::MetaField::REQUIRED 		= "272b7aa107d30cfa9c67c4bdfca7005d_REQUIRED";
# this field defaults to undef
$EPrints::MetaField::UNDEF 		= "272b7aa107d30cfa9c67c4bdfca7005d_UNDEF";

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

	my $realclass = "EPrints::MetaField::\u$properties{type}";
	eval 'use '.$realclass.';';
	warn "couldn't parse $realclass: $@" if $@;

	###########################################
	#
	# Pre 2.4 compatibility 
	#

	# for when repository was called archive.
	if( defined $properties{archive} )
	{
		$properties{repository} = $properties{archive};
	}

	# end of 2.4
	###########################################

	my $self = {};
	bless $self, $realclass;

	$self->{confid} = $properties{confid};

	if( defined $properties{dataset} ) 
	{ 
		$self->{confid} = $properties{dataset}->confid(); 
		$self->{dataset} = $properties{dataset};
		$self->{repository} = $properties{dataset}->get_repository;
	}
	else
	{
		if( !defined $properties{repository} )
		{
			EPrints::Config::abort( 
				"Tried to create a metafield without a ".
				"dataset or an repository." );
		}
		$self->{repository} = $properties{repository};
	}

	# This gets reset later, but we need it for potential
	# debug messages.
	$self->{type} = $properties{type};
	
	$self->{field_defaults} = $self->{repository}->get_field_defaults( $properties{type} );
	if( !defined $self->{field_defaults} )
	{
		my %props = $self->get_property_defaults;
		$self->{field_defaults} = {};
		foreach my $p_id ( keys %props )
		{
			if( defined $props{$p_id} && $props{$p_id} eq $EPrints::MetaField::FROM_CONFIG )
			{
				my $v = $self->{repository}->get_conf( "field_defaults" )->{$p_id};
				if( !defined $v )
				{
					$v = $EPrints::MetaField::UNDEF;
				}
				$props{$p_id} = $v;
			}
			$self->{field_defaults}->{$p_id} = $props{$p_id};
		}
		$self->{repository}->set_field_defaults( $properties{type}, $self->{field_defaults} );
	}

	foreach my $p_id ( keys %{$self->{field_defaults}} )
	{
		$self->set_property( $p_id, $properties{$p_id} );
	}

	# warn of non-applicable parameters; handy for spotting
	# typos in the config file.
	foreach my $p_id ( keys %properties )
	{
		# skip warning on ID fields, it's not relevant
		last if( $self->{type} eq "id" );
		# no warning if it's a valid param
		next if( defined $self->{field_defaults}->{$p_id} );
		# these params are always valid but have no defaults
		next if( $p_id eq "field_defaults" );
		next if( $p_id eq "repository" );
		next if( $p_id eq "dataset" );
		# internal values ignored. They start with .
		next if( $p_id =~ m/^\./ );
		$self->{repository}->log( "Field '".$self->{name}."' has invalid parameter:\n$p_id => $properties{$p_id}" );
	}

	return $self;
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
		EPrints::Config::abort( <<END );
Attempt to set property "$property" on a finalised metafield.
Field: $self->{name}, type: $self->{type}
END
	}

	if( !defined $self->{field_defaults}->{$property} )
	{
		EPrints::Config::abort( <<END );
BAD METAFIELD get_property property name: "$property"
Field: $self->{name}, type: $self->{type}
END
	}

	if( defined $value )
	{
		$self->{$property} = $value;
		return;
	}

	if( $self->{field_defaults}->{$property} eq $EPrints::MetaField::NO_CHANGE )
	{
		# don't set a default, just leave it alone
		return;
	}
	
	if( $self->{field_defaults}->{$property} eq $EPrints::MetaField::REQUIRED )
	{
		EPrints::Config::abort( 
			$property." on a ".$self->{type}." metafield can't be undefined" );
	}

	if( $self->{field_defaults}->{$property} eq $EPrints::MetaField::UNDEF )
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




######################################################################
=pod

=item $dataset = $field->get_dataset

Return the dataset to which this field belongs, or undef.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}

######################################################################
=pod

=item $xhtml = $field->render_name( $session )

Render the name of this field as an XHTML object.

=cut
######################################################################

sub render_name
{
	my( $self, $session ) = @_;

	my $phrasename = $self->{confid}."_fieldname_".$self->{name};

	return $session->html_phrase( $phrasename );
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

=item $helpstring = $field->display_help( $session, [$type] )

Use of this method is not recommended. Use render_help instead.

Return the help information for a user inputing some data for this
field as a UTF-8 encoded string in the language of the $session.

If an optional type is specified then specific help for that
type will be used if available. Otherwise the normal help will be
used.

=cut
######################################################################

sub display_help
{
	my( $self, $session, $type ) = @_;

	my $phrasename = $self->{confid}."_fieldhelp_".$self->{name};

	if( defined $type && $session->get_lang->has_phrase( $phrasename.".".$type ) )
	{	
		return $session->phrase( $phrasename.".".$type );
	}

	return $session->phrase( $phrasename );
}

######################################################################
=pod

=item $xhtml = $field->render_help( $session, [$type] )

Return the help information for a user inputing some data for this
field as an XHTML chunk.

If an optional type is specified then specific help for that
type will be used if available. Otherwise the normal help will be
used. Eg. help for the title of a book may have different examples to
the default help for the title field.

=cut
######################################################################

sub render_help
{
	my( $self, $session, $type ) = @_;

	my $phrasename = $self->{confid}."_fieldhelp_".$self->{name};

	if( defined $type && $session->get_lang->has_phrase( $phrasename.".".$type ) )
	{	
		return $session->html_phrase( $phrasename.".".$type );
	}

	return $session->html_phrase( $phrasename );
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

=item $name = $field->get_name

Return the name of this field.

=cut
######################################################################

sub get_name
{
	my( $self ) = @_;
	return $self->{name};
}


######################################################################
=pod

=item $type = $field->get_type

Return the type of this field.

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;
	return $self->{type};
}



######################################################################
=pod

=item $value = $field->get_property( $property )

Return the value of the given property.

Special note about "required" property: It only indicates if the
field is always required. You must query the dataset to check if
it is required for a specific type.

=cut
######################################################################

sub get_property
{
	my( $self, $property ) = @_;

	if( !defined $self->{field_defaults}->{$property} )
	{
		EPrints::Config::abort( <<END );
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
						$basephrase.".first" ) ) 
			{ 
				$phrase = $basephrase.".first";
			}
			if( $i == scalar(@$value)-1 && 
					$session->get_lang->has_phrase( 
						$basephrase.".last" ) ) 
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


	my $rendered;
	if( !$self->get_property( "multilang" ) )
	{
		$rendered = $self->render_value_no_multilang( $session, $value, $nolink, $object );
	}
	elsif( !$alllangs )
	{
		my $v = EPrints::Session::best_language( 
			$session->get_repository, 
			$session->get_langid(), 
			%$value );
		$rendered = $self->render_value_no_multilang( $session, $v, $nolink, $object );
	}
	else
	{
		my( $tr, $td, $th );
		$rendered = $session->make_element( "table" );
		foreach( keys %$value )
		{
			$tr = $session->make_element( "tr" );
			$rendered->appendChild( $tr );
			$td = $session->make_element( "td" );
			$tr->appendChild( $td );
			$td->appendChild( 
				$self->render_value_no_multilang( $session, $value->{$_}, $nolink, $object ) );
			$th = $session->make_element( "th" );
			$tr->appendChild( $th );
			$th->appendChild( $session->make_text( '(' ) );
			$th->appendChild( $session->render_language_name( $_ ) );
			$th->appendChild( $session->make_text( ')' ) );
		}
	}
	

	if( !defined $self->{browse_link} || $nolink)
	{
		return $rendered;
	}

	my $url = $session->get_repository->get_conf(
			"base_url" );
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

	if( $linkview->{fields} =~ m/,/ )
	{
		# has sub pages
		$url .= "/view/".$self->{browse_link}."/".
			EPrints::Utils::escape_filename( $value )."/";
	}
	else
	{
		# no sub pages
		$url .= "/view/".$self->{browse_link}."/".
			EPrints::Utils::escape_filename( $value ).
			".html";
	}

	my $a = $session->render_link( $url );
	$a->appendChild( $rendered );
	return $a;
}


######################################################################
=pod

=item $xhtml = $field->render_value_no_multilang( $session, $value, $nolink, $object )

Render a basic value, with no multilang, id, or multiple parts.

This uses either the field specific render_single_value or, if one
is configured, the render_single_value specified in the config.

Usually just used internally.

=cut
######################################################################

sub render_value_no_multilang
{
	my( $self, $session, $value, $nolink, $object ) = @_;

	if( !defined $value )
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

=item $out_list = $field->sort_values( $session, $in_list )

Sorts the in_list into order, based on the "order values" of the 
values in the in_list. Assumes that the values are not a list of
multiple values. [ [], [], [] ], but rather a list of single values.
May be multilang or has_id.

=cut
######################################################################

sub sort_values
{
	my( $self, $session, $in_list ) = @_;

	my $o_keys = {};
	my $langid = $session->get_langid;
	foreach my $value ( @{$in_list} )
	{
		$o_keys->{$value} = $self->ordervalue_basic( 
						$value,
						$session,
						$langid );
	}
	my @out_list = sort { _normalcmp($o_keys->{$a}, $o_keys->{$b}) } @{$in_list};

	return \@out_list;
}


######################################################################
#
# $text = _normalize( $text )
#
# Internal function to assist sorts
# _normalize code taken from:
# http://interglacial.com/~sburke/tpj/as_html/tpj14.html
# by Sean M. Burke
######################################################################

sub _normalize 
{
	my( $in ) = @_;
  	
	$in = lc($in);
	# lc probably didn't catch this
	$in =~ tr/Ñ/ñ/; 
	# lc probably failed to turn É to é, etc 
	$in =~ tr<áéíóúüÁÉÍÓÚÜ>  <aeiouuaeiouu>;
	$in =~ tr<abcdefghijklmnñopqrstuvwxyz> <\x01-\x1B>; # 1B = 27
	return $in;
}

sub _normalcmp
{
	my( $a, $b ) = @_;

	return( (_normalize($a) cmp _normalize($b)) or ($a cmp $b ) );
}



######################################################################
=pod

=item @values = $field->list_values( $value )

Return a list of every distinct value in this field. 

 - for simple fields: return ( $value )
 - for multiple fields: return @{$value}
 - for multilang fields: return all the variations in a list.

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
		my @list = ();
		foreach( @{$value} )
		{
			push @list, $self->_list_values2( $_ );
		}
		return @list;
	}

	return $self->_list_values2( $value );
}

sub _list_values2
{
	my( $self, $value ) = @_;

	if( $self->get_property( "multilang" ) )
	{
		return values %{$value};
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
	#cjg not done yet
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

	if( ref( $v ) eq "CODE" )
	{
		return &{$v}(@args);
	}	

	return $self->{repository}->call( $v, @args );
}



######################################################################
=pod

=item $sql = $field->get_sql_type( $notnull )

Return the SQL type of this field, used for creating tables. $notnull
being true indicates that this column may not be null.

=cut
######################################################################

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return $self->get_sql_name()." VARCHAR($EPrints::MetaField::VARCHAR_SIZE)".($notnull?" NOT NULL":"");
}

######################################################################
=pod

=item $sql = $field->get_sql_index

Return the SQL definition of the index/indexes required for this field 
or an empty string if no index is required.

=cut
######################################################################

sub get_sql_index
{
	my( $self ) = @_;
	
	return undef unless( $self->get_property( "sql_index" ) );

	return "INDEX( ".$self->get_sql_name.")";
}




######################################################################
=pod

=item $xhtml_dom = $field->render_single_value( $session, $value )

Returns the XHTML representation of the value. The value will be
non-multiple and non-multilang and have no "id" part. Just the
simple value.

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

	my $table = $session->make_element( "table", border=>0, cellpadding=>0, cellspacing=>0 );

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
		if( $self->get_property( "multilang" ) )
		{
			$th = $session->make_element( "th", id=>$basename."_th_".$x++ );
			$tr->appendChild( $th );
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

			my @ids = $self->get_basic_input_ids($session, $basename, $staff, $obj );
			my $script = $session->make_element( "script", type=>"text/javascript" );
			$script->appendChild( $session->make_text( "\n" ) ); 
			foreach my $id ( @ids )
			{	
				my @wcells = ( $id );
				$script->appendChild( $session->make_text( 'ep_autocompleter( "'.$id.'", "'.$basename.'_drop", "'.$self->{input_lookup_url}.'", {relative: "'.$basename.'", component: "'.$componentid.'" }, [ $("'.join('"),$("',@wcells).'")]);'."\n" ) );
			}
			$lookup->appendChild( $script );
			push @{$rows}, [ {el=>$lookup,colspan=>$cols} ];
		}
		if( defined $self->{input_advice_below} )
		{
			my $advice = $self->call_property( "input_advice_below", $session, $self, $value );
			push @{$rows}, [ {el=>$advice,colspan=>$cols} ];
		}

		if( defined $assist )
		{
			push @{$rows}, [ {el=>$assist,colspan=>3} ];
		}
		return $rows;
	}

	# multiple field...

	my $boxcount = $self->{input_boxes};
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
	my $spacesid = $basename."_spaces";

	if( $session->internal_button_pressed() )
	{
		$boxcount = $session->param( $spacesid );
		if( $session->internal_button_pressed( 
			$basename."_morespaces" ) )
		{
			$boxcount += $self->{input_add_boxes};
		}

		for( my $i=1 ; $i<=$boxcount ; ++$i )
		{
			if( $i>1 && $session->internal_button_pressed( $basename."_up_".$i ) )
			{
				my( $a, $b ) = ( $value->[$i-1], $value->[$i-2] );
				( $value->[$i-1], $value->[$i-2] ) = ( $b, $a );
			}
			if( $session->internal_button_pressed( $basename."_down_".$i ) )
			{
				my( $a, $b ) = ( $value->[$i-1], $value->[$i+0] );
				( $value->[$i-1], $value->[$i+0] ) = ( $b, $a );
				# If the last item was moved down then extend boxcount by 1
				$boxcount++ if( $i == $boxcount ); 
			}
				
		}

	}


	my $imagesurl = $session->get_repository->get_conf( "base_url" )."/style/images";
	my $esec = $session->get_request->dir_config( "EPrints_Secure" );
	if( defined $esec && $esec eq "yes" )
	{
		$imagesurl = $session->get_repository->get_conf( "securepath" )."/style/images";
	}
	
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
				$col1 = { el=>$session->make_text( $i.". " ) };
				my $arrows = $session->make_doc_fragment;
				if( $i > 1 )
				{
					$arrows->appendChild( $session->make_element(
						"input",
						type=>"image",
						alt=>"up",
						src=> "$imagesurl/multi_up.png",
                				name=>"_internal_".$basename."_up_$i",
						value=>"1" ));
				}
				else
				{
					$arrows->appendChild( $session->make_element(
						"img",
						alt=>"up",
						src=> "$imagesurl/multi_up_dim.png" ));
				}
				$arrows->appendChild( $session->make_element( "br" ) );
				if( 1 )
				{
					$arrows->appendChild( $session->make_element(
						"input",
						type=>"image",
						src=> "$imagesurl/multi_down.png",
						alt=>"down",
                				name=>"_internal_".$basename."_down_$i",
						value=>"1" ));
				}
				else
				{
					$arrows->appendChild( $session->make_element(
						"img",
						alt=>"down",
						src=> "/$imagesurl/multi_down_dim.png" ));
				}
				$lastcol = { el=>$arrows, valign=>"middle" };
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
				my @ids = $self->get_basic_input_ids( $session, $ibasename, $staff, $obj );
				my $script = $session->make_element( "script", type=>"text/javascript" );
				$script->appendChild( $session->make_text( "\n" ) ); 
				foreach my $id ( @ids )
				{	
					my @wcells = ();
					for( 1..scalar(@{$row})-2 ) { push @wcells, $basename."_cell_".$_."_".$y; }
					$script->appendChild( $session->make_text( 'ep_autocompleter( "'.$id.'", "'.$ibasename.'_drop", "'.$self->{input_lookup_url}.'", { relative: "'.$ibasename.'", component: "'.$componentid.'" }, [$("'.join('"),$("',@wcells).'")]); ' ) );
				}
				$lookup->appendChild( $script );
				my @row = ();
				push @row, {} if( $self->{input_ordered} );
				push @row, {el=>$lookup,colspan=>$cols-1};
				push @{$rows}, \@row;
			#, {afterUpdateElement: updated}); " ));
			}
			if( defined $self->{input_advice_below} )
			{
				my $advice = $self->call_property( "input_advice_below", $session, $self, $value->[$i-1] );
				push @{$rows}, [ {},{el=>$advice,colspan=>$cols-1} ];
			}
		}
	}
	my $more = $session->make_doc_fragment;
	$more->appendChild( $session->make_element(
		"input",
		"accept-charset" => "utf-8",
		type => "hidden",
		name => $spacesid,
		value => $boxcount ) );
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
	push @row, {el=>$more,colspan=>3};
	push @{$rows}, \@row;

	return $rows;
}




sub get_input_elements_single
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	unless( $self->get_property( "multilang" ) )
	{
		return $self->get_basic_input_elements( 
			$session, 
			$value, 
			$basename, 
			$staff,
			$obj );
	}


	my $boxcount = 1;
	my $spacesid = $basename."_langspaces";
	my $buttonid = $basename."_morelangspaces";

	if( $session->internal_button_pressed() )
	{
		if( defined $session->param( $spacesid ) )
		{
			$boxcount = $session->param( $spacesid );
		}
		if( $session->internal_button_pressed( $buttonid ) )
		{
			$boxcount += $self->{input_add_boxes};
		}
	}
		
	my( @force ) = @{$self->get_property( "requiredlangs" )};
	
	my %langstodo = ();
	foreach( keys %{$value} ) { $langstodo{$_}=1; }
	my %langlabels = ();
	foreach( EPrints::Config::get_languages() ) 
	{ 
		$langlabels{$_}= EPrints::Utils::tree_to_utf8(
			$session->render_language_name( $_ ) );
	}
	foreach( @force ) { delete $langlabels{$_}; }
	my @langopts = ("", keys %langlabels );
	# cjg NOT LANG'd
	$langlabels{""} = "** Select Language **";

	my $rows = [];	
	my $i=1;
	my $langid;
	while( 
		scalar( @force ) > 0 || 
		$i <= $boxcount || 
		scalar( keys %langstodo ) > 0 )
	{
		my $langid = "";
		my $forced = 0;
		if( scalar @force )
		{
			$langid = shift @force;
			$forced = 1;
			delete( $langstodo{$langid} );
		}
		elsif( scalar keys %langstodo )
		{
			$langid = ( keys %langstodo )[0];
			delete( $langstodo{$langid} );
		}
		
		my $langparamid = $basename."_".$i."_lang";
		my $langbit;
		if( $forced )
		{
			$langbit = $session->make_element( 
				"span", 
				class => "requiredlang" );
			$langbit->appendChild( $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "hidden",
				name => $langparamid,
				value => $langid ) );
			$langbit->appendChild( 
				$session->render_language_name( $langid ) );
		}
		else
		{
			$langbit = $session->render_option_list(
				name => $langparamid,
				values => \@langopts,
				default => $langid,
				labels => \%langlabels );
		}
	
		my $elements = $self->get_basic_input_elements( 
			$session, 
			$value->{$langid}, 
			$basename."_".$i, 
			$staff,
			$obj );

		my $first = 1;
		for my $n (0..(scalar @{$elements})-1)
		{
			my $lastcol = {};
			if( $n == 0 )
			{
				$lastcol = { el=>$langbit };
			}
			push @{$rows}, [ @{$elements->[$n]}, $lastcol ];
		}
			
		++$i;
	}
				
	$boxcount = $i-1;

	my $more = $session->make_doc_fragment;	
	$more->appendChild( $session->make_element(
		"input",
		"accept-charset" => "utf-8",
		type => "hidden",
		name => $spacesid,
		value => $boxcount ) );
	$more->appendChild( $session->render_internal_buttons(
		$buttonid => $session->phrase( 
				"lib/metafield:more_langs" ) ) );

	push @{$rows}, [ { el=>$more} ];

	return $rows;
}	



sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	my $maxlength = $self->get_max_input_size;
	my $size = ( $maxlength > $self->{input_cols} ?
					$self->{input_cols} : 
					$maxlength );
	my $input = $session->make_element(
		"input",
		class=>"ep_form_text",
		"accept-charset" => "utf-8",
		name => $basename,
		id => $basename,
		value => $value,
		size => $size,
		maxlength => $maxlength );

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
	return $EPrints::MetaField::VARCHAR_SIZE;
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
			if( defined $value || $session->internal_button_pressed )
			{
				push @values, $value;
			}
		}
		if( scalar @values == 0 )
		{
			return undef;
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

	unless( $self->get_property( "multilang" ) )
	{
		# simple case; not multilang
		my $value = $self->form_value_basic( $session, $basename, $object );
		return undef unless( EPrints::Utils::is_set( $value ) );
		return $value;
	}

	my $value = {};
	my $boxcount = $session->param( $basename."_langspaces" );
	$boxcount = 1 if( $boxcount < 1 );
	for( my $i=1; $i<=$boxcount; ++$i )
	{
		my $subvalue = $self->form_value_basic( 
			$session, 
			$basename."_".$i,
			$object );
		my $langid = $session->param( 
			$basename."_".$i."_lang" );
		if( $langid eq "" ) 
		{ 
			$langid = "_".$i; 
		}
		if( defined $subvalue )
		{
			$value->{$langid} = $subvalue;
			# print STDERR "($langid)($subvalue)\n";
			#cjg -- does not check that this is a valid langid...
		}
	}
	$value = undef if( scalar keys %{$value} == 0 );

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

=item $sqlname = $field->get_sql_name

Return the name of this field as it appears in an SQL table.

=cut
######################################################################

sub get_sql_name
{
	my( $self ) = @_;

	return $self->{name};
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

=item $values = $field->get_values( $session, $dataset, %opts )

Return a reference to an array of all the values of this field. 
For fields like "subject" or "set"
it returns all the variations. For fields like "text" return all 
the distinct values from the database.

Results are sorted according to the ordervalues of the $session.

=cut
######################################################################


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
		$v2 = "" unless( defined $value );
		push @values, $v2;

		# uses function _basic because value will NEVER be multiple
		# should never by .id or multilang either.
		my $orderkey = $self->ordervalue_basic(
			$value, 
			$session, 
			$langid );
		$orderkeys{$v2} = $orderkey || "";
	}

	my @outvalues = sort {$orderkeys{$a} cmp $orderkeys{$b}} @values;

	return \@outvalues;
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	return $session->get_database->get_values( $self, $dataset );
}

######################################################################
=pod

=item $xhtml = $field->get_value_label( $session, $value )

Return an XHTML DOM object describing the given value. Normally this
is just the value, but in the case of something like a "set" field 
this returns the name of the option in the current language.

=cut
######################################################################

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

=item $ov = $field->ordervalue( $value, $session, $langid )

Return a string representing this value which can be used to sort
it into order by comparing it alphabetically.

=cut
######################################################################

sub ordervalue
{
	my( $self , $value , $session , $langid ) = @_;

	return "" if( !defined $value );

	if( defined $self->{make_value_orderkey} )
	{
		no strict "refs";
		return $self->call_property( "make_value_orderkey",
			$self, 
			$value, 
			$session, 
			$langid );
	}


	if( !$self->get_property( "multiple" ) )
	{
		return $self->ordervalue_single( $value , $session , $langid );
	}

	my @r = ();	
	foreach( @$value )
	{
		push @r, $self->ordervalue_single( $_ , $session , $langid );
	}
	return join( ":", @r );
}


######################################################################
# 
# $ov = $field->ordervalue_single( $value, $session, $langid )
# 
# undocumented
# 
######################################################################

sub ordervalue_single
{
	my( $self , $value , $session , $langid ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	if( $self->get_property( "multilang" ) )
	{
		$value = EPrints::Session::best_language( 
			$session->get_repository,
			$langid,
			%{$value} );
	}

	if( defined $self->{make_single_value_orderkey} )
	{
		return $self->call_property( "make_single_value_orderkey",
			$self, 
			$value ); 
	}

	return $self->ordervalue_basic( $value );
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
	my( $self , $value ) = @_;

	return $value;
}







# XML output methods


sub to_xml
{
	my( $self, $session, $value, $depth ) = @_;

	$depth = 0 unless defined $depth;

	my $r = $session->make_doc_fragment;
	my $ind = "  "x$depth;

	$r->appendChild( $session->make_text( "\n$ind" ) );
	my $tag = $session->make_element( $self->get_name );	
	$r->appendChild( $tag );
	if( $self->get_property( "multiple" ) )
	{
		foreach my $single ( @{$value} )
		{
			$tag->appendChild( $session->make_text( "\n$ind " ) );
			my $item = $session->make_element( "item" );
			$item->appendChild( $self->to_xml_single( $session, $single, $depth+1 ) );
			$tag->appendChild( $item );
		}
		$tag->appendChild( $session->make_text( "\n$ind" ) );
	}
	else
	{
		$tag->appendChild( $self->to_xml_single( $session, $value, $depth ) );
	}

	return $r;
}

sub to_xml_single
{
	my( $self, $session, $value, $depth ) = @_;

	$depth = 0 unless defined $depth;

	unless( $self->get_property( "multilang" ) )
	{
		return $self->to_xml_basic( $session, $value, $depth );
	}

	my $ind = "  "x$depth;
	my $r = $session->make_doc_fragment;	
	foreach my $langid ( keys %{$value} )
	{
		$r->appendChild( $session->make_text( "\n  $ind" ) );
		my $langvar = $session->make_element( "langvar" );
		$r->appendChild( $langvar );

		$langvar->appendChild( $session->make_text( "\n    $ind" ) );

		my $lang = $session->make_element( "lang" );
		$lang->appendChild( $session->make_text( $langid ) );
		$langvar->appendChild( $lang );
				
		$langvar->appendChild( $session->make_text( "\n    $ind" ) );

		my $valuetag = $session->make_element( "value" );
		$valuetag->appendChild( $self->to_xml_basic( $session, $value->{$langid}, $depth+2 ) );
		$langvar->appendChild( $valuetag );

		$langvar->appendChild( $session->make_text( "\n  $ind" ) );

		$r->appendChild( $session->make_text( "\n$ind" ) );
	}
	return $r;
}

sub to_xml_basic
{
	my( $self, $session, $value, $depth ) = @_;

	if( !defined $value ) 
	{
		return $session->make_text( "" );
	}
	return $session->make_text( $value );
}







#### old xml v1

sub to_xml_old
{
	my( $self, $session, $v, $no_xmlns ) = @_;

	my $r = $session->make_doc_fragment;
	if( $self->get_property( "multiple" ) )
	{
		my @list = @{$v};
		# trim empty elements at end
		while( scalar @list > 0 && !EPrints::Utils::is_set($list[(scalar @list)-1]) )
		{
			pop @list;
		}
		foreach my $item ( @list )
		{
			$r->appendChild( $session->make_text( "    " ) );
			$r->appendChild( $self->to_xml_old_single( $session, $item, $no_xmlns ) );
			$r->appendChild( $session->make_text( "\n" ) );
		}
	}
	else
	{
		$r->appendChild( $session->make_text( "    " ) );
		$r->appendChild( $self->to_xml_old_single( $session, $v, $no_xmlns ) );
		$r->appendChild( $session->make_text( "\n" ) );
	}
	return $r;
}

sub to_xml_old_single
{
	my( $self, $session, $v, $no_xmlns ) = @_;

	my %attrs = ( name=>$self->get_name() );
	$attrs{'xmlns'}="http://eprints.org/ep2/data" unless( $no_xmlns );

	my $r = $session->make_element( "field", %attrs );

	if( $self->get_property( "multilang" ) )
	{
		foreach( keys %{$v} )
		{
			my $l = $session->make_element( "lang", id=>$_ );
			$l->appendChild( $self->to_xml_basic( $session, $v->{$_} ) );
			$r->appendChild( $l );
		}
	}
	else
	{
		$r->appendChild( $self->to_xml_basic( $session, $v ) );
	}

	return $r;
}

########## end of old XML


sub render_search_input
{
	my( $self, $session, $searchfield ) = @_;
	
	my $frag = $session->make_doc_fragment;

	# complex text types
	$frag->appendChild(
		$session->make_element( "input",
			"accept-charset" => "utf-8",
			type => "text",
			name => $searchfield->get_form_prefix,
			value => $searchfield->get_value,
			size => $self->get_property( "search_cols" ),
			maxlength => 256 ) );
	$frag->appendChild( $session->make_text(" ") );
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
	return $frag;
}

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

sub split_search_value
{
	my( $self, $session, $value ) = @_;

#	return EPrints::Index::split_words( 
#			$session,
#			EPrints::Index::apply_mapping( $session, $value ) );

	return split /\s+/, $value;
}

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

sub get_search_group { return 'basic'; } 


# return system defaults for this field type
sub get_property_defaults
{
	return (
		allow_null 	=> 0,
		browse_link 	=> $EPrints::MetaField::UNDEF,
		can_clone 	=> 1,
		confid 		=> $EPrints::MetaField::NO_CHANGE,
		export_as_xml 	=> 1,
		fromform 	=> $EPrints::MetaField::UNDEF,
		import		=> 1,
		input_add_boxes => $EPrints::MetaField::FROM_CONFIG,
		input_advice_right => $EPrints::MetaField::UNDEF,
		input_advice_below => $EPrints::MetaField::UNDEF,
		input_assist	=> 0,
		input_boxes 	=> $EPrints::MetaField::FROM_CONFIG,
		input_cols 	=> $EPrints::MetaField::FROM_CONFIG,
		input_id_cols	=> $EPrints::MetaField::FROM_CONFIG,
		input_lookup_url 	=> $EPrints::MetaField::UNDEF,
		input_ordered 	=> 1,
		make_single_value_orderkey 	=> $EPrints::MetaField::UNDEF,
		make_value_orderkey 		=> $EPrints::MetaField::UNDEF,
		maxlength 	=> $EPrints::MetaField::VARCHAR_SIZE,
		multilang 	=> 0,
		multiple 	=> 0,
		name 		=> $EPrints::MetaField::REQUIRED,
		show_in_html	=> 1,
		render_input 	=> $EPrints::MetaField::UNDEF,
		render_single_value 	=> $EPrints::MetaField::UNDEF,
		render_quiet	=> 0,
		render_magicstop	=> 0,
		render_noreturn	=> 0,
		render_dont_link	=> 0,
		render_value 	=> $EPrints::MetaField::UNDEF,
		required 	=> 0,
		requiredlangs 	=> [],
		search_cols 	=> $EPrints::MetaField::FROM_CONFIG,
		sql_index 	=> 1,
		text_index 	=> 0,
		toform 		=> $EPrints::MetaField::UNDEF,
		type 		=> $EPrints::MetaField::REQUIRED,
		hasid		=> 0, # do not use!
);
}
		
# Most types are not indexed		
sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
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

	return 0;
}

######################################################################

1;

=pod

=back

=cut
