######################################################################
#
# EPrints Metadata Field class
#
#  Holds information about a metadata field
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

package EPrints::MetaField;

use EPrints::Log;
use EPrints::Database;

use strict;

# Months
my @monthkeys = ( 
	"00", "01", "02", "03", "04", "05", "06",
	"07", "08", "09", "10", "11", "12" );

my %TYPE_SQL =
(
 	int        => "\$(name) INT UNSIGNED \$(param)",
 	date       => "\$(name) DATE \$(param)",
 	boolean    => "\$(name) SET('TRUE','FALSE') \$(param)",
 	set        => "\$(name) VARCHAR(255) \$(param)",
 	text       => "\$(name) VARCHAR(255) \$(param)",
 	longtext   => "\$(name) TEXT \$(param)",
 	url        => "\$(name) VARCHAR(255) \$(param)",
 	email      => "\$(name) VARCHAR(255) \$(param)",
 	subject    => "\$(name) VARCHAR(255) \$(param)",
 	username   => "\$(name) VARCHAR(255) \$(param)",
 	pagerange  => "\$(name) VARCHAR(255) \$(param)",
 	year       => "\$(name) INT UNSIGNED \$(param)",
 	datatype   => "\$(name) VARCHAR(255) \$(param)",
 	name       => "\$(name)_given VARCHAR(255) \$(param), \$(name)_family VARCHAR(255) \$(param)"
 );
 
# Map of INDEXs required if a user wishes a field indexed.
my %TYPE_INDEX =
(
 	int        => "INDEX(\$(name))",
 	date       => "INDEX(\$(name))",
	boolean    => "INDEX(\$(name))",
 	set        => "INDEX(\$(name))",
 	text       => "INDEX(\$(name))",
 	longtext   => "INDEX(\$(name))",
 	url        => "INDEX(\$(name))",
 	email      => "INDEX(\$(name))",
 	subject    => "INDEX(\$(name))",
 	username   => "INDEX(\$(name))",
 	pagerange  => "INDEX(\$(name))",
 	year       => "INDEX(\$(name))",
 	datatype   => "INDEX(\$(name))",
 	name       => "INDEX(\$(name)_given), INDEX(\$(name)_family)"
);


######################################################################
#
##
# cjg comment?
######################################################################
# name   **required**
# type   **required**
# required # default = no
# editable # default = no
# multiple # default = no
# tableid # for help & name 
# 
# displaylines   # for longtext and set (int)   # default = 5
# digits  # for int  (int)   # default = 20
# options # for set (array)   **required if type**
# maxlength # for text (maybe url & email?)
# showall # for subjects

# note: display name, help and labels for options are not
# defined here as they are lang specific.

## WP1: BAD
sub new
{
	my( $class, $dataset, $properties ) = @_;
	
	my $self = {};
	bless $self, $class;

	#if( $_[1] =~ m/[01]:[01]:[01]/ ) { print STDERR "---\n".join("\n",caller())."\n"; die "WRONG KIND OF CALL TO NEW METAFIELD: $_[1]"; } #cjg to debug

	foreach( "name" , "type" )
	{
		if( !defined $properties->{$_} )
		{
	print STDERR EPrints::Log::render_struct( $properties );
			die "No $_ defined for field. (".join(",",caller()).")";	
		}
		$self->setProperty( $_, $properties->{$_} );
	}
	foreach( "required" , "editable" , "multiple" )
	{
		$self->setProperty( $_, $properties->{$_}, 0 );
	}

	$self->{dataset} = $dataset;

	if( $self->is_type( "longtext", "set", "subjects", "datatype" ) )
	{
		$self->setProperty( 
			"displaylines", 
			$properties->{displaylines}, 
			5 );
	}

	if( $self->is_type( "int" ) )
	{
		$self->setProperty( "digits", $properties->{digits} , 20 );
	}

	if( $self->is_type( "subject" ) )
	{
		$self->setProperty( "showall" , $properties->{showall} , 0 );
	}

	if( $self->is_type( "datatype" ) )
	{
		if( !defined $properties->{datasetid} )
		{
			#cjg NOT a good way to quit
			die "NO DATASETID for FIELD: $properties->{name}\n";
		}
		$self->setProperty( "datasetid" , $properties->{datasetid} );
	}

	if( $self->is_type( "text" ) )
	{
		$self->setProperty( "maxlength" , $properties->{maxlength} );
	}

	if( $self->is_type( "set" ) )
	{
		if( !defined $properties->{options} )
		{
			#cjg NOT a good way to quit
			die "NO OPTIONS for FIELD: $properties->{name}\n";
		}
		$self->setProperty( "options" , $properties->{options} );
	}

	return( $self );
}


