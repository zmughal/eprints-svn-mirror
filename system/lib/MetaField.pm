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

use EPrints::Utils;
use EPrints::Session;
use EPrints::Subject;
use EPrints::Database;

use strict;
#CJG Option for Boolean to be a menu or radio buttons?
# Months
my @monthkeys = ( 
	"00", "01", "02", "03", "04", "05", "06",
	"07", "08", "09", "10", "11", "12" );

# These '255'... Maybe make them bigger due to UTF-8
# UTF-8 chars max 3 times normal (for unicode)

# ID and LANGID are for internal use only!

my %TYPE_SQL =
(
 	int        => "\$(name) INT UNSIGNED \$(param)",
 	date       => "\$(name) DATE \$(param)",
 	boolean    => "\$(name) SET('TRUE','FALSE') \$(param)",
 	set        => "\$(name) VARCHAR(255) \$(param)",
 	text       => "\$(name) VARCHAR(255) \$(param)",
 	secret     => "\$(name) VARCHAR(255) \$(param)",
 	longtext   => "\$(name) TEXT \$(param)",
 	url        => "\$(name) VARCHAR(255) \$(param)",
 	email      => "\$(name) VARCHAR(255) \$(param)",
 	subject    => "\$(name) VARCHAR(255) \$(param)",
 	pagerange  => "\$(name) VARCHAR(255) \$(param)",
 	year       => "\$(name) INT UNSIGNED \$(param)",
 	datatype   => "\$(name) VARCHAR(255) \$(param)",
 	langid	   => "\$(name) CHAR(16) \$(param)",
	id         => "\$(name) VARCHAR(255) \$(param)",
 	name       => "\$(name)_honourific VARCHAR(255) \$(param), \$(name)_given VARCHAR(255) \$(param), \$(name)_family VARCHAR(255) \$(param), \$(name)_lineage VARCHAR(255) \$(param)"
 );
 
# Map of INDEXs required if a user wishes a field indexed.
my %TYPE_INDEX =
(
 	int        => "INDEX(\$(name))",
 	date       => "INDEX(\$(name))",
	boolean    => "INDEX(\$(name))",
 	set        => "INDEX(\$(name))",
 	text       => "INDEX(\$(name))",
 	longtext   => undef,
 	secret     => undef,
 	url        => "INDEX(\$(name))",
 	email      => "INDEX(\$(name))",
 	subject    => "INDEX(\$(name))",
 	pagerange  => "INDEX(\$(name))",
 	year       => "INDEX(\$(name))",
 	datatype   => "INDEX(\$(name))",
 	langid	   => "INDEX(\$(name))",
 	id	   => "INDEX(\$(name))",
 	name       => "INDEX(\$(name)_honourific), INDEX(\$(name)_given), INDEX(\$(name)_family), INDEX(\$(name)_lineage)"
);

# list of legal properties used to check
# get & set property.

#cjg MAYBE this could be the defaults? not just =>1

my $PROPERTIES = {
	datasetid => "NO_DEFAULT",
	digits => 20,
	displaylines => 12,
	maxlength => 255,
	hasid => 0,
	multilang => 0,
	multiple => 0,
	name => "NO_DEFAULT",
	options => "NO_DEFAULT",
	required => 0,
	requiredlangs => [],
	showall => 0, 
	idpart => 0,
	mainpart => 0,
	top => "subjects", #cjg is this right?
	type => "NO_DEFAULT"
};

######################################################################
#
##
# cjg comment?
######################################################################
# name   **required**
# type   **required**
# required # default = no
# multiple # default = no
# 
# displaylines   # for longtext and set (int)   # default = 5
# digits  # for int  (int)   # default = 20
# options # for set (array)   **required if type**
# maxlength # for text (maybe url & email?)
# showall # for subjects

# hasid # for all - has an ID value(s)
# idpart, mainpart # internal use only by the "ID" fields sub-fields.

# note: display name, help and labels for options are not
# defined here as they are lang specific.

