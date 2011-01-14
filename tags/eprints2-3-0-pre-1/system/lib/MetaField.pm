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

use EPrints::Utils;
use EPrints::Session;
use EPrints::Subject;
use EPrints::Database;
use EPrints::SearchExpression;

use strict;

# Months
my @monthkeys = ( 
	"00", "01", "02", "03", "04", "05", "06",
	"07", "08", "09", "10", "11", "12" );


# list of legal properties used to check
# get & set property.

# a setting of -1 means that this property must be set
# explicitly and does not therefore have a default

my $PROPERTIES = 
{
	allow_set_order => 1,
	browse_link => 1,
	can_clone => 1,
	confid => -1,
	datasetid => -1,
	digits => 1,
	export_as_xml => 1,
	fieldnames => -1,
	input_rows => 1,
	input_cols => 1,
	input_name_cols => 1,
	input_id_cols => 1,
	input_add_boxes => 1,
	input_boxes => 1,
	input_style => 1,
	search_cols => 1,
	search_rows => 1,
	fromform => 1,
	toform => 1,
	maxlength => 1,
	hasid => 1,
	id_editors_only => 1,
	multilang => 1,
	multiple => 1,
	name => -1,
	options => -1,
	required => 1,
	requiredlangs => 1,
	showall => 1,
	showtop => 1,
	sql_index => 1,
	idpart => 1,
	mainpart => 1,
	make_value_orderkey => 1,
	make_single_value_orderkey => 1,
	min_resolution => 1,
	render_single_value => 1,
	render_value => 1,
	render_input => 1,
	render_opts => 1,
	top => 1,
	type => -1
};

my $VARCHAR_SIZE = 255;

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
	
	my $self = {};
	bless $self, $class;

	$self->{confid} = $properties{confid};

	if( defined $properties{dataset} ) { 
		$self->{confid} = $properties{dataset}->confid(); 
		$self->{dataset} = $properties{dataset};
		$self->{archive} = $properties{dataset}->get_archive();
	}
	else
	{
		if( !defined $properties{archive} )
		{
			EPrints::config::abort( 
				"Tried to create a metafield without a ".
				"dataset or an archive." );
		}
		$self->{archive} = $properties{archive};
	}
	$self->set_property( "name", $properties{name} );
	$self->set_property( "type", $properties{type} );
	if( $self->is_type( "datatype", "search" ) )
	{
		$self->set_property( "datasetid" , $properties{datasetid} );
	}

	if( $self->is_type( "search" ) )
	{
		$self->set_property( "fieldnames" , $properties{fieldnames} );
	}
	if( $self->is_type( "set" ) )
	{
		$self->set_property( "options" , $properties{options} );
	}
	my $p;
	foreach $p ( keys %{$PROPERTIES} )
	{
		if( $PROPERTIES->{$p} == 1 )
		{
			$self->set_property( $p, $properties{$p} );
		}
	}

	return( $self );
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

=item ( $options , $labels ) = $field->tags_and_labels( $session )

Return a reference to an array of options for this ("options" type)
field, plus an array of UTF-8 encoded labels for these options in the 
current language.

=cut
######################################################################

sub tags_and_labels
{
	my( $self , $session ) = @_;
	my %labels = ();
	foreach( @{$self->{options}} )
	{
		$labels{$_} = EPrints::Utils::tree_to_utf8( 
			$self->render_option( $session, $_ ) );
	}
	return ($self->{options}, \%labels);
}


######################################################################
=pod

=item $label = $field->display_name( $session )

Return the UTF-8 encoded name of this field, in the language of
the $session.

=cut
######################################################################

