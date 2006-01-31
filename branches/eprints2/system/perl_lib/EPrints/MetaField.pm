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
#  $self->{archive}
#     The archive to which this field belongs.
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

# are these all needed?
use EPrints::Utils;
use EPrints::Session;
use EPrints::Subject;
use EPrints::Database;
use EPrints::SearchExpression;

use strict;

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
"confid" and "archive" must be provided instead.

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

	my $self = {};
	bless $self, $realclass;

	$self->{confid} = $properties{confid};

	if( defined $properties{dataset} ) 
	{ 
		$self->{confid} = $properties{dataset}->confid(); 
		$self->{dataset} = $properties{dataset};
		$self->{archive} = $properties{dataset}->get_archive();
	}
	else
	{
		if( !defined $properties{archive} )
		{
			EPrints::Config::abort( 
				"Tried to create a metafield without a ".
				"dataset or an archive." );
		}
		$self->{archive} = $properties{archive};
	}

	# This gets reset later, but we need it for potential
	# debug messages.
	$self->{type} = $properties{type};
	
	$self->{field_defaults} = $self->{archive}->get_field_defaults( $properties{type} );
	if( !defined $self->{field_defaults} )
	{
		my %props = $self->get_property_defaults;
		$self->{field_defaults} = {};
		foreach my $p_id ( keys %props )
		{
			if( defined $props{$p_id} && $props{$p_id} eq $EPrints::MetaField::FROM_CONFIG )
			{
				my $v = $self->{archive}->get_conf( "field_defaults" )->{$p_id};
				if( !defined $v )
				{
					$v = $EPrints::MetaField::UNDEF;
				}
				$props{$p_id} = $v;
			}
			$self->{field_defaults}->{$p_id} = $props{$p_id};
		}
		$self->{archive}->set_field_defaults( $properties{type}, $self->{field_defaults} );
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
		next if( $p_id eq "archive" );
		next if( $p_id eq "dataset" );
		$self->{archive}->log( "Field '".$self->{name}."' has invalid parameter:\n$p_id => $properties{$p_id}" );
	}

	return( $self );
}

######################################################################
=pod

=item $field->set_property( $property, $value )

Set the named property to the given value.

=cut
######################################################################

sub set_property
{
	my( $self , $property , $value ) = @_;

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
	$phrasename.= "_id" if( $self->get_property( "idpart" ) );

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
	$phrasename.= "_id" if( $self->get_property( "idpart" ) );
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
	$phrasename.= "_id" if( $self->get_property( "idpart" ) );
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
	$phrasename.= "_id" if( $self->get_property( "idpart" ) );
	if( defined $type && $session->get_lang->has_phrase( $phrasename.".".$type ) )
	{	
		return $session->html_phrase( $phrasename.".".$type );
	}

	return $session->html_phrase( $phrasename );
}


######################################################################
=pod

=item $xhtml = $field->render_input_field( $session, $value, [$dataset, $type], [$staff], [$hidden_fields] )

Return the XHTML of the fields for an form which will allow a user
to input metadata to this field. $value is the default value for
this field.

The actual function called may be overridden from the config.

=cut
######################################################################

sub render_input_field
{
	my( $self, $session, $value, $dataset, $type, $staff, $hidden_fields, $obj ) = @_;

	if( defined $self->{toform} )
	{
		$value = &{$self->{toform}}( $value, $session );
	}

	if( defined $self->{render_input} )
	{
		return &{$self->{render_input}}(
			$self,
			$session, 
			$value, 
			$dataset, 
			$type, 
			$staff,
			$hidden_fields,
			$obj );
	}

	return $self->render_input_field_actual( 
			$session, 
			$value, 
			$dataset, 
			$type, 
			$staff,
			$hidden_fields,
			$obj );
}


######################################################################
=pod

=item $value = $field->form_value( $session )

Get a value for this field from the CGI parameters, assuming that
the form contained the input fields for this metadata field.

=cut
######################################################################

sub form_value
{
	my( $self, $session ) = @_;

	my $value = $self->form_value_actual( $session );

	if( defined $self->{fromform} )
	{
		$value = &{$self->{fromform}}( $value, $session );
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

=item $xhtml = $field->render_value( $session, $value, [$alllangs], [$nolink] )

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
	my( $self, $session, $value, $alllangs, $nolink ) = @_;

	if( defined $self->{render_value} )
	{
		return &{$self->{render_value}}( 
			$session, 
			$self, 
			$value, 
			$alllangs, 
			$nolink );
	}


	unless( EPrints::Utils::is_set( $value ) )
	{
		if( $self->{render_opts}->{quiet} )
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
			$nolink );
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
				$nolink ) );
	}
	return $html;

}


######################################################################
=pod

=item $xhtml = $field->render_value_no_multiple( $session, $value, $alllangs, $nolink )

Render the XHTML for a non-multiple value. Can be either a from
a non-multiple field, or a single value from a multiple field.

Usually just used internally.

=cut
######################################################################