## WP1: BAD
sub new
{
	my( $class, %properties ) = @_;
	
	my $self = {};
	bless $self, $class;

	#if( $_[1] =~ m/[01]:[01]:[01]/ ) { print STDERR "---\n".join("\n",caller())."\n"; die "WRONG KIND OF CALL TO NEW METAFIELD: $_[1]"; } #cjg to debug

	$self->set_property( "name", $properties{name} );
	$self->set_property( "type", $properties{type} );
	$self->set_property( "required", $properties{required} );
	$self->set_property( "multiple", $properties{multiple} );

	$self->{confid} = $properties{confid};

	if( defined $properties{dataset} ) { 
		$self->{confid} = $properties{dataset}->confid(); 
	}

	if( $self->is_type( "longtext", "set", "subject", "datatype" ) )
	{
		$self->set_property( "displaylines", $properties{displaylines} );
	}

	if( $self->is_type( "text","longtext","name" ) )
	{
		$self->set_property( "multilang", $properties{multilang} );
	}
	if( $self->is_type( "int" ) )
	{
		$self->set_property( "digits", $properties{digits} );
	}

	if( $self->is_type( "subject" ) )
	{
		$self->set_property( "showall" , $properties{showall} );
		$self->set_property( "top" , $properties{top} );
	}

	if( $self->is_type( "datatype" ) )
	{
		$self->set_property( "datasetid" , $properties{datasetid} );
	}

	if( $self->is_type( "text" , "secret" ) )
	{
		$self->set_property( "maxlength" , $properties{maxlength} );
	}

	if( $self->is_type( "set" ) )
	{
		$self->set_property( "options" , $properties{options} );
	}

	if( $self->is_type( "text", "name" ) )
	{
		$self->set_property( "hasid" , $properties{hasid} );
		$self->set_property( "mainpart" , $properties{mainpart} );
	}
	if( $self->is_type( "id" ) )
	{
		$self->set_property( "idpart" , $properties{idpart} );
	}

	if( $self->get_property( "multilang" ) )
	{
		$self->set_property( "requiredlangs", $properties{requiredlangs} );
	}

	return( $self );
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

	return EPrints::MetaField->new( %{$self} );
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

	my $dname = $session->phrase( $self->{confid}."_fieldname_".$self->{name} );

	$dname.= "_id" if( $self->get_property( "idpart" ) );

	return $dname;
}

## WP1: BAD
sub display_help
{
	my( $self, $session ) = @_;

	my $dhelp = $session->phrase( $self->{confid}."_fieldhelp_".$self->{name} );

	$dhelp.= "_id" if( $self->get_property( "idpart" ) );

	return $dhelp;
}