sub display_name
{
	my( $self, $session ) = @_;

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

=item $xhtml = $field->render_option( $session, $option )

Return the title of option $option in the language of $session as an 
XHTML DOM object.

=cut
######################################################################

sub render_option
{
	my( $self, $session, $option ) = @_;

	my $phrasename = $self->{confid}."_fieldopt_".$self->{name}."_".$option;

	return $session->html_phrase( $phrasename );
}


######################################################################
=pod

=item $sql = $field->get_sql_type( [$notnull] )

Return the SQL type for this field used when constructing a MySQL 
table. If $notnull is true then add "NOT NULL" to the specification.

Type "name" fields return four field definitions. One for each part
of the name.

=cut
######################################################################

sub get_sql_type
{
	my( $self , $notnull ) = @_;

	my $sqlname = $self->get_sql_name();
	my $param = "";
	$param = "NOT NULL" if( $notnull );

	if( $self->is_type( "int", "year" ) )
	{
 		return $sqlname.' INTEGER '.$param;
	}

	if( $self->is_type( "langid" ) )
	{
 		return $sqlname.' CHAR(16) '.$param;
	}

	if( $self->is_type( "longtext", "search" ) )
	{
 		return $sqlname.' TEXT '.$param;
	}

	if( $self->is_type( "date" ) )
	{
 		return $sqlname.' DATE '.$param;
	}

	if( $self->is_type( "boolean" ) )
	{
 		return $sqlname." SET('TRUE','FALSE') ".$param;
	}

	if( $self->is_type( "name" ) )
	{
		my $vc = 'VARCHAR('.$VARCHAR_SIZE.')';
		return 
			$sqlname.'_honourific '.$vc.' '.$param.', '.
			$sqlname.'_given '.$vc.' '.$param.', '.
			$sqlname.'_family '.$vc.' '.$param.', '.
			$sqlname.'_lineage '.$vc.' '.$param;
	}

	# all others: 
	#   set, text, secret, url, email, subject, pagerange, 
	#   datatype, id
	# become a VARCHAR.
	# This is not very effecient, but diskspace is cheap, right?

	return $sqlname." VARCHAR($VARCHAR_SIZE) ".$param;
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
	
	if( $self->is_type( "longtext", "secret", "search" ) )
	{
		return undef;
	}

	unless( $self->get_property( "sql_index" ) )
	{
		return undef;
	}


	my $sqlname = $self->get_sql_name();
	
	if( $self->is_type( "name" ) )
	{
		return 'INDEX( '.$sqlname.'_given), '.
			'INDEX( '.$sqlname.'_family)';
	}

	return "INDEX( ".$sqlname.")";
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

=item $field->set_property( $property, $value )

Set the named property to the given value.

=cut
######################################################################

sub set_property
{
	my( $self , $property , $value ) = @_;

	if( !defined $PROPERTIES->{$property} )
	{
		die "BAD METAFIELD set_property NAME: \"$property\"";
	}
	if( !defined $value )
	{
		if( $PROPERTIES->{$property} == -1 )
		{
			EPrints::Config::abort( 
				$property." on a metafield can't be undef" );
		}
		$self->{$property} = $self->get_property_default( $property );
	}
	else
	{
		$self->{$property} = $value;
	}
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

	if( !defined $PROPERTIES->{$property})
	{
		die "BAD METAFIELD get_property NAME: \"$property\"";
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

=item $boolean = $field->is_text_indexable

Return true if this field can be searched by "free text" searching - 
indexing all the individual words in it.

=cut
######################################################################

sub is_text_indexable
{
	my( $self ) = @_;
	return $self->is_type( "text","longtext","url","email" );
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

	unless( $self->get_property( "multiple" ) )
	{
		return $self->_render_value1( 
			$session, 
			$value, 
			$alllangs, 
			$nolink );
	}

	unless( EPrints::Utils::is_set( $value ) )
	{
		# maybe should just return nothing
		return $session->html_phrase( "lib/metafield:unspecified" );
	}

	my @rendered_values = ();

	my $first = 1;
	my $html = $session->make_doc_fragment();
	
	foreach( @$value )
	{
		if( $first )
		{
			$first = 0;	
		}	
		else
		{
			$html->appendChild( $session->html_phrase( 
				"lib/metafield:join_".$self->get_type ) );
		}
		$html->appendChild( 
			$self->_render_value1( 
				$session, 
				$_, 
				$alllangs, 
				$nolink ) );
	}
	return $html;

}


######################################################################
# 
# $xhtml = $field->_render_value1( $session, $value, $alllangs, $nolink )
#
# undocumented
#
######################################################################

sub _render_value1
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

		my $rendered = $self->get_main_field()->_render_value2( $session, $value->{main}, $alllangs, $nolink );

		return $session->get_archive()->call( 
			"render_value_with_id",  
			$self, 
			$session, 
			$value, 
			$alllangs, 
			$rendered, 
			$nolink );
	}

	my $rendered = $self->_render_value2( $session, $value, $alllangs, $nolink );

	if( defined $self->{browse_link} && !$nolink)
	{
		my $url = $session->get_archive()->get_conf( 
				"base_url" );
		$url .= "/view/".$self->{browse_link}."/".
			EPrints::Utils::escape_filename( $value ).
			".html";
		my $a = $session->render_link( $url );
		$a->appendChild( $rendered );
		return $a;
	}

	return $rendered;
}

######################################################################
# 
# $xhtml = $field->_render_value2( $session, $value, $alllangs, $nolink )
#
# undocumented
#
######################################################################

sub _render_value2
{
	my( $self, $session, $value, $alllangs, $nolink ) = @_;

	# We don't care about the ID
	if( $self->get_property( "hasid" ) )
	{
		$value = $value->{main};
	}

	if( !$self->get_property( "multilang" ) )
	{
		return $self->_render_value3( $session, $value, $nolink );
	}

	if( !$alllangs )
	{
		my $v = EPrints::Session::best_language( 
			$session->get_archive(), 
			$session->get_langid(), 
			%$value );
		return $self->_render_value3( $session, $v, $nolink );
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
			$self->_render_value3( $session, $value->{$_} ) );
		$th = $session->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild( $session->make_text(
			"(".EPrints::Config::lang_title( $_ ).")" ) );
	}
	return $table;
}

######################################################################
# 
# $xhtml = $field->_render_value3( $session, $value, $nolink )
#
# undocumented
#
######################################################################

sub _render_value3
{
	my( $self, $session, $value, $nolink ) = @_;

	if( !defined $value )
	{
		return $session->html_phrase( "lib/metafield:unspecified" );
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


	if( defined $self->{render_single_value} )
	{
		return &{$self->{render_single_value}}( 
			$session, 
			$self, 
			$value );
	}

	if( $self->is_type( "text" , "int" , "pagerange" , "year" ) )
	{
		# Render text
		return $session->make_text( $value );
	}

	if( $self->is_type( "secret" ) )
	{
		# cjg better return than ???? ?
		return $session->make_text( "????" );
	}

	if( $self->is_type( "url" ) )
	{
		my $a = $session->render_link( $value );
		$a->appendChild( $session->make_text( $value ) );
		return $a;
	}

	if( $self->is_type( "email" ) )
	{
		my $text =  $session->make_text( $value ) ;
		if( $nolink )
		{
			return $text;
		}
		my $a = $session->render_link( "mailto:".$value );
		$a->appendChild( $text );
		return $a;
	}

	if( $self->is_type( "name" ) )
	{
		return $session->render_name( $value );
	}

	if( $self->is_type( "date" ) )
	{
		my $res = $self->get_property( "render_opts" )->{res};
		my $l = 10;
		$l = 7 if( $res eq "M" );
		$l = 4 if( $res eq "Y" );
		return EPrints::Utils::render_date( $session, substr( $value,0,$l ) );
	}

	if( $self->is_type( "search" ) )
	{
		my $searchexp = $self->make_searchexp( $session, $value );
		my $desc = $searchexp->render_description;
		$searchexp->dispose;
		return $desc;
	}

	if( $self->is_type( "longtext" ) )
	{
		my @paras = split( /\r\n|\r|\n/ , $value );
		my $frag = $session->make_doc_fragment();
		my $first = 1;
		foreach( @paras )
		{
			unless( $first )
			{
				$frag->appendChild( 
					$session->make_element( "br" ) );
			}
			$frag->appendChild( $session->make_text( $_ ) );
			$first = 0;
		}
		return $frag;
	}

	if( $self->is_type( "datatype" ) )
	{
		my $ds = $session->get_archive()->get_dataset( 
			$self->get_property( "datasetid" ) );

		return $ds->render_type_name( $session, $value ); 
	}

	if( $self->is_type( "set" ) )
	{
		return $self->render_option( $session , $value );
	}

	if( $self->is_type( "boolean" ) )
	{
		return $session->html_phrase( 
			"lib/metafield:".($value eq "TRUE"?"true":"false") );
	}

	
	if( $self->is_type( "subject" ) )
	{
		my $subject = new EPrints::Subject( $session, $value );
		if( !defined $subject )
		{
			return $session->make_text( "?? $value ??" );
		}
		return $subject->render_with_path( 
			$session, 
			$self->get_property( "top" ) );
	}
	
	$session->get_archive()->log( "Unknown field type: ".$self->{type} );
	return $session->make_text( "?? $value ??" );
}


######################################################################
=pod

=item $xhtml = $field->render_input_field( $session, $value, [$dataset, $type], [$staff], [$hidden_fields] )

Return the XHTML of the fields for an form which will allow a user
to input metadata to this field. $value is the default value for
this field.

=cut
######################################################################

sub render_input_field
{
	my( $self, $session, $value, $dataset, $type, $staff, $hidden_fields ) = @_;

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
			$hidden_fields );
	}

	my( $html, $frag );

	my $req = $self->get_property( "required" );
	if( defined $dataset && defined $type )
	{
		$req = $dataset->field_required_in_type( $self, $type );
	}


	$html = $session->make_doc_fragment();

	# subject fields can be rendered here and now
	# without looping and calling the aux function.

	if( $self->is_type( "subject", "datatype", "set" ) )
	{
		my %settings;
		$settings{name} = $self->{name};
		$settings{multiple} = 
			( $self->{multiple} ?  "multiple" : undef );

		if( !defined $value )
		{
			$settings{default} = []; 
		}
		elsif( !$self->get_property( "multiple" ) )
		{
			$settings{default} = [ $value ]; 
		}
		else
		{
			$settings{default} = $value; 
		}

		$settings{height} = $self->{input_rows};
		if( $settings{height} ne "ALL" && $settings{height} == 0 )
		{
			$settings{height} = undef;
		}

		if( $self->is_type( "subject" ) )
		{
			my $topsubj = $self->get_top_subject( $session );

			my ( $pairs ) = $topsubj->get_subjects( 
				!($self->{showall}), 
				$self->{showtop},
				0,
				($self->{input_style} eq "short"?1:0) );
			if( !$self->get_property( "multiple" ) && 
				!$req )
			{
				# If it's not multiple and not required there 
				# must be a way to unselect it.
				my $unspec = $session->phrase( 
					"lib/metafield:unspecified" ) ;
				$settings{pairs} = [ 
					[ "", $unspec ], 
					@{$pairs} ];
			}
			else
			{
				$settings{pairs} = $pairs;
			}
			$settings{defaults_at_top} = 1;
		} 
		else 
		{
			my($tags,$labels);
			if( $self->is_type( "set" ) )
			{
				$tags = $self->{options};
				$labels = {};
				foreach( @{$tags} ) 
				{ 
					$labels->{$_} = 
						EPrints::Utils::tree_to_utf8( 
							$self->render_option( 
								$session, 
								$_ ) );
				}
			}
			else # is "datatype"
			{
				my $ds = $session->get_archive()->get_dataset( 
						$self->{datasetid} );	
				$tags = $ds->get_types();
				$labels = $ds->get_type_names( $session );
			}
			if( 
				!$self->get_property( "multiple" ) && 
				!$req ) 
			{
				# If it's not multiple and not required there 
				# must be a way to unselect it.
				$settings{values} = [ "", @{$tags} ];
				my $unspec = $session->phrase( 
					"lib/metafield:unspecified" );
				$settings{labels} = { ""=>$unspec, %{$labels} };
			}
			else
			{
				$settings{values} = $tags;
				$settings{labels} = $labels;
			}
		}
		if( $self->get_property( "input_style" ) eq "long" )
		{
			my( $dl, $dt, $dd );
			$dl = $session->make_element( "dl", class=>"longset" );
			foreach my $opt ( @{$settings{values}} )
			{
				$dt = $session->make_element( "dt" );
				$dt->appendChild( $session->make_element(
					"input",
					"accept-charset" => "utf-8",
					type => "radio",
					name => $settings{name},
					value => $opt,
					checked => ( $settings{default}->[0] eq $opt ?"checked":undef) ));
				$dt->appendChild( $session->make_text( " ".$settings{labels}->{$opt} ));
				$dl->appendChild( $dt );
				$dd = $session->make_element( "dd" );
				my $phrasename = $self->{confid}."_optdetails_".$self->{name}."_".$opt;
				$dd->appendChild( $session->html_phrase( $phrasename ));
				$dl->appendChild( $dd );
			}
			$html->appendChild( $dl );
		}
		else
		{
			$html->appendChild( $session->render_option_list( %settings ) );
		}
		return $html;
	}
	# The other types require a loop if they are multiple.

	if( $self->get_property( "multiple" ) )
	{
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
		my $spacesid = $self->{name}."_spaces";

		if( $session->internal_button_pressed() )
		{
			$boxcount = $session->param( $spacesid );
			if( $session->internal_button_pressed( 
				$self->{name}."_morespaces" ) )
			{
				$boxcount += $self->{input_add_boxes};
			}
		}
	
		my $i;
		for( $i=1 ; $i<=$boxcount ; ++$i )
		{
			my $div;
			$div = $session->make_element( "div" );
			$div->appendChild( $session->make_text( $i.". " ) );
			$html->appendChild( $div );
			$div = $session->make_element( 
				"div", 
				id => "inputfield_".$self->get_name."_".$i,
				style=>"margin-left: 20px" ); #cjg NOT CSS
			$div->appendChild( 
				$self->_render_input_field_aux( 
					$session, 
					$value->[$i-1], 
					$i,
					$staff ) );
			$html->appendChild( $div );
		}
		$html->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "hidden",
			name => $spacesid,
			value => $boxcount ) );
		$html->appendChild( $session->render_internal_buttons(
			$self->{name}."_morespaces" => 
				$session->phrase( 
					"lib/metafield:more_spaces" ) ) );
	}
	else
	{
		$html->appendChild( 
			$self->_render_input_field_aux( 
				$session, 
				$value,
				undef,
				$staff ) );
	}

	return $html;
}



	

