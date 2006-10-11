######################################################################
#
# EPrints::MetaField::Basic;
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

B<EPrints::MetaField::Basic> - no description

=head1 DESCRIPTION

Base class for all other metafield types. Sets the most common return 
values etc.

This could go in MetaField.pm but it makes it clearer to have it
seperated out.

=over 4

=cut

package EPrints::MetaField::Basic;

use strict;
use warnings;

use EPrints::MetaField;
use EPrints::Session;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

my $VARCHAR_SIZE = 255;

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

	return $self->get_sql_name()." VARCHAR($VARCHAR_SIZE)".($notnull?" NOT NULL":"");
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

=item $xhtml_dom = $field->render_single_value( $value, $dont_link )

Returns the XHTML representation of the value. The value will be
non-multiple and non-multilang and have no "id" part. Just the
simple value.

If $dont_link then do not render any hypertext links in the returned XHTML.

=cut
######################################################################

sub render_single_value
{
	my( $self, $value, $dont_link ) = trim_params(@_);

	return &SESSION->make_text( $value );
}




######################################################################
=pod

=item $xhtml = $field->render_input_field_actual( $value, [$dataset, $type], [$staff], [$hidden_fields], [$obj] )

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
	my( $self, $value, $dataset, $type, $staff, $hidden_fields, $obj ) = trim_params(@_);

	my $elements = $self->get_input_elements( $value, $staff, $obj );

	# if there's only one element then lets not bother making
	# a table to put it in

	if( scalar @{$elements} == 1 && scalar @{$elements->[0]} == 1 )
	{
		return $elements->[0]->[0]->{el};
	}

	my $table = &SESSION->make_element( "table", border=>0 );

	my $col_titles = $self->get_input_col_titles( $staff );
	if( defined $col_titles || $self->get_property( "hasid" ) )
	{
		my $tr = &SESSION->make_element( "tr" );
		my $th;
		if( $self->get_property( "multiple" ) )
		{
			$th = &SESSION->make_element( "th" );
			$tr->appendChild( $th );
		}
		if( !defined $col_titles )
		{
			$th = &SESSION->make_element( "th" );
			$tr->appendChild( $th );
		}	
		else
		{
			foreach my $col_title ( @{$col_titles} )
			{
				$th = &SESSION->make_element( "th" );
				$th->appendChild( $col_title );
				$tr->appendChild( $th );
			}
		}
		if( $self->get_property( "multilang" ) )
		{
			$th = &SESSION->make_element( "th" );
			$tr->appendChild( $th );
		}
		if( $self->get_property( "hasid" ) )
		{
			$th = &SESSION->make_element( "th" );
			$th->appendChild( $self->get_id_field()->render_name );
			$tr->appendChild( $th );
		}
		$table->appendChild( $tr );
	}

	foreach my $row ( @{$elements} )
	{
		my $tr = &SESSION->make_element( "tr" );
		foreach my $item ( @{$row} )
		{
			my %opts = ( valign=>"top" );
			foreach my $prop ( keys %{$item} )
			{
				next if( $prop eq "el" );
				$opts{$prop} = $item->{$prop};
			}	
			my $td = &SESSION->make_element( "td", %opts );
			if( defined $item->{el} )
			{
				$td->appendChild( $item->{el} );
			}
			$tr->appendChild( $td );
		}
		$table->appendChild( $tr );
	}

	return $table;
}

sub get_input_col_titles
{
	my( $self, $staff ) = trim_params(@_);
	return undef;
}