sub render_value_no_multiple
{
	my( $self, $session, $value, $alllangs, $nolink ) = @_;

	# just main/id if that's what we're rendering
	$value = $self->which_bit( $value );

	if( $self->get_property( "hasid" ) )
	{
		# Ask the usercode to fiddle with this bit of HTML
		# based on the value of it's ID. 
		# It will either just pass it through, redo it from scratch
		# or wrap it in a link.

		my $rendered = $self->get_main_field()->render_value_no_id( $session, $value->{main}, $alllangs, $nolink );

		return $session->get_archive()->call( 
			"render_value_with_id",  
			$self, 
			$session, 
			$value, 
			$alllangs, 
			$rendered, 
			$nolink );
	}

	my $rendered = $self->render_value_no_id( $session, $value, $alllangs, $nolink );

	if( !defined $self->{browse_link} || $nolink)
	{
		return $rendered;
	}

	my $url = $session->get_archive()->get_conf(
			"base_url" );
	my $views = $session->get_archive()->get_conf( "browse_views" );
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
		$session->get_archive()->log( "browse_link to view '".$self->{browse_link}."' not found for field '".$self->{name}."'\n" );
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

=item $xhtml = $field->render_value_no_id( $session, $value, $alllangs, $nolink )

Render the XHTML for a non-multiple value which has no id/main part. 
Can be either a from a non-multiple field, non-id field or a part of
a field which is non-multiple and is the main part.

Usually just used internally.

=cut
######################################################################

sub render_value_no_id
{
	my( $self, $session, $value, $alllangs, $nolink ) = @_;

	# We don't care about the ID
	if( $self->get_property( "hasid" ) )
	{
		$value = $value->{main};
	}

	if( !$self->get_property( "multilang" ) )
	{
		return $self->render_value_no_multilang( $session, $value, $nolink );
	}

	if( !$alllangs )
	{
		my $v = EPrints::Session::best_language( 
			$session->get_archive(), 
			$session->get_langid(), 
			%$value );
		return $self->render_value_no_multilang( $session, $v, $nolink );
	}
	my( $table, $tr, $td, $th );
	$table = $session->make_element( "table" );
	foreach( keys %$value )
	{
		$tr = $session->make_element( "tr" );
		$table->appendChild( $tr );
		$td = $session->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( 
			$self->render_value_no_multilang( $session, $value->{$_} ) );
		$th = $session->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild( $session->make_text( '(' ) );
		$th->appendChild( $session->render_language_name( $_ ) );
		$th->appendChild( $session->make_text( ')' ) );
	}
	return $table;
}

######################################################################
=pod

=item $xhtml = $field->render_value_no_multilang( $session, $value, $nolink )

Render a basic value, with no multilang, id, or multiple parts.

This uses either the field specific render_single_value or, if one
is configured, the render_single_value specified in the config.

Usually just used internally.

=cut
######################################################################

sub render_value_no_multilang
{
	my( $self, $session, $value, $nolink ) = @_;

	if( !defined $value )
	{
		return $session->html_phrase( 
			"lib/metafield:unspecified",
			fieldname => $self->render_name( $session ) );
	}

	if( $self->{render_opts}->{magicstop} )
	{
		# add a full stop if the vale does not end with ? ! or .
		$value =~ s/\s*$//;
		if( $value !~ m/[\?!\.]$/ )
		{
			$value .= '.';
		}
	}

	if( $self->{render_opts}->{noreturn} )
	{
		# turn  all CR's and LF's to spaces
		$value =~ s/[\r\n]/ /g;
	}



	if( defined $self->{render_single_value} )
	{
		return &{$self->{render_single_value}}( 
			$session, 
			$self, 
			$value );
	}

	return $self->render_single_value( $session, $value );
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

This function is used by the item_matches method in SearchExpression.

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

	my $v2 = $self->which_bit( $value );

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
the archive, any language at all. If it is not a multilang field
then just return $value.

=cut
######################################################################

sub most_local
{
	my( $self, $session, $value ) = @_;
	#cjg not done yet
	my $bestvalue =  EPrints::Session::best_language( 
		$session->get_archive(), $session->get_langid(), %{$value} );
	return $bestvalue;
}


######################################################################
=pod

=item $idfield = $field->get_id_field

Only meaningful on fields with "hasid" property. Return a field 
representing just the id part of this field.

=cut
######################################################################

sub get_id_field
{
	my( $self ) = @_;
	# only meaningful to call this on "hasid" fields
	#cjg SHould log an issue if otherwise?
	#returns undef for non-id fields.
	return unless( $self->get_property( "hasid" ) );
	# hack to make the cloned field a different type
	my $tmp_type = $self->{type}; 
	$self->{type} = 'id'; 
	my $idfield = $self->clone();
	$self->{type} = $tmp_type;
	$idfield->set_property( "multilang", 0 );
	$idfield->set_property( "hasid", 0 );
	$idfield->set_property( "type", "id" );
	$idfield->set_property( "idpart", 1 );
	return $idfield;
}


######################################################################
=pod

=item $mainfield = $field->get_main_field

Only meaningful on fields with "hasid" property. Return a field 
representing just the main part of this field.

=cut
######################################################################

sub get_main_field
{
	my( $self ) = @_;
	# only meaningful to call this on "hasid" fields
	return unless( $self->get_property( "hasid" ) );

	my $idfield = $self->clone();
	$idfield->set_property( "hasid", 0 );
	$idfield->set_property( "mainpart", 1 );
	return $idfield;
}


# Which bit do we care about in an eprints value (the id, main, or all of it?)

######################################################################
=pod

=item $value2 = $field->which_bit( $value )

If this field represents the id part of a field only, then return the
id part of $value.

If this field represents the main part of a field only, then return the
id part of $value.

Otherwise return $value.

=cut
######################################################################

sub which_bit
{
	my( $self, $value ) = @_;

	if( $self->get_property( "idpart" ) )
	{
		return $value->{id};
	}
	if( $self->get_property( "mainpart" ) )
	{
		return $value->{main};
	}
	return $value;
}








######################################################################
1;