######################################################################
# 
# $xhtml = $field->_render_input_field_aux( $session, $value, $n, $staff )
#
# undocumented
#
######################################################################

sub _render_input_field_aux
{
	my( $self, $session, $value, $n, $staff ) = @_;

	my $suffix = (defined $n ? "_$n" : "" );	

	my $idvalue;
	if( $self->get_property( "hasid" ) )
	{
		$idvalue = $value->{id};
		$value = $value->{main};
	}
	my( $boxcount, $spacesid, $buttonid, $rows );

	if( $self->get_property( "multilang" ) )
	{
		$boxcount = 1;
		$spacesid = $self->{name}.$suffix."_langspaces";
		$buttonid = $self->{name}.$suffix."_morelangspaces";

		$rows = $session->make_doc_fragment();
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
			$langlabels{$_}=EPrints::Config::lang_title($_); 
		}
		foreach( @force ) { delete $langlabels{$_}; }
		my @langopts = ("", keys %langlabels );
		# cjg NOT LANG'd
		$langlabels{""} = "** Select Language **";
	
		my $i=1;
		my $langid;
		while( 
			scalar( @force ) > 0 || 
			$i <= $boxcount || 
			scalar( keys %langstodo ) > 0 )
		{
			my $langid = undef;
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
			
			my $langparamid = $self->{name}.$suffix."_".$i."_lang";
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
					$session->make_text( 
						EPrints::Config::lang_title( 
							$langid ) ) );
			}
			else
			{
				$langbit = $session->render_option_list(
					name => $langparamid,
					values => \@langopts,
					default => $langid,
					labels => \%langlabels );
			}
			
			my $aux2;
			if( $self->get_property( "hasid" ) )	
			{
				$aux2 = $self->get_main_field()->_render_input_field_aux2( $session, $value->{$langid}, $suffix."_".$i );
			}
			else
			{
				$aux2 = $self->_render_input_field_aux2( $session, $value->{$langid}, $suffix."_".$i );
			}

			if( $self->is_type( "name" ) )
			{
				my $tr = $session->make_element( "tr" );
				$rows->appendChild( $tr );
				$tr->appendChild( $aux2 );
				my $td = $session->make_element( "td" );
				$td->appendChild( $langbit );
				$tr->appendChild( $td );
			}
			else
			{
				my $div = $session->make_element( "div" );
				# cjg style?
				$div->appendChild( $aux2 );
				#space? cjg
				$div->appendChild( $langbit );
				$rows->appendChild( $div );
			}
			
			++$i;
		}
				
		$boxcount = $i-1;

	}
	else
	{
		if( $self->is_type( "name" ) )
		{
			$rows = $session->make_element( "tr" );
		} 
		else
		{
			$rows = $session->make_doc_fragment();
		}
		my $aux2;
		if( $self->get_property( "hasid" ) )	
		{
			$aux2 = $self->get_main_field()->_render_input_field_aux2( $session, $value, $suffix );
		}
		else
		{
			$aux2 = $self->_render_input_field_aux2( $session, $value, $suffix );
		}
		$rows->appendChild( $aux2 );
	}

	my $block = $session->make_doc_fragment();
	if( $self->is_type( "name" ) )
	{
		my( $table, $tr, $td, $th );
		$table = $session->make_element( "table" );
		$tr = $session->make_element( "tr" );
		$table->appendChild( $tr );
		
		unless( $session->get_archive()->get_conf( "hide_honourific" ) )
		{
			$th = $session->make_element( "th" );
			$th->appendChild( $session->html_phrase( 
						"lib/metafield:honourific" ) );
			$tr->appendChild( $th );
		}
		if( $session->get_archive()->get_conf( "invert_name_input" ) )
		{
			$th = $session->make_element( "th" );
			$th->appendChild( $session->html_phrase( 
						"lib/metafield:family_names" ) );
			$tr->appendChild( $th );

			$th = $session->make_element( "th" );
			$th->appendChild( $session->html_phrase( 
						"lib/metafield:given_names" ) );
			$tr->appendChild( $th );
	
		}
		else
		{
			$th = $session->make_element( "th" );
			$th->appendChild( $session->html_phrase( 
						"lib/metafield:given_names" ) );
			$tr->appendChild( $th );
	
			$th = $session->make_element( "th" );
			$th->appendChild( $session->html_phrase( 
						"lib/metafield:family_names" ) );
			$tr->appendChild( $th );

		}

		unless( $session->get_archive()->get_conf( "hide_lineage" ) )
		{
			$th = $session->make_element( "th" );
			$th->appendChild( $session->html_phrase( 
						"lib/metafield:lineage" ) );
			$tr->appendChild( $th );
		}

		$table->appendChild( $rows );
		$block->appendChild( $table );
	}
	else
	{
		$block->appendChild( $rows );
	}

	if( $self->get_property( "multilang" ) )
	{
		$block->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "hidden",
			name => $spacesid,
			value => $boxcount ) );
		$block->appendChild( $session->render_internal_buttons(
			$buttonid => $session->phrase( 
					"lib/metafield:more_langs" ) ) );
	}

	if( $self->get_property( "hasid" ) )
	{
		if( !$self->get_property( "id_editors_only" ) || $staff  )
		{
			my $div;
			$div = $session->make_element( 
						"div", 
						class => "formfieldidname" );
			$div->appendChild( $session->make_text( 
				$self->get_id_field()->display_name( $session ).":" ) );
			$block->appendChild( $div );
			$div = $session->make_element( 
						"div",
			 			class=>"formfieldidinput" );
			$block->appendChild( $div );
	
			$div->appendChild( $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				name => $self->{name}.$suffix."_id",
				value => $idvalue,
				size => $self->{input_id_cols} ) );
			$block->appendChild( $div );
		}
		else
		{
			$block->appendChild( $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "hidden",
				name => $self->{name}.$suffix."_id",
				value => $idvalue ) );
		}

	}
	
	return $block;
}