######################################################################
#
# $value = get( $field )
#
#  Get information about the metadata field.
#
######################################################################

## WP1: BAD
sub get
{
	my( $self, $field ) = @_;
	
	return( $self->{$field} );
}


######################################################################
#
# $clone = clone()
#
#  Clone the field, so the clone can be edited without affecting the
#  original. (Exception: the tag and label fields - only the references
#  are copied, not the full array/hash.)
#
######################################################################

## WP1: BAD
sub clone
{
	my( $self ) = @_;

	return EPrints::MetaField->new( $self->{dataset} , $self );
}



######################################################################
#
# ( $year, $month, $day ) = get_date( $time )
#
#  Static method that returns the given time (in UNIX time, seconds 
#  since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).
#
######################################################################

## WP1: BAD
sub get_date
{
	my( $time ) = @_;

	my @date = localtime( $time );
	my $day = $date[3];
	my $month = $date[4]+1;
	my $year = $date[5]+1900;
	
	# Ensure number of digits
	while( length $day < 2 )
	{
		$day = "0".$day;
	}

	while( length $month < 2 )
	{
		$month = "0".$month;
	}

	return( $year, $month, $day );
}


######################################################################
#
# $datestamp = get_datestamp( $time )
#
#  Static method that returns the given time (in UNIX time, seconds 
#  since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).
#
######################################################################

## WP1: BAD
sub get_datestamp
{
	my( $time ) = @_;

	my( $year, $month, $day ) = EPrints::MetaField::get_date( $time );

	return( $year."-".$month."-".$day );
}


## WP1: BAD
sub tags_and_labels
{
	my( $self , $session ) = @_;
	my %labels = ();
	foreach( @{$self->{options}} )
	{
		$labels{$_} = "$_ multilang opts not done";
	}
	return ($self->{options}, \%labels);
}

## WP1: BAD
sub display_name
{
	my( $self, $session ) = @_;
	
	return $session->phrase( "fieldname_".$self->{dataset}->confid()."_".$self->{name} );
}

## WP1: BAD
sub display_help
{
	my( $self, $session ) = @_;
	
	return $session->phrase( "fieldhelp_".$self->{dataset}->confid."_".$self->{name} );
}

## WP1: BAD
sub getSQLType
{
        my( $self , $notnull ) = @_;

	my $type = $TYPE_SQL{$self->{type}};

	$type =~ s/\$\(name\)/$self->{name}/g;
	if( $notnull )
	{
		$type =~ s/\$\(param\)/NOT NULL/g;
	}
	else
	{
		$type =~ s/\$\(param\)//g;
	}

	return $type;
}

## WP1: BAD
sub getSQLIndex
{
        my( $self ) = @_;

	my $index = $TYPE_INDEX{$self->{type}};
	$index =~ s/\$\(name\)/$self->{name}/g;
print STDERR "gsind: $self->{type}...($index)\n";
	return $index;
}

## WP1: BAD
sub get_name
{
	my( $self ) = @_;
	return $self->{name};
}

## WP1: BAD
sub get_type
{
	my( $self ) = @_;
	return $self->{type};
}

sub setProperty
{
	my( $self , $property , $value , $default ) = @_;
	
	$self->{$property} = ( defined $value ? $value : $default );
}

## WP1: GOOD
sub isShowAll
{
	my( $self ) = @_;
	return $self->{showall};
}

## WP1: GOOD
sub isEditable
{
	my( $self ) = @_;
	return $self->{editable};
}

## WP1: GOOD
sub setEditable
{
	my( $self , $val ) = @_;
	$self->{editable} = $val;
}

## WP1: GOOD
sub isRequired
{
	my( $self ) = @_;
	return $self->{required};
}

## WP1: GOOD
sub setRequired
{
	my( $self , $val ) = @_;
	$self->{required} = $val;
}

## WP1: BAD
sub isMultiple
{
	my( $self ) = @_;
	return $self->{multiple};
}
## WP1: BAD
sub setMultiple
{
	my( $self , $val ) = @_;
	$self->{multiple} = $val;
}