sub get_input_elements
{
	my( $self, $value, $staff, $obj ) = trim_params(@_);

	unless( $self->get_property( "multiple" ) )
	{
		return $self->get_input_elements_single( 
				$value,
				undef,
				$staff,
				$obj );
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
	my $spacesid = $self->{name}."_spaces";

	if( &SESSION->internal_button_pressed() )
	{
		$boxcount = &SESSION->param( $spacesid );
		if( &SESSION->internal_button_pressed( 
			$self->{name}."_morespaces" ) )
		{
			$boxcount += $self->{input_add_boxes};
		}

		for( my $i=1 ; $i<=$boxcount ; ++$i )
		{
			if( $i>1 && &SESSION->internal_button_pressed( $self->{name}."_up_".$i ) )
			{
				my( $a, $b ) = ( $value->[$i-1], $value->[$i-2] );
				( $value->[$i-1], $value->[$i-2] ) = ( $b, $a );
			}
			if( &SESSION->internal_button_pressed( $self->{name}."_down_".$i ) )
			{
				my( $a, $b ) = ( $value->[$i-1], $value->[$i+0] );
				( $value->[$i-1], $value->[$i+0] ) = ( $b, $a );
				# If the last item was moved down then extend boxcount by 1
				$boxcount++ if( $i == $boxcount ); 
			}
				
		}

	}


	my $rows = [];
	for( my $i=1 ; $i<=$boxcount ; ++$i )
	{
		my $section = $self->get_input_elements_single( 
				$value->[$i-1], 
				$i,
				$staff,
				$obj );
		my $first = 1;
		for my $n (0..(scalar @{$section})-1)
		{
			my $col1 = {};
			my $lastcol = {};
			if( $n == 0 )
			{
				$col1 = { el=>&SESSION->make_text( $i.". " ) };
				my $arrows = &SESSION->make_doc_fragment;
				if( $i > 1 )
				{
					$arrows->appendChild( &SESSION->make_element(
						"input",
						type=>"image",
						alt=>"up",
						src=> &ARCHIVE->get_conf( "base_url" )."/images/multi_up.png",
                				name=>"_internal_".$self->{name}."_up_$i",
						value=>"1" ));
				}
				else
				{
					$arrows->appendChild( &SESSION->make_element(
						"img",
						alt=>"up",
						src=> &ARCHIVE->get_conf( "base_url" )."/images/multi_up_dim.png" ));
				}
				$arrows->appendChild( &SESSION->make_element( "br" ) );
				if( 1 )
				{
					$arrows->appendChild( &SESSION->make_element(
						"input",
						type=>"image",
						src=> &ARCHIVE->get_conf( "base_url" )."/images/multi_down.png",
						alt=>"down",
                				name=>"_internal_".$self->{name}."_down_$i",
						value=>"1" ));
				}
				else
				{
					$arrows->appendChild( &SESSION->make_element(
						"img",
						alt=>"down",
						src=> &ARCHIVE->get_conf( "base_url" )."/images/multi_down_dim.png" ));
				}
				$lastcol = { el=>$arrows, valign=>"middle" };
			}
			push @{$rows}, [ $col1, @{$section->[$n]}, $lastcol ];
		}
	}
	my $more = &SESSION->make_doc_fragment;
	$more->appendChild( &SESSION->make_element(
		"input",
		"accept-charset" => "utf-8",
		type => "hidden",
		name => $spacesid,
		value => $boxcount ) );
	$more->appendChild( &SESSION->render_internal_buttons(
		$self->{name}."_morespaces" => 
			&SESSION->phrase( 
				"lib/metafield:more_spaces" ) ) );

	push @{$rows}, [ {}, {el=>$more,colspan=>3} ];

	return $rows;
}




######################################################################
# 
# $xhtml = $field->get_input_elements_single( $value, $n, $staff, $obj )
#
# undocumented
#
######################################################################

sub get_input_elements_single
{
	my( $self, $value, $suffix, $staff, $obj ) = trim_params(@_);

	$suffix = (defined $suffix ? "_$suffix" : "" );	

	unless( $self->get_property( "hasid" ) )
	{
		return $self->get_input_elements_no_id( 
			$value, 
			$suffix, 
			$staff,
			$obj );
	}

	my $elements = $self->get_input_elements_no_id( 
		$value->{main}, 
		$suffix, 
		$staff,
		$obj );

	my $idvalue = $value->{id};


	# id_editors_only is _not_ security feature, it's just
	# to stop normal users getting bothered by confusing
	# ID fields.
	if( $self->get_property( "id_editors_only" ) && !$staff  )
	{
		my $f = &SESSION->make_doc_fragment;
		my $hidden = &SESSION->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "hidden",
				name => $self->{name}.$suffix."_id",
				value => $idvalue );
		# cache it in the table...
		my $firstel = $elements->[0]->[0];
		if( defined $firstel->{el} )
		{
			$f->appendChild( $firstel->{el} );
		}
		$f->appendChild( $hidden );
		$firstel->{el} = $f;

		return $elements;
	}

	my $div = &SESSION->make_element( 
			"div",
			class=>"formfieldidinput" );
	$div->appendChild( &SESSION->make_element(
		"input",
		"accept-charset" => "utf-8",
		name => $self->{name}.$suffix."_id",
		value => $idvalue,
		size => $self->{input_id_cols} ) );

	my $first = 1;
	for my $n (0..(scalar @{$elements})-1)
	{
		my $lastcol = {};
		if( $n == 0 )
		{
			$lastcol = { el=>$div };
		}
		push @{$elements->[$n]}, $lastcol;
	}
	
	return $elements;
}