######################################################################
# 
# $xhtml = $field->_render_input_field_aux2( $session, $value, $suffix )
#
# undocumented
#
######################################################################

sub _render_input_field_aux2
{
	my( $self, $session, $value, $suffix ) = @_;

# not return DIVs? cjg (currently some types do some don't)

	if( $self->is_type( "longtext" ) || $self->{input_style} eq "textarea" )
	{
		my( $div , $textarea , $id );
 		$id = $self->{name}.$suffix;
		$div = $session->make_element( "div" );	
		$textarea = $session->make_element(
			"textarea",
			"accept-charset" => "utf-8",
			name => $id,
			rows => $self->{input_rows},
			cols => $self->{input_cols},
			wrap => "virtual" );
		$textarea->appendChild( $session->make_text( $value ) );
		$div->appendChild( $textarea );
		
		return $div;
	}

	if( $self->is_type( "text", "url", "int", "email", "year", "secret" ) )
	{
		my( $maxlength, $size, $div, $id );
 		$id = $self->{name}.$suffix;

		if( $self->is_type( "int" ) )
		{
			$maxlength = $self->{digits};
		}
		elsif( $self->is_type( "year" ) )
		{
			$maxlength = 4;
		}
		else
		{
			$maxlength = $self->{maxlength};
		}

		$size = ( $maxlength > $self->{input_cols} ?
					$self->{input_cols} : 
					$maxlength );

		my $input = $session->make_element(
			"input",
			type => ($self->is_type( "secret" )?"password":undef),
			"accept-charset" => "utf-8",
			name => $id,
			value => $value,
			size => $size,
			maxlength => $maxlength );
		return $input;
	}

	if( $self->is_type( "boolean" ) )
	{
		my( $div , $id);
 		$id = $self->{name}.$suffix;
		
		$div = $session->make_element( "div" );	
		if( $self->{input_style} eq "menu" )
		{
			my %settings = (
				height=>2,
				values=>[ "TRUE", "FALSE" ],
				labels=>{
TRUE=> $session->phrase( $self->{confid}."_fieldopt_".$self->{name}."_TRUE"),
FALSE=> $session->phrase( $self->{confid}."_fieldopt_".$self->{name}."_FALSE")
				},
				name=>$id,
				default=>$value
			);
			$div->appendChild( 
				$session->render_option_list( %settings ) );
		}
		elsif( $self->{input_style} eq "radio" )
		{
			# render as radio buttons

			my $true = $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "radio",
				checked=>( defined $value && $value eq 
						"TRUE" ? "checked" : undef ),
				name => $id,
				value => "TRUE" );
			my $false = $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "radio",
				checked=>( defined $value && $value ne 
						"TRUE" ? "checked" : undef ),
				name => $id,
				value => "FALSE" );
			$div->appendChild( $session->html_phrase(
				$self->{confid}."_radio_".$self->{name},
				true=>$true,
				false=>$false ) );
		}
		else
		{
			$div->appendChild( $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "checkbox",
				checked=>( defined $value && $value eq 
						"TRUE" ? "checked" : undef ),
				name => $id,
				value => "TRUE" ) );
		}
		return $div;
	}

	if( $self->is_type( "name" ) )
	{
		my( $td, $frag );
		$frag = $session->make_doc_fragment;
		my @namebits;
		unless( $session->get_archive()->get_conf( "hide_honourific" ) )
		{
			push @namebits, "honourific";
		}
		if( $session->get_archive()->get_conf( "invert_name_input" ) )
		{
			push @namebits, "family", "given";
		}
		else
		{
			push @namebits, "given", "family";
		}
		unless( $session->get_archive()->get_conf( "hide_lineage" ) )
		{
			push @namebits, "lineage";
		}
	
		foreach( @namebits )
		{
			my $size = $self->{input_name_cols}->{$_};
			$td = $session->make_element( "td" );
			$frag->appendChild( $td );
			$td->appendChild( $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				name => $self->{name}.$suffix."_".$_,
				value => $value->{$_},
				size => $size,
				maxlength => $self->{maxlength} ) );
		}
		return $frag;
	}

	if( $self->is_type( "pagerange" ) )
	{
		my( $div , @pages , $fromid, $toid );
		@pages = split /-/, $value if( defined $value );
 		$fromid = $self->{name}.$suffix."_from";
 		$toid = $self->{name}.$suffix."_to";
		
		$div = $session->make_element( "div" );	

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $fromid,
			value => $pages[0],
			size => 6,
			maxlength => 10 ) );

		$div->appendChild( $session->make_text(" ") );
		$div->appendChild( $session->html_phrase( 
			"lib/metafield:to" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $toid,
			value => $pages[1],
			size => 6,
			maxlength => 10 ) );
		return $div;
	}

	if( $self->is_type( "date" ) )
	{
		my( $frag, $div, $yearid, $monthid, $dayid );

		$frag = $session->make_doc_fragment;
		
		my $min_res = $self->get_property( "min_resolution" );
	
		if( $min_res eq "M" || $min_res eq "Y" )
		{	
			my( %r ) = ( D=>"d", M=>"m", Y=>"y" );
			$div = $session->make_element( "div", class=>"formfieldhelp" );	
			$div->appendChild( $session->html_phrase( 
				"lib/metafield:date_res_".$r{$min_res} ) );
			$frag->appendChild( $div );
		}

		$div = $session->make_element( "div" );
		my( $year, $month, $day ) = ("", "", "");
		if( defined $value && $value ne "" )
		{
			($year, $month, $day) = split /-/, $value;
			$month = "00" if( !defined $month || $month == 0 );
			$day = "00" if( !defined $day || $day == 0 );
			$year = "" if( !defined $year || $year == 0 );
		}
 		$dayid = $self->{name}.$suffix."_day";
 		$monthid = $self->{name}.$suffix."_month";
 		$yearid = $self->{name}.$suffix."_year";

		$div->appendChild( 
			$session->html_phrase( "lib/metafield:year" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $yearid,
			value => $year,
			size => 4,
			maxlength => 4 ) );

		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( 
			$session->html_phrase( "lib/metafield:month" ) );
		$div->appendChild( $session->make_text(" ") );
		$div->appendChild( $session->render_option_list(
			name => $monthid,
			values => \@monthkeys,
			default => $month,
			labels => $self->_month_names( $session ) ) );

		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( 
			$session->html_phrase( "lib/metafield:day" ) );
		$div->appendChild( $session->make_text(" ") );
#		$div->appendChild( $session->make_element(
#			"input",
#			"accept-charset" => "utf-8",
#			name => $dayid,
#			value => $day,
#			size => 2,
#			maxlength => 2 ) );
		my @daykeys = ();
		my %daylabels = ();
		for( 0..31 )
		{
			my $key = sprintf( "%02d", $_ );
			push @daykeys, $key;
			$daylabels{$key} = ($_==0?"?":$key);
		}
		$div->appendChild( $session->render_option_list(
			name => $dayid,
			values => \@daykeys,
			default => $day,
			labels => \%daylabels ) );

		$frag->appendChild( $div );
		return $frag;
	}

	if( $self->is_type( "search" ) )
	{
#cjg NOT CSS'd properly.
		my $div = $session->make_element( 
			"div", 
			style => "padding: 6pt; margin-left: 24pt; " );

		# cjg - make help an option?

		my $searchexp = $self->make_searchexp( 
			$session,
			$value,
			$self->{name}.$suffix."_" );
		$div->appendChild( $searchexp->render_search_fields( 0 ) );
		if( $self->get_property( "allow_set_order" ) )
		{
			$div->appendChild( $searchexp->render_order_menu );
		}
		$searchexp->dispose();

		return $div;
	}

	$session->get_archive()->log( "Don't know how to render input".
				  "field of type: ".$self->get_type() );
	return $session->make_text( "?? Unknown type: ".$self->get_type." ??" );
}