## WP1: BAD
sub isIndexed
{
	my( $self ) = @_;
	return $self->{indexed};
}
## WP1: BAD
sub setIndexed
{
	my( $self , $val ) = @_;
	$self->{indexed} = $val;
}

## WP1: BAD
sub is_type
{
	my( $self , @typenames ) = @_;

	foreach( @typenames )
	{
		return 1 if( $self->{type} eq $_ );
	}
	return 0;
}

## WP1: BAD
sub isTextIndexable
{
	my( $self ) = @_;
	return $self->is_type( "text","longtext","url","email" );
}

######################################################################
#
# $html = getHTML( $field, $value )
#
#  format a field. Returns the formatted HTML as a string (doesn't
#  actually print it.)
#
######################################################################

## WP1: BAD
sub getHTML
{
	my( $self, $session, $value ) = @_;
#cjg not DOM


	if( !defined $value || $value eq "" )
	{
		return $session->makeText( "" );
	}

	my $html;

	if( $self->is_type( "text" , "int" , "pagerange" , "year" ) )
	{
		# Render text
		return $session->makeText( $value );
	}

	if( $self->is_type( "name" ) )
	{
		return $session->makeText(
			EPrints::Name::format_names( $value ) );
	}

	if( $self->is_type( "datatype" ) )
	{
		$html = $self->{labels}->{$value} if( defined $value );
		$html = $self->{session}->makeText("UNSPECIFIED") unless( defined $value );
	}
	elsif( $self->is_type( "boolean" ) )
	{
		$html = $self->{session}->makeText("UNSPECIFIED") unless( defined $value );
		$html = ( $value eq "TRUE" ? "Yes" : "No" ) if( defined $value );
	}
	elsif( $self->is_type( "longtext" ) )
	{
		$html = ( defined $value ? $value : "" );
		$html =~ s/\r?\n\r?\n/<BR><BR>\n/s;
	}
	elsif( $self->is_type( "date" ) )
	{
		if( defined $value )
		{
			my @elements = split /\-/, $value;

			if( $elements[0]==0 )
			{
				$html = "UNSPECIFIED";
			}
			elsif( $#elements != 2 || $elements[1] < 1 || $elements[1] > 12 )
			{
				$html = "INVALID";
			}
			else
			{
#				$html = $elements[2]." ".$monthnames{$elements[1]}." ".$elements[0];
			}
		}
		else
		{
			$html = "UNSPECIFIED";
		}
	}
	elsif( $self->is_type( "url" ) )
	{
		$html = "<A HREF=\"$value\">$value</A>" if( defined $value );
		$html = "" unless( defined $value );
	}
	elsif( $self->is_type( "email" ) )
	{
		$html = "<A HREF=\"mailto:$value\">$value</A>"if( defined $value );
		$html = "" unless( defined $value );
	}
	elsif( $self->is_type( "subject" ) )
	{
		$html = "";

		my $subject_list = EPrints::SubjectList->new( $value );
		my @subjects = $subject_list->get_tags();
		
		my $sub;
		my $first = 0;

		foreach $sub (@subjects)
		{
			if( $first==0 )
			{
				$first = 1;
			}
			else
			{
				$html .= "<BR>";
			}
			
			$html .= EPrints::Subject::subject_label( $self->{session}, $sub );
		}
	}
	elsif( $self->is_type( "set" ) )
	{
		$html = "";
		my @setvalues;
		@setvalues = split /:/, $value if( defined $value );
		my $first = 0;

		foreach (@setvalues)
		{
			if( $_ ne "" )
			{
				$html .=  ", " unless( $first );
				$first=1 if( $first );
				$html .= $self->{labels}->{$_};
			}
		}
	}
	elsif( $self->is_type( "username" ) )
	{
		$html = "";
		my @usernames;
		@usernames = split /:/, $value if( defined $value );
		my $first = 0;

		foreach (@usernames)
		{
			if( $_ ne "" )
			{
				$html .=  ", " unless( $first );
				$first=1 if( $first );
				$html .= $_;
				# This could be much prettier
			}
		}
	}
	
	$session->getSite()->log( "Unknown field type: ".$self->{type} );
	return undef;

}


## WP1: BAD
sub render_input_field
{
	my( $self, $session, $value ) = @_;

	my( $html, $frag );

	$html = $session->makeDocFragment();

	# subject fields can be rendered here and now
	# without looping and calling the aux function.

	if( $self->is_type( "subject", "datatype", "set" ) )
	{
		my( $tags, $labels, $id );
 		$id = $self->{name};
		if( $session->internal_button_pressed() )
		{
			my @values = $session->param( $id );
			$value = \@values;
		}
	
		if( $self->is_type( "set" ) )
		{
			$tags = $self->{tags};
			$labels = $self->{labels};
		}
		elsif( $self->is_type( "datatype" ) )
		{
			my $ds = $session->getSite()->getDataSet( 
					$self->{datasetid} );	
			$tags = $ds->getTypes();
			$labels = $ds->getTypeNames( $session );
		}
		elsif( $self->is_type( "subject" ) )
		{
			if( $self->{showall} )
			{
				( $tags, $labels ) = 
					EPrints::Subject::all_subject_labels(
 					$session ); 
			}
			else
			{			
				( $tags, $labels ) = 
					EPrints::Subject::get_postable( 
						$session, 
						$session->current_user );
	print STDERR "##(".join(",",@{$tags}).")\n";
	print STDERR "##(".join(",",%{$labels}).")\n";
			}
		}

		if( !defined $value )
		{
			$value = [];
		}
		elsif( !$self->isMultiple() )
		{
			$value = [ $value ];
		}

		$html->appendChild( $session->make_option_list(
			name => $id,
			values => $tags,
			default => $value,
			height => $self->{displaylines},
			multiple => ( $self->{multiple} ? 
					"multiple" : undef ),
			labels => $labels ) );

		return $html;
	}

	# The other types require a loop if they are multiple.

	$frag = $html;

	if( $self->is_type( "name" ) )
	{
		my( $table, $tr, $th, $div );
		$table = $session->make_element( 
					"table", 
					cellpadding=>0,
					cellspacing=>2,
					border=>0 );
		$tr = $session->make_element( "tr" );
		$th = $session->make_element( "th" );
		$div = $session->make_element( "div", class => "namefieldheading" );
		$div->appendChild( $session->html_phrase( "family_name" ) );
		$th->appendChild( $div );
		$tr->appendChild( $th );
		$th = $session->make_element( "th" );
		$div = $session->make_element( "div", class => "namefieldheading" );
		$div->appendChild( $session->html_phrase( "first_names" ) );
		$th->appendChild( $div );
		$tr->appendChild( $th );
		$table->appendChild( $tr );
	
		$html->appendChild( $table );
		$frag = $table;
	}

	if( $self->isMultiple() )
	{
		my $boxcount = 3;
		my $spacesid = $self->{name}."_spaces";

		if( $session->internal_button_pressed() )
		{
			$boxcount = $session->param( $spacesid );
			if( $session->param( "_internal" ) eq  
				$session->phrase( "more_spaces" ) )
			{
				$boxcount += 2;
			}
		}
	
		my $i;
		for( $i=1 ; $i<=$boxcount ; ++$i )
		{
			my $more = undef;
			if( $i == $boxcount )
			{
				$more = $session->makeDocFragment();
				$more->appendChild( $session->make_element(
					"input",
					type => "hidden",
					name => $spacesid,
					value => $boxcount ) );
				$more->appendChild( $session->make_element(
					"input",
					type => "submit",
					name => "_internal",
					value => $session->phrase( 
							"more_spaces" ) ) );
			}
			$frag->appendChild( 
				$self->_render_input_field_aux( 
					$session, 
					$value->[$i], 
					$i,
					$more ) );
		}
	}
	else
	{
		$frag->appendChild( 
			$self->_render_input_field_aux( 
				$session, 
				$value ) );
	}

	return $html;
}


sub _render_input_field_aux
{
	my( $self, $session, $value, $n, $morebutton ) = @_;
print STDERR "val($value)\n";

	my $id_suffix = "";
	$id_suffix = "_$n" if( defined $n );

	# These DO NOT belong here. cjg.
	my( $FORM_WIDTH, $INPUT_MAX ) = ( 40, 255 );

	my $html = $session->makeDocFragment();
	if( $self->is_type( "text", "username", "url", "int", "email" ) )
	{
		my( $maxlength, $size, $div, $id );
 		$id = $self->{name}.$id_suffix;
		if( $session->internal_button_pressed() )
		{
			$value = $session->param( $id );
		}

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
			$maxlength = ( defined $self->{maxlength} ? 
					$self->{maxlength} : 
					$INPUT_MAX );
		}

		$size = ( $maxlength > $FORM_WIDTH ?
					$FORM_WIDTH : 
					$maxlength );

		$div = $session->make_element( "div" );	
		$div->appendChild( $session->make_element(
			"input",
			name => $id,
			value => $value,
			size => $size,
			maxlength => $maxlength ) );

		if( defined $morebutton )
		{
			$div->appendChild( $morebutton );
		}
		$html->appendChild( $div );
	}
	elsif( $self->is_type( "longtext" ) )
	{
		my( $div , $textarea , $id );
 		$id = $self->{name}.$id_suffix;
		if( $session->internal_button_pressed() )
		{
			$value = $session->param( $id );
		}
		$div = $session->make_element( "div" );	
		$textarea = $session->make_element(
			"textarea",
			name => $id,
			rows => $self->{displaylines},
			cols => $FORM_WIDTH,
			wrap => "virtual" );
		$textarea->appendChild( $session->makeText( $value ) );
		$div->appendChild( $textarea );
		if( defined $morebutton )
		{
			$div->appendChild( $morebutton );
		}
		
		$html->appendChild( $div );
	}
	elsif( $self->is_type( "boolean" ) )
	{
		my( $div , $id);
 		$id = $self->{name}.$id_suffix;
		if( $session->internal_button_pressed() )
		{
			$value = $session->param( $id );
		}

		$div = $session->make_element( "div" );	
		$div->appendChild( $session->make_element(
			"input",
			type => "checkbox",
			checked=>( defined $value && $value eq 
					"TRUE" ? "checked" : undef ),
			name => $id,
			value => "TRUE" ) );
		# No more button for boolean. That would be silly.
		$html->appendChild( $div );
	}
	elsif( $self->is_type( "name" ) )
	{
		my( $tr, $td , $givenid, $familyid );
 		$givenid = $self->{name}.$id_suffix."_given";
 		$familyid = $self->{name}.$id_suffix."_family";
		if( $session->internal_button_pressed() )
		{
			$value->{family} = $session->param( $familyid );
			$value->{given} = $session->param( $givenid );
		}
		$tr = $session->make_element( "tr" );
		$td = $session->make_element( "td" );
		$td->appendChild( $session->make_element(
			"input",
			name => $familyid,
			value => $value->{family},
			size => int( $FORM_WIDTH / 2 ),
			maxlength => $INPUT_MAX ) );
		$tr->appendChild( $td );
		$td = $session->make_element( "td" );
		$td->appendChild( $session->make_element(
			"input",
			name => $givenid,
			value => $value->{given},
			size => int( $FORM_WIDTH / 2 ),
			maxlength => $INPUT_MAX ) );
		$tr->appendChild( $td );
		if( defined $morebutton )
		{
			$td = $session->make_element( "td" );
			$td->appendChild( $morebutton );
			$tr->appendChild( $td );
		}
		$html->appendChild( $tr );
	}
	elsif( $self->is_type( "pagerange" ) )
	{
		my( $div , @pages , $fromid, $toid );
		@pages = split /-/, $value if( defined $value );
 		$fromid = $self->{name}.$id_suffix."_from";
 		$toid = $self->{name}.$id_suffix."_to";
		if( $session->internal_button_pressed() )
		{
			$pages[0] = $session->param( $fromid );
			$pages[1] = $session->param( $toid );
		}
		
		
		$div = $session->make_element( "div" );	

		$div->appendChild( $session->make_element(
			"input",
			name => $fromid,
			value => $pages[0],
			size => 6,
			maxlength => 10 ) );

		$div->appendChild( $session->makeText(" ") );
		$div->appendChild( $session->html_phrase( "to" ) );
		$div->appendChild( $session->makeText(" ") );

		$div->appendChild( $session->make_element(
			"input",
			name => $toid,
			value => $pages[1],
			size => 6,
			maxlength => 10 ) );
		if( defined $morebutton )
		{
			$div->appendChild( $morebutton );
		}
		$html->appendChild( $div );

	}
	elsif( $self->is_type( "date" ) )
	{
		my( $div, $yearid, $monthid, $dayid );
		$div = $session->make_element( "div" );	
		my( $year, $month, $day ) = ("", "", "");
		if( defined $value && $value ne "" )
		{
			($year, $month, $day) = split /-/, $value;
			if( $month == 0 )
			{
				($year, $month, $day) = ("", "00", "");
			}
		}
 		$dayid = $self->{name}.$id_suffix."_day";
 		$monthid = $self->{name}.$id_suffix."_month";
 		$yearid = $self->{name}.$id_suffix."_year";
		if( $session->internal_button_pressed() )
		{
			$month = $session->param( $monthid );
			$day = $session->param( $dayid );
			$year = $session->param( $yearid );
		}

		$div->appendChild( $session->html_phrase( "year" ) );
		$div->appendChild( $session->makeText(" ") );

		$div->appendChild( $session->make_element(
			"input",
			name => $yearid,
			value => $year,
			size => 4,
			maxlength => 4 ) );

		$div->appendChild( $session->makeText(" ") );
		$div->appendChild( $session->html_phrase( "month" ) );
		$div->appendChild( $session->makeText(" ") );

		$div->appendChild( $session->make_option_list(
			name => $monthid,
			values => \@monthkeys,
			default => $month,
			labels => $self->_month_names( $session ) ) );
		$div->appendChild( $session->makeText(" ") );
		$div->appendChild( $session->html_phrase( "day" ) );
		$div->appendChild( $session->makeText(" ") );

		$div->appendChild( $session->make_element(
			"input",
			name => $dayid,
			value => $day,
			size => 2,
			maxlength => 2 ) );
		if( defined $morebutton )
		{
			$div->appendChild( $morebutton );
		}
		$html->appendChild( $div );
	}
	else
	{
		$html->appendChild( $session->makeText( "???" ) );
		$session->getSite()->log( "Don't know how to render input".
					  "field of type: ".$self->get_type() );
	}
	return $html;
}