## WP1: BAD
sub get_sql_type
{
        my( $self , $notnull ) = @_;

	my $type = $TYPE_SQL{$self->{type}};
	my $sqlname = $self->get_sql_name();
	$type =~ s/\$\(name\)/$sqlname/g;
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
sub get_sql_index
{
        my( $self ) = @_;

	my $index = $TYPE_INDEX{$self->{type}};
	
	if( defined $index )
	{
		my $sqlname = $self->get_sql_name();
		$index =~ s/\$\(name\)/$sqlname/g;
	}

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

sub set_property
{
	my( $self , $property , $value ) = @_;

	if( !defined $PROPERTIES->{$property})
	{
		die "BAD METAFIELD set_property NAME: \"$property\"";
	}
	if( !defined $value )
	{
		if( $PROPERTIES->{$property} eq "NO_DEFAULT" )
		{
			EPrints::Config::abort( $property." on a metafield can't be undef" );
		}
		$self->{$property} = $PROPERTIES->{$property};
	}
	else
	{
		$self->{$property} = $value;
	}
}

sub get_property
{
	my( $self, $property ) = @_;

	if( !defined $PROPERTIES->{$property})
	{
		die "BAD METAFIELD get_property NAME: \"$property\"";
	}

	return( $self->{$property} ); 
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
sub is_text_indexable
{
	my( $self ) = @_;
	return $self->is_type( "text","longtext","url","email" );
}


sub render_value
{
	my( $self, $session, $value, $alllangs, $ignoreid ) = @_;

	if( !$self->get_property( "multiple" ) )
	{
		return $self->_render_value1( $session, $value, $alllangs, $ignoreid );
	}

	if(! EPrints::Utils::is_set( $value ) )
	{
		return $session->make_text( "[undef-$self->{name}]" );#cjg!??!? null or text?		
	}

	my @rendered_values = ();
	my $sep; #cjg NOT LANG'D
	if( $self->is_type( "name" ) )
	{
		$sep = " and ";
	}
	else
	{
		$sep = ", ";
	}
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
			$html->appendChild( $session->make_text( $sep ) );
		}
		$html->appendChild( $self->_render_value1( $session, $_, $alllangs, $ignoreid ) );
	}
	return $html;

}


sub _render_value1
{
	my( $self, $session, $value, $alllangs ) = @_;

	my $rendered = $self->_render_value2( $session, $value, $alllangs );

	if( $self->get_property( "hasid" ) )
	{
		# Ask the usercode to fiddle with this bit of HTML
		# based on the value of it's ID. 
		# It will either just pass it through, redo it from scratch
		# or wrap it in a link.
		
		return $session->get_archive()->call( "render_value_with_id",  
			$self, $session, $value, $alllangs, $rendered );
	}
	else
	{
		return $rendered;
	}

}

sub _render_value2
{
	my( $self, $session, $value, $alllangs ) = @_;

	# We don't care about the ID
	if( $self->get_property( "hasid" ) )
	{
		$value = $value->{main};
	}

	if( !$self->get_property( "multilang" ) )
	{
		return $self->_render_value3( $session, $value );
	}

	if( !$alllangs )
	{
		my $v = EPrints::Session::best_language( $session->get_archive(), $session->get_langid(), %$value );
		return $self->_render_value3( $session, $v );
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

sub _render_value3
{
	my( $self, $session, $value ) = @_;

	if( !defined $value )
	{
		return $session->html_phrase( "lib/metafield:unspecified" );
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
		my $a = $session->make_element( "a", href=>$value );
		$a->appendChild( $session->make_text( $value ) );
		return $a;
	}

	if( $self->is_type( "email" ) )
	{
		my $a = $session->make_element( "a", href=>"mailto:".$value );
		$a->appendChild( $session->make_text( $value ) );
		return $a;
	}

	if( $self->is_type( "name" ) )
	{
		return $session->make_text(
			EPrints::Utils::format_name( $value ) );
	}

	if( $self->is_type( "longtext" ) )
	{
		my @paras = split( /\r?\n\r?\n/ , $value );
		my $frag = $session->make_doc_fragment();
		my $first = 1;
		foreach( @paras )
		{
			unless( $first )
			{
				$frag->appendChild( $session->make_element( "br" ) );
			}
			$frag->appendChild( $session->make_text( $_ ) );
			$first = 0;
		}
		return $frag;
	}

	if( $self->is_type( "datatype" ) )
	{
		my $ds = $session->get_archive()->get_dataset( $self->get_property( "datasetid" ) );
		return $ds->render_type_name( $session, $value ); 
	}

	if( $self->is_type( "subject" ) )
	{
		my $subject = EPrints::Subject->new( $session, $value );
		return $subject->render();
	}

return $session->make_text( "<<".$value.">>" );#cjg!!!!!
my $html;

	if( $self->is_type( "boolean" ) )
	{
		$html = $self->{session}->make_text("UNSPECIFIED") unless( defined $value );
		$html = ( $value eq "TRUE" ? "Yes" : "No" ) if( defined $value );
	}
	if( $self->is_type( "date" ) )
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
	elsif( $self->is_type( "subject" ) )
	{
		$html = "";

		my $sub;
		my $first = 0;

		foreach $sub (@{$value})
		{
			if( $first==0 )
			{
				$first = 1;
			}
			else
			{
				$html .= "<BR>";
			}
			
			$html .= EPrints::Subject::subject_label( $self->{session}, $sub ); #cjg!!
		}
	}
	elsif( $self->is_type( "set" ) )
	{
		$html = "";
		my @setvalues;
		@setvalues = split /:/, $value if( defined $value );
		my $first = 0;
		my $value;
		foreach $value (@setvalues)
		{
			if( $value ne "" )
			{
				$html .=  ", " unless( $first );
				$first=1 if( $first );
	#bad {labels} dep
				$html .= $self->{labels}->{$value};
			}
		}
	}
	
	$session->get_archive()->log( "Unknown field type: ".$self->{type} );
	return undef;

}


## WP1: BAD
sub render_input_field
{
	my( $self, $session, $value ) = @_;

#use Data::Dumper;
#print STDERR "FIELD: ".$self->get_name()."\n".Dumper($value);

	my( $html, $frag );

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

		$settings{height} = $self->{displaylines};
#print STDERR "HEIGHT: $settings{height}\n";
		if( $settings{height} == 0 )
		{
			$settings{height} = undef;
		}

		if( $self->is_type( "subject" ) )
		{
			my $topsubj = EPrints::Subject->new(
				$session,
				$self->get_property( "top" ) );
			my ( $pairs ) = $topsubj->get_subjects( 
				!($self->{showall}), 
				0 );
			$settings{pairs} = $pairs;
			if( $settings{height} eq "ALL")
			{
				$settings{height} = scalar @{$pairs};
			}
		} else {
			my($tags,$labels);
			if( $self->is_type( "set" ) )
			{
				$tags = $self->{options};
				$labels = {};
				foreach( @{$tags} ) { $labels->{$_} = $_; } # hack!!!cjg
			}
			else # is "datatype"
			{
				my $ds = $session->get_archive()->get_dataset( 
						$self->{datasetid} );	
				$tags = $ds->get_types();
				$labels = $ds->get_type_names( $session );
			}
			$settings{values} = $tags;
			$settings{labels} = $labels;
			if( $settings{height} eq "ALL")
			{
				$settings{height} = scalar @{$tags};
			}

		}
		$html->appendChild( $session->render_option_list( %settings ) );

		return $html;
	}

	# The other types require a loop if they are multiple.

	if( $self->get_property( "multiple" ) )
	{
		my $boxcount = 3;
		my $spacesid = $self->{name}."_spaces";

		if( $session->internal_button_pressed() )
		{
			$boxcount = $session->param( $spacesid );
			if( $session->internal_button_pressed( $self->{name}."_morespaces" ) )
			{
				$boxcount += 2;
			}
		}
	
		my $i;
		for( $i=1 ; $i<=$boxcount ; ++$i )
		{
			my $div;
			$div = $session->make_element( "div" );
			$div->appendChild( $session->make_text( $i.". " ) );
			$html->appendChild( $div );
			$div = $session->make_element( "div", style=>"margin-left: 20px" ); #cjg NOT CSS
			$div->appendChild( 
				$self->_render_input_field_aux( 
					$session, 
					$value->[$i-1], 
					$i ) );
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
				$session->phrase( "lib/metafield:more_spaces" ) ) );
	}
	else
	{
		$html->appendChild( 
			$self->_render_input_field_aux( 
				$session, 
				$value ) );
	}

	return $html;
}

sub _render_input_field_aux
{
	my( $self, $session, $value, $n ) = @_;

	my $suffix = (defined $n ? "_$n" : "" );	

	my $idvalue;
	if( $self->get_property( "hasid" ) )
	{
		$idvalue = $value->{id};
		$value = $value->{main};
	}
	my( $boxcount, $spacesid, $buttonid, $rows );
#print STDERR "AUX: ".$self->{name}."\n";
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
				$boxcount += 2;
			}
		}
		
		my( @force ) = @{$self->get_property( "requiredlangs" )};
		
		my %langstodo = ();
		foreach( keys %{$value} ) { $langstodo{$_}=1; }
		my %langlabels = ();
		foreach( EPrints::Config::get_languages() ) { $langlabels{$_}=EPrints::Config::lang_title($_); }
		foreach( @force ) { delete $langlabels{$_}; }
		my @langopts = ("", keys %langlabels );
		$langlabels{""} = "** Select Language **";
	
		my $i=1;
		my $langid;
		while( scalar(@force)>0 || $i<=$boxcount || scalar(keys %langstodo)>0)
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
			