######################################################################
# 
# $searchexp = $field->make_searchexp( $session, $value, [$prefix] )
#
# This method should only be called on fields of type "search". 
# Return a search expression from the serialised expression in value.
# $prefix is passed to the SearchExpression to prefix all HTML form
# field ids when more than one search will exist in the same form. 
#
######################################################################

sub make_searchexp
{
	my( $self, $session, $value, $prefix ) = @_;

	unless( $self->is_type( "search" ) )
	{
		EPrints::Config::abort( <<END );
Attempt to call make_searchexp on a metafield which is not of type 'search'.
END
	}

	my $ds = $session->get_archive()->get_dataset( 
			$self->{datasetid} );	

	my $searchexp = EPrints::SearchExpression->new(
		session => $session,
		dataset => $ds,
		prefix => $prefix,
		fieldnames => $self->get_property( "fieldnames" ) );
	$searchexp->from_string( $value );

	return $searchexp;
}		


######################################################################
# 
# $months = $field->_month_names( $session )
#
# undocumented
#
######################################################################

sub _month_names
{
	my( $self , $session ) = @_;
	
	my $months = {};

	my $month;
	foreach $month ( @monthkeys )
	{
		$months->{$month} = EPrints::Utils::get_month_label( 
			$session, 
			$month );
	}

	return $months;
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

	my $value = $self->_form_value_aux0( $session );

	if( defined $self->{fromform} )
	{
		$value = &{$self->{fromform}}( $value, $session );
	}

	return $value;
}

######################################################################
# 
# $foo = $field->_form_value_aux0( $session )
#
# undocumented
#
######################################################################

