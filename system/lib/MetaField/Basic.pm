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

=item $xhtml_dom = $field->render_single_value( $session, $value, $dont_link )

Returns the XHTML representation of the value. The value will be
non-multiple and non-multilang and have no "id" part. Just the
simple value.

If $dont_link then do not render any hypertext links in the returned XHTML.

=cut
######################################################################

sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;

	return $session->make_text( $value );
}




######################################################################
=pod

=item $xhtml = $field->render_input_field_actual( $session, $value, [$dataset, $type], [$staff], [$hidden_fields] )

Return the XHTML of the fields for an form which will allow a user
to input metadata to this field. $value is the default value for
this field.

Unlike render_input_field, this function does not use the render_input
property, even if it's set.

=cut
######################################################################

sub render_input_field_actual
{
	my( $self, $session, $value, $dataset, $type, $staff, $hidden_fields ) = @_;

	my $elements = $self->get_input_elements( $session, $value, $staff );

	# if there's only one element then lets not bother making
	# a table to put it in

	if( scalar @{$elements} == 1 && scalar @{$elements->[0]} == 1 )
	{
		return $elements->[0]->[0]->{el};
	}

	my $table = $session->make_element( "table", border=>0 );

	my $col_titles = $self->get_input_col_titles( $session, $staff );
	if( defined $col_titles || $self->get_property( "hasid" ) )
	{
		my $tr = $session->make_element( "tr" );
		my $th;
		if( $self->get_property( "multiple" ) )
		{
			$th = $session->make_element( "th" );
			$tr->appendChild( $th );
		}
		if( !defined $col_titles )
		{
			$th = $session->make_element( "th" );
			$tr->appendChild( $th );
		}	
		else
		{
			foreach my $col_title ( @{$col_titles} )
			{
				$th = $session->make_element( "th" );
				$th->appendChild( $col_title );
				$tr->appendChild( $th );
			}
		}
		if( $self->get_property( "multilang" ) )
		{
			$th = $session->make_element( "th" );
			$tr->appendChild( $th );
		}
		if( $self->get_property( "hasid" ) )
		{
			$th = $session->make_element( "th" );
			$th->appendChild( 
				$self->get_id_field()->render_name( 
								$session ) );
			$tr->appendChild( $th );
		}
		$table->appendChild( $tr );
	}

	foreach my $row ( @{$elements} )
	{
		my $tr = $session->make_element( "tr" );
		foreach my $item ( @{$row} )
		{
			my %opts = ( valign=>"top" );
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
	my( $self, $session, $value, $staff ) = @_;	

	unless( $self->get_property( "multiple" ) )
	{
		return $self->get_input_elements_single( 
				$session, 
				$value,
				undef,
				$staff );
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

	if( $session->internal_button_pressed() )
	{
		$boxcount = $session->param( $spacesid );
		if( $session->internal_button_pressed( 
			$self->{name}."_morespaces" ) )
		{
			$boxcount += $self->{input_add_boxes};
		}

		for( my $i=1 ; $i<=$boxcount ; ++$i )
		{
			if( $i>1 && $session->internal_button_pressed( $self->{name}."_up_".$i ) )
			{
				my( $a, $b ) = ( $value->[$i-1], $value->[$i-2] );
				( $value->[$i-1], $value->[$i-2] ) = ( $b, $a );
			}
			if( $session->internal_button_pressed( $self->{name}."_down_".$i ) )
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
				$session, 
				$value->[$i-1], 
				$i,
				$staff );
		my $first = 1;
		for my $n (0..(scalar @{$section})-1)
		{
			my $col1 = {};
			my $lastcol = {};
			if( $n == 0 )
			{
				$col1 = { el=>$session->make_text( $i.". " ) };
				my $arrows = $session->make_doc_fragment;
				if( $i > 1 )
				{
					$arrows->appendChild( $session->make_element(
						"input",
						type=>"image",
						src=> $session->get_archive->get_conf( "base_url" )."/images/up.png",
                				name=>"_internal_".$self->{name}."_up_$i",
						value=>"1" ));
				}
				else
				{
					$arrows->appendChild( $session->make_element(
						"img",
						src=> $session->get_archive->get_conf( "base_url" )."/images/up_dim.png" ));
				}
				$arrows->appendChild( $session->make_element( "br" ) );
				if( 1 )
				{
					$arrows->appendChild( $session->make_element(
						"input",
						type=>"image",
						src=> $session->get_archive->get_conf( "base_url" )."/images/down.png",
                				name=>"_internal_".$self->{name}."_down_$i",
						value=>"1" ));
				}
				else
				{
					$arrows->appendChild( $session->make_element(
						"img",
						src=> $session->get_archive->get_conf( "base_url" )."/images/down_dim.png" ));
				}
				$lastcol = { el=>$arrows, valign=>"middle" };
			}
			push @{$rows}, [ $col1, @{$section->[$n]}, $lastcol ];
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
		$self->{name}."_morespaces" => 
			$session->phrase( 
				"lib/metafield:more_spaces" ) ) );

	push @{$rows}, [ {}, {el=>$more,colspan=>3} ];

	return $rows;
}




######################################################################
# 
# $xhtml = $field->get_input_elements_single( $session, $value, $n, $staff )
#
# undocumented
#
######################################################################

sub get_input_elements_single
{
	my( $self, $session, $value, $suffix, $staff ) = @_;

	$suffix = (defined $suffix ? "_$suffix" : "" );	

	unless( $self->get_property( "hasid" ) )
	{
		return $self->get_input_elements_no_id( 
			$session, 
			$value, 
			$suffix, 
			$staff );
	}

	my $elements = $self->get_input_elements_no_id( 
		$session, 
		$value->{main}, 
		$suffix, 
		$staff );

	my $idvalue = $value->{id};


	# id_editors_only is _not_ security feature, it's just
	# to stop normal users getting bothered by confusing
	# ID fields.
	if( $self->get_property( "id_editors_only" ) && !$staff  )
	{
		my $f = $session->make_doc_fragment;
		my $hidden = $session->make_element(
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

	my $div = $session->make_element( 
			"div",
			class=>"formfieldidinput" );
	$div->appendChild( $session->make_element(
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
	my( $self, $session, $value, $suffix, $staff ) = @_;

	unless( $self->get_property( "multilang" ) )
	{
		return $self->get_basic_input_elements( 
			$session, 
			$value, 
			$suffix, 
			$staff );
	}


	my $boxcount = 1;
	my $spacesid = $self->{name}.$suffix."_langspaces";
	my $buttonid = $self->{name}.$suffix."_morelangspaces";

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

	my $rows = [];	
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
	
		my $elements = $self->get_basic_input_elements( 
			$session, 
			$value->{$langid}, 
			$suffix, 
			$staff );

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
	my( $self, $session, $value, $suffix, $staff ) = @_;

	my $maxlength = $self->get_max_input_size;
	my $size = ( $maxlength > $self->{input_cols} ?
					$self->{input_cols} : 
					$maxlength );
	my $input = $session->make_element(
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
# $foo = $field->form_value_actual( $session )
#
# undocumented
#
######################################################################

sub form_value_actual
{
	my( $self, $session ) = @_;
	
	if( $self->get_property( "multiple" ) )
	{
		my @values = ();
		my $boxcount = $session->param( $self->{name}."_spaces" );
		$boxcount = 1 if( $boxcount < 1 );
		for( my $i=1; $i<=$boxcount; ++$i )
		{
			my $value = $self->form_value_single( $session, $i );
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

	return $self->form_value_single( $session );
}

######################################################################
# 
# $foo = $field->form_value_single( $session, $n )
#
# undocumented
#
######################################################################

sub form_value_single
{
	my( $self, $session, $n ) = @_;

	my $suffix = "";
	$suffix = "_$n" if( defined $n );

	my $value = $self->form_value_no_id( $session, $suffix );

	if( $self->get_property( "hasid" ) )
	{
		my $id = $session->param( $self->{name}.$suffix."_id" );
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
	my( $self, $session, $suffix ) = @_;

	unless( $self->get_property( "multilang" ) )
	{
		# simple case; not multilang
		my $value = $self->form_value_basic( $session, $suffix );
		return undef unless( EPrints::Utils::is_set( $value ) );
		return $value;
	}

	my $value = {};
	my $boxcount = $session->param( $self->{name}.$suffix."_langspaces" );
	$boxcount = 1 if( $boxcount < 1 );
	for( my $i=1; $i<=$boxcount; ++$i )
	{
		my $subvalue = $self->form_value_basic( 
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

	return $value;
}

######################################################################
# 
# $foo = $field->form_value_basic( $session, $suffix )
#
# undocumented
#
######################################################################

sub form_value_basic
{
	my( $self, $session, $suffix ) = @_;
	
	my $value = $session->param( $self->{name}.$suffix );

	return undef if( $value eq "" );

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

		# uses function _single because value will NEVER be multiple
		my $orderkey = $self->ordervalue_single(
			$value, 
			$session, 
			$langid );
		$orderkeys{$v2} = $orderkey;
	}

	my @outvalues = sort {$orderkeys{$a} cmp $orderkeys{$b}} @values;

	return \@outvalues;
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	return $session->get_db()->get_values( $self, $dataset );
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
#		return $session->get_archive()->call( 
#			"id_label", 
#			$self, 
#			$session, 
#			$value );
#	}


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

	return $self->ordervalue_no_id( $value, $session, $langid );
}

sub ordervalue_no_id
{
	my( $self , $value , $session , $langid ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	if( $self->get_property( "multilang" ) )
	{
		$value = EPrints::Session::best_language( 
			$session->get_archive,
			$langid,
			%{$value} );
	}

	if( defined $self->{make_single_value_orderkey} )
	{
		return &{$self->{make_single_value_orderkey}}( 
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
	my( $self, $session, $prefix ) = @_;

	# complex text types

	my $val = $session->param( $prefix );
	return unless defined $val;

	my $search_type = $session->param( $prefix."_merge" );
		
	# Default search type if none supplied (to allow searches 
	# using simple HTTP GETs)
	$search_type = "ALL" unless defined( $search_type );		
		
	return unless( defined $val );

	return( $val, $search_type, "IN" );	
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

	# should use archive whitespaces
	return split /\s+/ , $value;
}

sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

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
	my( $self, $session, $value ) = @_;

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