#print STDERR "****************".$suffix."_".$i."\n";
#use Data::Dumper;
#print STDERR Dumper( $langid, $value, $value->{$langid} );
#print STDERR "************\n";

			my $langparamid = $self->{name}.$suffix."_".$i."_lang";
			my $langbit;
			if( $forced )
			{
				$langbit = $session->make_element( "span", class=>"requiredlang" );
				$langbit->appendChild( $session->make_element(
					"input",
					"accept-charset" => "utf-8",
					type => "hidden",
					name => $langparamid,
					value => $langid ) );
				$langbit->appendChild( $session->make_text( EPrints::Config::lang_title( $langid ) ) );
			}
			else
			{
				$langbit = $session->render_option_list(
					name => $langparamid,
					values => \@langopts,
					default => $langid,
					labels => \%langlabels );
			}
			$langbit->appendChild( $session->make_text( " (LANGID:$langid)") );
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
				my $div = $session->make_element( "div" );# cjg style?
				$div->appendChild( $aux2 );
				#space? cjg
				$div->appendChild( $langbit );
				$rows->appendChild( $div );
			}
			
#print STDERR "****************".$suffix."_".$i."\n";
#use Data::Dumper;
#print STDERR Dumper( $langid, $value, $value->{$langid} );
#print STDERR "************\n\n";
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
print SDTERR "ZOOKl\n";
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

		$th = $session->make_element( "th" );
		$th->appendChild( $session->html_phrase( "lib/metafield:honourific" ) );
		$tr->appendChild( $th );

		$th = $session->make_element( "th" );
		$th->appendChild( $session->html_phrase( "lib/metafield:given_names" ) );
		$tr->appendChild( $th );

		$th = $session->make_element( "th" );
		$th->appendChild( $session->html_phrase( "lib/metafield:family_names" ) );
		$tr->appendChild( $th );

		$th = $session->make_element( "th" );
		$th->appendChild( $session->html_phrase( "lib/metafield:lineage" ) );
		$tr->appendChild( $th );

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
			$buttonid => $session->phrase( "lib/metafield:more_langs" ) ) );
	}
	if( $self->get_property( "hasid" ) )
	{
		$block->appendChild( $session->make_text( "[[HAS ID]]" ) );
		my $div = $session->make_element( "div", class=>"formfieldinputid" );
		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $self->{name}.$suffix."_id",
			value => $idvalue,
			size => 40 ) );
		$block->appendChild( $div );
	}
	
	return $block;
}