sub _form_value_aux0
{
	my( $self, $session ) = @_;
	
	if( $self->is_type( "set", "subject", "datatype" ) ) 
	{
		my @values = $session->param( $self->{name} );
		
		if( scalar( @values ) == 0 )
		{
			return undef;
		}
		if( $self->get_property( "multiple" ) )
		{
			# Make sure all fields are unique
			# There could be two options with the same id,
			# especially in "subject"
			my %v;
			foreach( @values ) { $v{$_}=1; }
			delete $v{"-"}; # for the  ------- in defaults at top
			@values = keys %v;
			return \@values;
		}
	
		return $values[0];
	}

	if( $self->get_property( "multiple" ) )
	{
		my @values = ();
		my $boxcount = $session->param( $self->{name}."_spaces" );
		$boxcount = 1 if( $boxcount < 1 );
		my $i;
		for( $i=1; $i<=$boxcount; ++$i )
		{
			my $value = $self->_form_value_aux1( $session, $i );
			if( defined $value )
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

	return $self->_form_value_aux1( $session );
}

######################################################################
# 
# $foo = $field->_form_value_aux1( $session, $n )
#
# undocumented
#
######################################################################

sub _form_value_aux1
{
	my( $self, $session, $n ) = @_;

	my $suffix = "";
	$suffix = "_$n" if( defined $n );

	my $value;
	if( $self->get_property( "multilang" ) )
	{
		$value = {};
		my $boxcount = $session->param( 
			$self->{name}.$suffix."_langspaces" );
		$boxcount = 1 if( $boxcount < 1 );
		my $i;
		for( $i=1; $i<=$boxcount; ++$i )
		{
			my $subvalue = $self->_form_value_aux2( 
				$session, 
				$suffix."_".$i );
			my $langid = $session->param( 
				$self->{name}.$suffix."_".$i."_lang" );
			if( $langid eq "" ) 
			{ 
				$langid = "_".$i; 
			}
			if( defined $subvalue )
			{
				$value->{$langid} = $subvalue;
#cjg -- does not check that this is a valid langid...
			}
		}
		$value = undef if( scalar keys %{$value} == 0 );
	}
	else
	{
		$value = $self->_form_value_aux2( $session, $suffix );
	}
	if( $self->get_property( "hasid" ) )
	{
		my $id = $session->param( $self->{name}.$suffix."_id" );
		$value = { id=>$id, main=>$value };
	}
	return undef unless( EPrints::Utils::is_set( $value ) );

	return $value;
}

######################################################################
# 
# $foo = $field->_form_value_aux2( $session, $suffix )
#
# undocumented
#
######################################################################

sub _form_value_aux2
{
	my( $self, $session, $suffix ) = @_;
	
	if( $self->is_type( 
		"text", "url", "int", "email", "longtext", "year", 
		"secret", "id" ) )
	{
		my $value = $session->param( $self->{name}.$suffix );
		return undef if( $value eq "" );
		if( 
			!$self->is_type( "longtext" ) && 
			$self->{input_style} eq "textarea" )
		{
			$value=~s/[\n\r]+/ /gs;
		}
		return $value;
	}
	elsif( $self->is_type( "pagerange" ) )
	{
		my $from = $session->param( $self->{name}.$suffix."_from" );
		my $to = $session->param( $self->{name}.$suffix."_to" );

		if( !defined $to || $to eq "" )
		{
			return( $from );
		}
		
		return( $from . "-" . $to );
	}
	elsif( $self->is_type( "boolean" ) )
	{
		my $form_val = $session->param( $self->{name}.$suffix );
		my $true = 0;
		if( 
			$self->{input_style} eq "radio" || 
			$self->{input_style} eq "menu" )
		{
			$true = $form_val eq "TRUE";
		}
		else
		{
			$true = defined $form_val;
		}
		return ( $true ? "TRUE" : "FALSE" );
	}
	elsif( $self->is_type( "date" ) )
	{
		my $day = $session->param( $self->{name}.$suffix."_day" );
		my $month = $session->param( 
					$self->{name}.$suffix."_month" );
		my $year = $session->param( $self->{name}.$suffix."_year" );
		$month = undef if( !defined $month || $month == 0 );
		$year = undef if( !defined $year || $year == 0 );
		$day = undef if( !defined $day || $day == 0 );
		my $res = $self->get_property( "min_resolution" );

		if( defined $year && !defined $month && !defined $day )
		{
			if( $res eq "Y" )
			{
				return sprintf( "%04d", $year );
			}
			return undef;
		}

		if( defined $year && defined $month && !defined $day )
		{
			if( $res eq "Y" || $res eq "M" )
			{
				return sprintf( "%04d-%02d", $year, $month );
			}
			return undef;
		}

		if( defined $year && defined $month && defined $day )
		{
			return sprintf( "%04d-%02d-%02d", $year, $month, $day );
		}
		
		return undef;
	}
	elsif( $self->is_type( "name" ) )
	{
		my $data = {};
		foreach( "honourific", "given", "family", "lineage" )
		{
			$data->{$_} = 
				$session->param( $self->{name}.$suffix."_".$_ );
		}
		if( EPrints::Utils::is_set( $data ) )
		{
			return $data;
		}
		return undef;
	}
	elsif( $self->is_type( "search" ) )
	{
		my $ds = $session->get_archive()->get_dataset( 
				$self->{datasetid} );	
		my $searchexp = EPrints::SearchExpression->new(
			session => $session,
			dataset => $ds,
			prefix => $self->{name}.$suffix."_",
			fieldnames => $self->get_property( "fieldnames" ) );
		$searchexp->from_form;
		my $value = undef;
		unless( $searchexp->is_blank )
		{
			$value = $searchexp->serialise;	
		}
		$searchexp->dispose();

		return $value;
	}
	else
	{
		$session->get_archive()->log( 
			"Error: can't do _form_value_aux2 on type ".
			"'".$self->{type}."'" );
		return undef;
	}	
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
	my $idfield = $self->clone();
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
=pod

=item $sqlname = $field->get_sql_name

Return the name of this field as it appears in an SQL table.

=cut
######################################################################

sub get_sql_name
{
	my( $self ) = @_;

	if( $self->get_property( "idpart" ) )
	{
		return $self->{name}."_id";
	}
	if( $self->get_property( "mainpart" ) )
	{
		#cjg I'm not at all sure about if the main
		# bit should be the plain name or name_main
		#return $self->{name}."_main";

		return $self->{name};
	}
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
	my( $self ) = @_;
	
	# Can never browse:
	# pagerange , secret , longtext

	# Can't yet browse:
	# langid 

	return $self->is_type( "set", "subject", "datatype", "date", "int", 
				"year", "id", "email", "url", "text",
				"name", "boolean" );

}


######################################################################
=pod

=item @values = $field->get_values( $session, $dataset, %opts )

Return all the values of this field. For fields like "subject" or "set"
it returns all the variations. For fields like "text" return all 
the distinct values from the database.

=cut
######################################################################

sub get_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $langid = $opts{langid};
	if (!defined $langid)
	{
		$langid = $session->get_langid();
	}

	my @outvalues = ();

	if( $self->is_type( "set" ) )
	{
		return @{$self->get_property( "options" )};
	}
	elsif( $self->is_type( "subject" ) )
	{
		my $topsubj = $self->get_top_subject( $session );
		my ( $pairs ) = $topsubj->get_subjects( 
			0 , 
			!$opts{hidetoplevel} , 
			$opts{nestids} );
		my $pair;
		foreach $pair ( @{$pairs} )
		{
			push @outvalues, $pair->[0];
		}
	}
	elsif( $self->is_type( "datatype" ) )
	{
		my $ds = $session->get_archive()->get_dataset( 
				$self->{datasetid} );	
		@outvalues = @{$ds->get_types()};
	}
	elsif( $self->is_type( "boolean" ) )
	{
		@outvalues = ( "TRUE", "FALSE" );
	}
	elsif( $self->is_type( 
		"date", "int", "year", "id", "email", "url" , "text",
		"name" ) )
	{
		@outvalues = $session->get_db()->get_values( $self, $dataset );
	}
	else
	{
		$session->get_archive->log( "WARNING: Attempt to call get_values on a field of type ".$self->get_type );
	}

	foreach( @outvalues )
	{
		$_ = "" if( !defined $_ );
	}

	my $res = $self->get_property( "render_opts" )->{res};
	if( $self->is_type( "date" ) && $res ne "D" )
	{
		my $l = 10;
		if( $res eq "M" ) { $l = 7; }
		if( $res eq "Y" ) { $l = 4; }
		
		my %ov = ();
		foreach( @outvalues )
		{
			$ov{substr($_,0,$l)}=1;
		}
		@outvalues = keys %ov;
	}

	my %orderkeys = ();
	foreach my $value ( @outvalues )
	{
		# uses function aux1 because value will NEVER be multiple
		my $orderkey = $self->_ordervalue_aux1( 
			$value, 
			$session, 
			$langid );
		$orderkeys{$value} = $orderkey;
	}

	@outvalues = sort {$orderkeys{$a} cmp $orderkeys{$b}} @outvalues;

	return @outvalues;
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

	if( !EPrints::Utils::is_set( $value ) )
	{
		return $session->html_phrase( "lib/metafield:unspecified" );
	}
	if( $self->is_type( "set" ) )
	{
		return $self->render_option( $session, $value );
	}

	if( $self->is_type( "subject" ) )
	{
		my $subj = EPrints::Subject->new( $session, $value );
		if( !defined $subj )
		{
			return $session->make_text( 
				"?? Bad Subject: ".$value." ??" );
		}
		return $subj->render_description();
	}

	if( $self->is_type( "datatype" ) )
	{
		my $ds = $session->get_archive()->get_dataset( 
				$self->{datasetid} );	
		return $session->make_text( 
			$ds->get_type_name( $session, $value ) );
	}

	if( $self->is_type( "date" ) )
	{
		return EPrints::Utils::render_date( $session, $value );
	}

	# In some contexts people migth want the URL or email to be a link
	# but usually it's going to be a label, which can be a link in
	# itself. Which is weird, but I doubt anyone will browse by URL
	# anyway...

	if( $self->is_type( "int", "year", "email", "url", "text" ) )
	{
		return $session->make_text( $value );
	}

	if( $self->is_type( "id" ) )
	{
		return $session->get_archive()->call( 
			"id_label", 
			$self, 
			$session, 
			$value );
	}

	if( $self->is_type( "name" ) )
	{
		return $session->render_name( $value );
	}

	return $session->make_text( "???".$value."???" );
}



######################################################################
=pod

=item $ov = $field->ordervalue( $value, $archive, $langid )

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
		return &{$self->{make_value_orderkey}}( 
			$self, 
			$value, 
			$session, 
			$langid );
	}


	if( !$self->get_property( "multiple" ) )
	{
		return $self->_ordervalue_aux1( $value , $session , $langid );
	}

	my @r = ();	
	foreach( @$value )
	{
		push @r, $self->_ordervalue_aux1( $_ , $session , $langid );
	}
	return join( ":", @r );
}