#WP1: BAD
sub _month_names
{
	my( $self , $session ) = @_;
	
	my $months = {};

	my $month;
	foreach $month ( @monthkeys )
	{
		$months->{$month} = $session->phrase( "month_".$month );
	}

	return $months;
}

######################################################################
#
# $value = form_value( $field )
#
#  A complement to param(). This reads in values from the form,
#  and puts them back into a value appropriate for the field type.
#
######################################################################

## WP1: BAD
sub form_value
{
	my( $self, $session ) = @_;
	
	if( $self->is_type( "set", "subject", "datatype" ) ) 
	{
		my @values = $session->param( $self->{name} );
		
		if( scalar( @values ) == 0 )
		{
			return undef;
		}
		if( $self->isMultiple() )
		{
			return \@values;
		}
		else
		{
			$values[0];
		}
	}

	if( $self->isMultiple() )
	{
		my @values = ();
		my $boxcount = $session->param( $self->{name}."_spaces" );
		$boxcount = 1 if( $boxcount < 1 );
		my $i;
		for( $i=1; $i<=$boxcount; ++$i )
		{
			my $value = $self->_form_value_aux( $session, $i );
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

	return $self->_form_value_aux( $session );
}

sub _form_value_aux
{
	my( $self, $session, $n ) = @_;

	my $id_suffix = "";
	$id_suffix = "_$n" if( defined $n );

	if( $self->is_type( "text", "username", "url", "int", "email" ) )
	{
		my $value = $session->param( $self->{name} );
		return undef if( $value eq "" );
		return $value;
	}
	elsif( $self->is_type( "pagerange" ) )
	{
		my $from = $session->param( $self->{name}.$id_suffix."_from" );
		my $to = $session->param( $self->{name}.$id_suffix."_to" );

		if( !defined $to || $to eq "" )
		{
			return( $from );
		}
		
		return( $from . "-" . $to );
	}
	elsif( $self->is_type( "boolean" ) )
	{
		my $form_val = $session->param( $self->{name}.$id_suffix );
		return ( defined $form_val ? "TRUE" : "FALSE" );
	}
	elsif( $self->is_type( "date" ) )
	{
		my $day = $session->param( $self->{name}.$id_suffix."_day" );
		my $month = $session->param( 
					$self->{name}.$id_suffix."_month" );
		my $year = $session->param( $self->{name}.$id_suffix."_year" );

		if( defined $day && $month ne "00" && defined $year )
		{
			return $year."-".$month."-".$day;
		}
		return undef;
	}
	elsif( $self->is_type( "name" ) )
	{
		my( $family, $given );
		$family = $session->param( $self->{name}.$id_suffix."_family" );
		$given = $session->param( $self->{name}.$id_suffix."_given" );

		if( defined $family && $family ne "" )
		{
			return { family => $family, given => $given };
		}
		return undef;
	}
	else
	{
		$session->getSite()->log( 
			"Error: can't do _form_value_aux on type ".
			"'".$self->{type}."'" );
		return undef;
	}	
}