sub get_input_elements_no_id
{
	my( $self, $value, $suffix, $staff, $obj ) = trim_params(@_);

	unless( $self->get_property( "multilang" ) )
	{
		return $self->get_basic_input_elements( 
			$value, 
			$suffix, 
			$staff,
			$obj );
	}


	my $boxcount = 1;
	my $spacesid = $self->{name}.$suffix."_langspaces";
	my $buttonid = $self->{name}.$suffix."_morelangspaces";

	if( &SESSION->internal_button_pressed() )
	{
		if( defined &SESSION->param( $spacesid ) )
		{
			$boxcount = &SESSION->param( $spacesid );
		}
		if( &SESSION->internal_button_pressed( $buttonid ) )
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
			&SESSION->render_language_name( $_ ) );
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
		
		my $langparamid = $self->{name}.$suffix."_".$i."_lang";
		my $langbit;
		if( $forced )
		{
			$langbit = &SESSION->make_element( 
				"span", 
				class => "requiredlang" );
			$langbit->appendChild( &SESSION->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "hidden",
				name => $langparamid,
				value => $langid ) );
			$langbit->appendChild( 
				&SESSION->render_language_name( $langid ) );
		}
		else
		{
			$langbit = &SESSION->render_option_list(
				name => $langparamid,
				values => \@langopts,
				default => $langid,
				labels => \%langlabels );
		}
	
		my $elements = $self->get_basic_input_elements( 
			$value->{$langid}, 
			$suffix."_".$i, 
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

	my $more = &SESSION->make_doc_fragment;	
	$more->appendChild( &SESSION->make_element(
		"input",
		"accept-charset" => "utf-8",
		type => "hidden",
		name => $spacesid,
		value => $boxcount ) );
	$more->appendChild( &SESSION->render_internal_buttons(
		$buttonid => &SESSION->phrase( 
				"lib/metafield:more_langs" ) ) );

	push @{$rows}, [ { el=>$more} ];

	return $rows;
}	



sub get_basic_input_elements
{
	my( $self, $value, $suffix, $staff, $obj ) = trim_params(@_);

	my $maxlength = $self->get_max_input_size;
	my $size = ( $maxlength > $self->{input_cols} ?
					$self->{input_cols} : 
					$maxlength );
	my $input = &SESSION->make_element(
		"input",
		"accept-charset" => "utf-8",
		name => $self->{name}.$suffix,
		value => $value,
		size => $size,
		maxlength => $maxlength );

	return [ [ { el=>$input } ] ];
}

sub get_max_input_size
{
	return $VARCHAR_SIZE;
}





######################################################################
# 
# $foo = $field->form_value_actual()
#
# undocumented
#
######################################################################