######################################################################
# 
# $ov = $field->_ordervalue_aux1( $value, $session, $langid )
# 
# undocumented
# 
######################################################################

# cjg shouldn't we do main/id part BEFORE multilang?
sub _ordervalue_aux1
{
	my( $self , $value , $session , $langid ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	if( $self->is_type( "subject", "dataset", "set" ) )
	{
		my $label = $self->get_value_label( $session, $value );
		return EPrints::Utils::tree_to_utf8( $label );
	}

	if( !$self->get_property( "multilang" ) )
	{
		return $self->_ordervalue_aux2( $value );
	}

	return $self->_ordervalue_aux2( 
		EPrints::Session::best_language( 
			$session->get_archive,
			$langid,
			%{$value} ) );
}


######################################################################
# 
# $ov = $field->_ordervalue_aux2( $value )
# 
# undocumented
# 
######################################################################

sub _ordervalue_aux2
{
	my( $self , $value ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	# cjg: this test is acutally to supress an occasional error
	# from somewhere "upstream" in the code. Must figure it
	# out properly. Something to do with idpart ordervalues.

	my $v = $value;
	unless( ref($value) eq "" )
	{
		if( $self->get_property( "idpart" ) )
		{
			$v = $value->{id};
		}
		if( $self->get_property( "mainpart" ) )
		{
			$v = $value->{main};
		}
	}
	return $self->_ordervalue_aux3( $v );
}


######################################################################
#
# $ov = $field->_ordervalue_aux3( $value )
#
# undocumented
#
######################################################################

sub _ordervalue_aux3
{
	my( $self , $value ) = @_;

	return "" if( !defined $value );

	if( defined $self->{make_single_value_orderkey} )
	{
		return &{$self->{make_single_value_orderkey}}( 
			$self, 
			$value ); 
	}

	if( $self->is_type( "name" ) )
	{
		my @a;
		foreach( "family", "lineage", "given", "honourific" )
		{
			if( defined $value->{$_} )
			{
				push @a, $value->{$_};
			}
			else
			{
				push @a, "";
			}
		}
		return join( "," , @a );
	}

	if( $self->is_type( "int", "year" ) )
	{
		# just in case we still use eprints in year 200k 
		my $pad = 6; 
		if( $self->is_type( "int" ) )
		{
 			$pad = $self->get_property( "digits" ) ;
		}
		return sprintf( "%0".$pad."d",$value );
	}

	return $value;
}



######################################################################
=pod

=item $setting = $field->get_property_default( $property )

Return the default setting for the given field property.

=cut
######################################################################

sub get_property_default
{
	my( $self, $property ) = @_;

	my $archive = $self->{archive};

	foreach( 
		"search_cols", 
		"search_rows", 
		"digits", 
		"input_rows", 
		"input_cols", 
		"input_name_cols",
		"input_id_cols",
		"input_add_boxes", 
		"input_boxes" )
	{
		if( $property eq $_ )
		{
			return $archive->get_conf( "field_defaults" )->{$_};
		}
	}	

	if( $property eq "maxlength" )
	{
		return $VARCHAR_SIZE;
	}

	return [] if( $property eq "requiredlangs" );

	return "D" if( $property eq "min_resolution" );

	return 0 if( $property eq "input_style" );
	return 0 if( $property eq "hasid" );
	return 0 if( $property eq "multiple" );
	return 0 if( $property eq "multilang" );
	return 0 if( $property eq "required" );
	return 0 if( $property eq "showall" );
	return 0 if( $property eq "showtop" );
	return 0 if( $property eq "idpart" );
	return 0 if( $property eq "mainpart" );
	return 0 if( $property eq "id_editors_only" );
	return 1 if( $property eq "export_as_xml" );
	return 1 if( $property eq "can_clone" );
	return 1 if( $property eq "sql_index" );
	return 1 if( $property eq "allow_set_order" );

	return "subjects" if( $property eq "top" );

	return undef if( $property eq "browse_link" );
	return undef if( $property eq "confid" );
	return undef if( $property eq "fromform" );
	return undef if( $property eq "toform" );
	return undef if( $property eq "make_value_orderkey" );
	return undef if( $property eq "make_single_value_orderkey" );
	return undef if( $property eq "render_single_value" );
	return undef if( $property eq "render_value" );
	return undef if( $property eq "render_input" );
	return {} if( $property eq "render_opts" );

	EPrints::Config::abort( 
		"Unknown property in get_property_default: $property" );
};


######################################################################
=pod

=item $subject = $field->get_top_subject( $session )

Return the top EPrints::Subject object for this field. Only meaningful
for "subject" type fields.

=cut
######################################################################

sub get_top_subject
{
	my( $self, $session ) = @_;

	unless( $self->is_type( "subject" ) )
	{
		$session->render_error( $session->make_text( 
			'Attempt to call get_top_subject on a field not '.
			'of type subject. Field name '.
			'"'.$self->get_name().'".' ) );
		exit;
	}

	my $topid = $self->get_property( "top" );
	if( !defined $topid )
	{
		$session->render_error( $session->make_text( 
			'Subject field name "'.$self->get_name().'" has '.
			'no "top" property.' ) );
		exit;
	}
		
	my $topsubject = EPrints::Subject->new( $session, $topid );

	if( !defined $topsubject )
	{
		$session->render_error( $session->make_text( 
			'The top level subject (id='.$topid.') for field '.
			'"'.$self->get_name().'" does not exist. The '.
			'site admin probably has not run import_subjects. '.
			'See the documentation for more information.' ) );
		exit;
	}
	
	return $topsubject;
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

=item subject_browser_input

This is an alternate input renderer for "subject" fields. It is 
intended to be passed by reference to the render_input parameter
of such a field.

Due to the way this works, it is recommended that the "subjects"
type field it is used for is by itself on the metadata input page.

=cut
######################################################################

sub subject_browser_input
{
	my( $field, $session, $value, $dataset, $type, $staff, $hidden_fields ) = @_;

	my $values;
	if( !defined $value )
	{
		$values = [];
	}
	elsif( !$field->get_property( "multiple" ) )
	{
		$values = [ $value ]; 
	}
	else
	{
		$values = $value; 
	}

	my $topsubj = $field->get_top_subject( $session );
 	my $subject = $topsubj;

	my $html = $session->make_doc_fragment;

	if( $session->internal_button_pressed )
	{
		my $button = $session->get_internal_button();
		if( $button =~ m/^view_(.*)$/ )
		{
			$subject = EPrints::Subject->new( $session, $1 );
			if( !defined $subject ) 
			{ 
				$subject = $topsubj; 
				$html->appendChild( 
					$session->make_element( 
						"a", 
						name=>"t" ) );
			}
		}
	}

	my @param_pairs = ();
	foreach( keys %{$hidden_fields} )
	{
		push @param_pairs, $_.'='.$hidden_fields->{$_};
	}
	my $baseurl = '?'.join( '&', @param_pairs );

	my( %bits );

	$bits{selections} = $session->make_doc_fragment;

	foreach my $s_id ( sort @{$values} )
	{
		my $s = EPrints::Subject->new( $session, $s_id );
		next if( !defined $s );

		$html->appendChild( 
			$session->render_hidden_field(
				$field->get_name,
				$s_id ) );

		my $div = $session->make_element( "div" );
		$div->appendChild( $s->render_description );

		my $url = $baseurl.'&_internal_view_'.$subject->get_id.'=1'.$field->get_name.'='.$s->get_id;
		foreach my $v ( @{$values} )
		{
			next if( $v eq $s_id );
			$url.= '&'.$field->get_name.'='.$v;
		}
		$url .= '#t';

		$div->appendChild(  $session->html_phrase(
                        "lib/metafield:subject_browser_remove",
			link=>$session->make_element( "a", href=>$url ) ) );
		$bits{selections}->appendChild( $div );
	}

	if( scalar @{$values} == 0 )
	{	
		my $div = $session->make_element( "div" );
		$div->appendChild( $session->html_phrase(
			"lib/metafield:subject_browser_none" ) );
		$bits{selections}->appendChild( $div );
	}

	my @paths = $subject->get_paths( $session );
	my %expanded = ();
	foreach my $path ( @paths )
	{
		my $div = $session->make_element( "div" );
		my $first = 1;
		foreach my $s ( @{$path} )
		{
			$expanded{$s->get_id}=1;
		}
		$bits{selections}->appendChild( $div );
	}	

	$bits{topsubj} = $topsubj->render_description;
	$bits{opts} = $field->_subject_browser_input_aux( 
			$session,
			$topsubj,
			$subject,
			\%expanded,
			$baseurl,
			$values );

	$html->appendChild( $session->html_phrase( 
			"lib/metafield:subject_browser",
			%bits ) );

	return $html;
}


sub _subject_browser_input_aux
{
	my( $field, $session, $subj, $current_subj, $expanded, $baseurl, $values ) = @_;

	my $addurl = $baseurl;
	foreach my $v ( @{$values} )
	{
		$addurl.= '&'.$field->get_name.'='.$v;
	}

	my $ul = $session->make_element( "ul" );
	my $parent_id = $subj->get_id;
	foreach my $s ( $subj->children() )
	{
		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );
		my $n_kids = scalar $s->children();
		my $exp = 0;
		if( $n_kids > 0 )
		{
			if( $expanded->{$s->get_id} )
			#if( $expanded->{$s->get_id} || $n_kids < 3)
			{
				$exp = 1;
			}
			else
			{
				$exp = -1;
			}
		}
		my $selected = 0;
		foreach my $v ( @{$values} )
		{
			$selected = 1 if( $v eq $s->get_id );
		}
		if( $exp == -1 )
		{
			my $url = $addurl.'&_internal_view_'.$s->get_id.'=1#t';
			my $a = $session->make_element( "a", href=>$url );
			$a->appendChild( $s->render_description );
			$li->appendChild( $a );
			$li->appendChild( $session->html_phrase(
                        	"lib/metafield:subject_browser_expandable" ) );
		}
		else
		{
			my $span = $session->make_element( 
				"span", 
				class=>"subject_browser_".($selected?"":"un")."selected" );
			$span->appendChild( $s->render_description );
			$li->appendChild( $span );
		}
		if( $s->can_post && $exp != -1 && !$selected )
		{	
			my $url = $addurl.'&_internal_view_'.$current_subj->get_id.'=1&'.$field->get_name.'='.$s->get_id.'#t';
			$li->appendChild(  $session->html_phrase(
                        	"lib/metafield:subject_browser_add",
				link=>$session->make_element( "a", href=>$url ) ) );
		}
		if( $exp == 1 )
		{
			$li->appendChild( $session->make_element( "br" ));
			$li->appendChild( $field->_subject_browser_input_aux(
				$session, 
				$s, 
				$current_subj,
				$expanded, 
				$baseurl,
				$values ) );
		}

		$ul->appendChild( $li );
	}
	
	return $ul;
}



######################################################################
=pod

=item render_pagerange_pp

This is a renderer for pagerange type fields which renders the range
as:
pp.100-102

unless both values are equal, in which case it renders:
p.23

At a later date it may compess ranges eg.
103-109 becomes 103-9, but I've not found a reliable guide to the
correct way to do this yet.

=cut
######################################################################

sub render_pagerange_pp
{
	my( $session, $field, $value ) = @_;

	unless( $value =~ m/^(\d+)-(\d+)$/ )
	{
		# value not in expected form. Ah, well. Muddle through.
		return $session->make_text( $value );
	}

	my( $a, $b ) = ( $1, $2 );
	
	if( $a == $b )
	{
		return $session->make_text( 'p.'.$a );
	}

#	if( length $a == length $b )
#	{
#	}
		

	return $session->make_text( 'pp.'.$a.'-'.$b );
}



######################################################################

1;

=pod

=back

=cut