sub _render_input_field_aux2
{
	my( $self, $session, $value, $suffix ) = @_;
#print STDERR "$suffix ... val($value)\n";


	# These DO NOT belong here. cjg.
	my( $FORM_WIDTH, $INPUT_MAX ) = ( 40, 255 );
# not return DIVs? cjg (currently some types do some don't)
	my $frag = $session->make_doc_fragment();
	if( $self->is_type( "text", "url", "int", "email", "year","secret" ) )
	{
		my( $maxlength, $size, $div, $id );
 		$id = $self->{name}.$suffix;
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

		$frag->appendChild( $session->make_element(
			"input",
			type => ($self->is_type( "secret" )?"password":undef),
			"accept-charset" => "utf-8",
			name => $id,
			value => $value,
			size => $size,
			maxlength => $maxlength ) );
	}
	elsif( $self->is_type( "longtext" ) )
	{
		my( $div , $textarea , $id );
 		$id = $self->{name}.$suffix;
		$div = $session->make_element( "div" );	
		$textarea = $session->make_element(
			"textarea",
			name => $id,
			rows => $self->{displaylines},
			cols => $FORM_WIDTH,
			wrap => "virtual" );
		$textarea->appendChild( $session->make_text( $value ) );
		$div->appendChild( $textarea );
		
		$frag->appendChild( $div );
	}
	elsif( $self->is_type( "boolean" ) )
	{
		#cjg OTHER METHOD THAN CHECKBOX? TRUE/FALSE MENU?
		my( $div , $id);
 		$id = $self->{name}.$suffix;

		$div = $session->make_element( "div" );	
		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "checkbox",
			checked=>( defined $value && $value eq 
					"TRUE" ? "checked" : undef ),
			name => $id,
			value => "TRUE" ) );
		# No more button for boolean. That would be silly.
		$frag->appendChild( $div );
	}
	elsif( $self->is_type( "name" ) )
	{
		my( $td );
		foreach( "honourific", "given", "family", "lineage" )
		{
			my $size;
			if( $_ eq "given" || $_ eq "family" )
			{
				$size = int( $FORM_WIDTH / 2 );
			}
			else
			{
				$size = int( $FORM_WIDTH / 4 );
			}
			$td = $session->make_element( "td" );
			$frag->appendChild( $td );
			$td->appendChild( $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				name => $self->{name}.$suffix."_".$_,
				value => $value->{$_},
				size => $size,
				maxlength => $INPUT_MAX ) );
		}

	}
	elsif( $self->is_type( "pagerange" ) )
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
		$div->appendChild( $session->html_phrase( "lib/metafield:to" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $toid,
			value => $pages[1],
			size => 6,
			maxlength => 10 ) );
		$frag->appendChild( $div );

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
 		$dayid = $self->{name}.$suffix."_day";
 		$monthid = $self->{name}.$suffix."_month";
 		$yearid = $self->{name}.$suffix."_year";

		$div->appendChild( $session->html_phrase( "lib/metafield:year" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $yearid,
			value => $year,
			size => 4,
			maxlength => 4 ) );

		$div->appendChild( $session->make_text(" ") );
		$div->appendChild( $session->html_phrase( "lib/metafield:month" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->render_option_list(
			name => $monthid,
			values => \@monthkeys,
			default => $month,
			labels => $self->_month_names( $session ) ) );
		$div->appendChild( $session->make_text(" ") );
		$div->appendChild( $session->html_phrase( "lib/metafield:day" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $dayid,
			value => $day,
			size => 2,
			maxlength => 2 ) );
		$frag->appendChild( $div );
	}
	else
	{
		$frag->appendChild( $session->make_text( "???" ) );
		$session->get_archive()->log( "Don't know how to render input".
					  "field of type: ".$self->get_type() );
	}
	return $frag;
}