sub form_value_actual
{
	my( $self ) = trim_params(@_);

	if( $self->get_property( "multiple" ) )
	{
		my @values = ();
		my $boxcount = &SESSION->param( $self->{name}."_spaces" );
		$boxcount = 1 if( $boxcount < 1 );
		for( my $i=1; $i<=$boxcount; ++$i )
		{
			my $value = $self->form_value_single( $i );
			if( defined $value || &SESSION->internal_button_pressed )
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

	return $self->form_value_single;
}

######################################################################
# 
# $foo = $field->form_value_single( $n )
#
# undocumented
#
######################################################################

sub form_value_single
{
	my( $self, $n ) = trim_params(@_);

	my $suffix = "";
	$suffix = "_$n" if( defined $n );

	my $value = $self->form_value_no_id( $suffix );

	if( $self->get_property( "hasid" ) )
	{
		my $id = &SESSION->param( $self->{name}.$suffix."_id" );
		if( 
			!EPrints::Utils::is_set( $value ) &&
			!EPrints::Utils::is_set( $id ) )
		{
			# id part and main part are undef!
			return undef;
		}
		return { id=>$id, main=>$value };
	}

	return $value;
}

sub form_value_no_id
{
	my( $self, $suffix ) = trim_params(@_);

	unless( $self->get_property( "multilang" ) )
	{
		# simple case; not multilang
		my $value = $self->form_value_basic( $suffix );
		return undef unless( EPrints::Utils::is_set( $value ) );
		return $value;
	}

	my $value = {};
	my $boxcount = &SESSION->param( $self->{name}.$suffix."_langspaces" );
	$boxcount = 1 if( $boxcount < 1 );
	for( my $i=1; $i<=$boxcount; ++$i )
	{
		my $subvalue = $self->form_value_basic( 
			$suffix."_".$i );
		my $langid = &SESSION->param( 
			$self->{name}.$suffix."_".$i."_lang" );
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
# $foo = $field->form_value_basic( $suffix )
#
# undocumented
#
######################################################################

sub form_value_basic
{
	my( $self, $suffix ) = trim_params(@_);
	
	my $value = &SESSION->param( $self->{name}.$suffix );

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
	return( 1 );
}


######################################################################
=pod

=item $values = $field->get_values( $dataset, %opts )

Return a reference to an array of all the values of this field. 
For fields like "subject" or "set"
it returns all the variations. For fields like "text" return all 
the distinct values from the database.

Results are sorted according to the ordervalues of the session.

=cut
######################################################################


sub get_values
{
	my( $self, $dataset, %opts ) = trim_params(@_);

	my $langid = $opts{langid};
	$langid = &SESSION->get_langid unless( defined $langid );

	my $unsorted_values = $self->get_unsorted_values( 
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
			$langid );
		$orderkeys{$v2} = $orderkey;
	}

	my @outvalues = sort {$orderkeys{$a} cmp $orderkeys{$b}} @values;

	return \@outvalues;
}

sub get_unsorted_values
{
	my( $self, $dataset, %opts ) = trim_params(@_);

	return &DATABASE->get_values( $self, $dataset );
}

######################################################################
=pod

=item $xhtml = $field->get_value_label( $value )

Return an XHTML DOM object describing the given value. Normally this
is just the value, but in the case of something like a "set" field 
this returns the name of the option in the current language.

=cut
######################################################################

sub get_value_label
{
	my( $self, $value ) = trim_params(@_);

	return &SESSION->make_text( $value );
}



#	if( $self->is_type( "id" ) )
#	{
#		return &ARCHIVE->call( 
#			"id_label", 
#			$self, 
#			$value );
#	}


######################################################################
=pod

=item $ov = $field->ordervalue( $value, $langid )

Return a string representing this value which can be used to sort
it into order by comparing it alphabetically.

=cut
######################################################################

sub ordervalue
{
	my( $self , $value , $langid ) = trim_params(@_);

	return "" if( !defined $value );

	if( defined $self->{make_value_orderkey} )
	{
		return &{$self->{make_value_orderkey}}( 
			&SESSION,
			$self, 
			$value, 
			$langid );
	}


	if( !$self->get_property( "multiple" ) )
	{
		return $self->ordervalue_single( $value , $langid );
	}

	my @r = ();	
	foreach( @$value )
	{
		push @r, $self->ordervalue_single( $_ , $langid );
	}
	return join( ":", @r );
}


######################################################################
# 
# $ov = $field->ordervalue_single( $value, $langid )
# 
# undocumented
# 
######################################################################

sub ordervalue_single
{
	my( $self , $value , $langid ) = trim_params(@_);

	return "" unless( EPrints::Utils::is_set( $value ) );

	unless( ref($value) eq "" )
	{
		if( $self->get_property( "idpart" ) )
		{
			$value = $value->{id};
		}
		if( $self->get_property( "mainpart" ) )
		{
			$value = $value->{main};
		}
	}
	# what if it HAS id but is not a sub-part??

	return $self->ordervalue_no_id( $value, $langid );
}

sub ordervalue_no_id
{
	my( $self , $value , $langid ) = trim_params(@_);

	return "" unless( EPrints::Utils::is_set( $value ) );

	if( $self->get_property( "multilang" ) )
	{
		$value = EPrints::Session::best_language( 
			$langid,
			%{$value} );
	}

	if( defined $self->{make_single_value_orderkey} )
	{
		return &{$self->{make_single_value_orderkey}}( 
			&SESSION,
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




sub render_search_input
{
	my( $self, $searchfield ) = trim_params(@_);
	
	my $frag = &SESSION->make_doc_fragment;

	# complex text types
	$frag->appendChild(
		&SESSION->make_element( "input",
			"accept-charset" => "utf-8",
			type => "text",
			name => $searchfield->get_form_prefix,
			value => $searchfield->get_value,
			size => $self->get_property( "search_cols" ),
			maxlength => 256 ) );
	$frag->appendChild( &SESSION->make_text(" ") );
	my @text_tags = ( "ALL", "ANY" );
	my %text_labels = ( 
		"ANY" => &SESSION->phrase( "lib/searchfield:text_any" ),
		"ALL" => &SESSION->phrase( "lib/searchfield:text_all" ) );
	$frag->appendChild( 
		&SESSION->render_option_list(
			name=>$searchfield->get_form_prefix."_merge",
			values=>\@text_tags,
			default=>$searchfield->get_merge,
			labels=>\%text_labels ) );
	return $frag;
}

sub from_search_form
{
	my( $self, $prefix ) = trim_params(@_);

	# complex text types

	my $val = &SESSION->param( $prefix );
	return unless defined $val;

	my $search_type = &SESSION->param( $prefix."_merge" );
		
	# Default search type if none supplied (to allow searches 
	# using simple HTTP GETs)
	$search_type = "ALL" unless defined( $search_type );		
		
	return unless( defined $val );

	return( $val, $search_type, "IN" );	
}		


sub render_search_description
{
	my( $self, $sfname, $value, $merge, $match ) = trim_params(@_);

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
		$value );
	
	return &SESSION->html_phrase(
		$phraseid,
		name => $sfname, 
		value => $valuedesc );
}

sub render_search_value
{
	my( $self, $value ) = trim_params(@_);

	return &SESSION->make_text( '"'.$value.'"' );
}	

sub split_search_value
{
	my( $self, $value ) = trim_params(@_);

#	return EPrints::Index::split_words( 
#			EPrints::Index::apply_mapping( $value ) );

	return split /\s+/, $value;
}

sub get_search_conditions
{
	my( $self, $dataset, $search_value, $match, $merge,
		$search_mode ) = trim_params(@_);

	if( $match eq "EX" )
	{
		if( $search_value eq "" )
		{	
			return EPrints::SearchCondition->new( 
					'is_null', 
					$dataset, 
					$self );
		}

		return EPrints::SearchCondition->new( 
				'=', 
				$dataset, 
				$self, 
				$search_value );
	}

	return $self->get_search_conditions_not_ex(
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
		browse_link 	=> $EPrints::MetaField::UNDEF,
		can_clone 	=> 1,
		confid 		=> $EPrints::MetaField::NO_CHANGE,
		export_as_xml 	=> 1,
		fromform 	=> $EPrints::MetaField::UNDEF,
		hasid 		=> 0,
		id_editors_only	=> 0,
		idpart 		=> 0, # internal
		input_add_boxes => $EPrints::MetaField::FROM_CONFIG,
		input_boxes 	=> $EPrints::MetaField::FROM_CONFIG,
		input_cols 	=> $EPrints::MetaField::FROM_CONFIG,
		input_id_cols	=> $EPrints::MetaField::FROM_CONFIG,
		mainpart 	=> 0, #internal
		make_single_value_orderkey 	=> $EPrints::MetaField::UNDEF,
		make_value_orderkey 		=> $EPrints::MetaField::UNDEF,
		maxlength 	=> $VARCHAR_SIZE,
		multilang 	=> 0,
		multiple 	=> 0,
		name 		=> $EPrints::MetaField::REQUIRED,
		render_input 	=> $EPrints::MetaField::UNDEF,
		render_opts 	=> {},
		render_single_value 	=> $EPrints::MetaField::UNDEF,
		render_value 	=> $EPrints::MetaField::UNDEF,
		required 	=> 0,
		requiredlangs 	=> [],
		search_cols 	=> $EPrints::MetaField::FROM_CONFIG,
		sql_index 	=> 1,
		toform 		=> $EPrints::MetaField::UNDEF,
		type 		=> $EPrints::MetaField::REQUIRED );
}
		
# Most types are not indexed		
sub get_index_codes
{
	my( $self, $value ) = trim_params(@_);

	return( [], [], [] );
}

sub get_value
{
	my( $self, $object ) = @_;

	return $object->get_value_raw( $self->{name} );
}

######################################################################

1;

=pod

=back

=cut