#WP1: BAD
sub _month_names
{
	my( $self , $session ) = @_;
	
	my $months = {};

	my $month;
	foreach $month ( @monthkeys )
	{
		$months->{$month} = $session->phrase( "lib/metafield:month_".$month );
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
		if( $self->get_property( "multiple" ) )
		{
			# Make sure all fields are unique
			# There could be two options with the same id,
			# especially in "subject"
			my %v;
			foreach( @values ) { $v{$_}=1; }
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

	my $suffix = "";
	$suffix = "_$n" if( defined $n );

	my $value;
	if( $self->get_property( "multilang" ) )
	{
		$value = {};
		my $boxcount = $session->param( $self->{name}.$suffix."_langspaces" );
		$boxcount = 1 if( $boxcount < 1 );
		my $i;
		for( $i=1; $i<=$boxcount; ++$i )
		{
			my $subvalue = $self->_form_value_aux2( $session, $suffix."_".$i );
			my $langid = $session->param( $self->{name}.$suffix."_".$i."_lang" );
			if( $langid eq "" ) { $langid = "_".$i; }
			if( defined $subvalue )
			{
				$value->{$langid} = $subvalue;
#cjg -- does not check that this is a valid langid...
			}
	print STDERR ".....................tick: ".$self->{name}.$suffix."_".$i."_lang\n";
		}
#print STDERR "!!".Dumper( $value ) if( $self->{name} =~ m/editor/ );
		$value = undef if( scalar keys %{$value} == 0 );
	}
	else
	{
		$value = $self->_form_value_aux2( $session, $suffix );
	}
#print STDERR ">>".Dumper( $value ) if( $self->{name} =~ m/editor/ );
	if( $self->get_property( "hasid" ) )
	{
		my $id = $session->param( $self->{name}.$suffix."_id" );
		$value = { id=>$id, main=>$value };
	}
	return undef unless( EPrints::Utils::is_set( $value ) );

	return $value;
}

sub _form_value_aux2
{
	my( $self, $session, $suffix ) = @_;
	
print STDERR "Hmmm: ".$self->{name}." / ".$suffix."\n";

	if( $self->is_type( "text", "url", "int", "email", "longtext", "year", "secret", "id" ) )
	{
		my $value = $session->param( $self->{name}.$suffix );
		return undef if( $value eq "" );
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
		return ( defined $form_val ? "TRUE" : "FALSE" );
	}
	elsif( $self->is_type( "date" ) )
	{
		my $day = $session->param( $self->{name}.$suffix."_day" );
		my $month = $session->param( 
					$self->{name}.$suffix."_month" );
		my $year = $session->param( $self->{name}.$suffix."_year" );

		if( defined $day && $month ne "00" && defined $year )
		{
			return $year."-".$month."-".$day;
		}
		return undef;
	}
	elsif( $self->is_type( "name" ) )
	{
		my $data = {};
		foreach( "honourific", "given", "family", "lineage" )
		{
			$data->{$_} = $session->param( $self->{name}.$suffix."_".$_ );
		}
use Data::Dumper;
print STDERR "A".Dumper( $data );
		if( EPrints::Utils::is_set( $data ) )
		{
print STDERR "B\n";
			return $data;
		}
print STDERR "BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n";
		return undef;
	}
	else
	{
		$session->get_archive()->log( 
			"Error: can't do _form_value_aux2 on type ".
			"'".$self->{type}."'" );
		return undef;
	}	
}

# cjg this function should return the most useful version of a field if it
# is a multilang field. Initially the search order will be:
# language of 'session'
# default language
# any language
sub most_local
{
	#cjg not done yet
	my( $self, $session, $value ) = @_;

	return $value;
}

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

sub get_sql_name
{
	my( $self ) = @_;

	if( $self->get_property( "idpart" ) )
	{
		return $self->{name}."_id";
	}
	if( $self->get_property( "mainpart" ) )
	{
		return $self->{name}."_main";
	}
	return $self->{name};
}


1;
