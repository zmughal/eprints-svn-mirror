######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::ImportXML;

use XML::Parser;

# function will be called once for each object described by the XML
# file with the session handle, the table and whatever kind of 
# eprint object.

# this module creates an extra property of the parser, calling it
# "eprints". This is used to pass around state information including
# the session handle and the current object.

#cjg NEEDS to spot ID!

#cjg Needs to be able to specify default language (to stop it doing 
# "?" )

sub import_file
{
	my( $session , $filename , $function, $dataset, $theirinfo ) = @_;
	my $parser = new XML::Parser(
		Style => "Subs", 
		ErrorContext => 5,
		Handlers => { 
			Start => \&_handle_start, 
			End => \&_handle_end,
			Char => \&_handle_char 
		} );
	$parser->{eprints} = {};
	$parser->{eprints}->{session} = $session;
	$parser->{eprints}->{theirinfo} = $theirinfo;
	$parser->{eprints}->{function} = $function;
	$parser->{eprints}->{fields} = {};
	foreach( $dataset->get_fields() )
	{
		$parser->{eprints}->{fields}->{$_->{name}}=$_;
	}
	$parser->{eprints}->{dataset} = $dataset;
	$parser->parsefile( $filename );
}

sub _handle_start
{
	my( $parser , $tag , %params ) = @_;
	$tag = uc($tag);
	if( $tag eq "EPRINTSDATA" )
	{
		if( $parser->{eprints}->{started} )
		{
			$parser->xpcroak( "EPRINTSDATA inside EPRINTSDATA" );
		}
		$parser->{eprints}->{started} = 1;
	
		return;
	}

	if( $tag eq "RECORD" )
	{
		if( defined $parser->{eprints}->{data} )
		{
			$parser->xpcroak( "RECORD inside RECORD" );
		}
		$parser->{eprints}->{data} = {};
		return;
	}	

	if( $tag eq "FIELD" )
	{
		if( defined $parser->{eprints}->{currentfield} )
		{
			$parser->xpcroak( "$tag inside other field" );
		}
		#elsif( !defined $parser->{eprints}->{fields}->{$params{name}} )
		#{
		#	$parser->xpcroak( "unknown field: $params{name}" );
		#}
		else
		{
			$parser->{eprints}->{currentfield} = $params{name};
			$parser->{eprints}->{currentdata} = "";
			$parser->{eprints}->{currentid} = $params{id};
		}

		return;
	}

	if( $tag eq "PART" )
	{
		if( !$parser->{eprints}->{currentspecial} )
		{
			$parser->{eprints}->{currentdata} = {};
			$parser->{eprints}->{currentspecial} = 1;
		}
		$parser->{eprints}->{currentspecialpart} = lc $params{name};
		$parser->{eprints}->{currentdata}->{lc $params{name}} = "";
		return;
	}
	
	if( $tag eq "LANG" )
	{
		if( !defined $parser->{eprints}->{currentmultilang} )
		{
			$parser->{eprints}->{currentmultilang} = {};
		}
		$parser->{eprints}->{currentlang} = lc $params{id};
		$parser->{eprints}->{currentdata} = "";
		return;
	}
	
	if( $tag eq "RECORDS")
	{
		return;
	}

	$parser->xpcroak( "Unknown tag: $tag" );
}



sub _handle_end
{
	my ( $parser , $tag ) = @_;
	$tag = uc($tag);
	if ( $tag eq "EPRINTSDATA" )
	{
		delete $parser->{eprints}->{ds};
		delete $parser->{eprints}->{fields};
		return;
	}

	if ( $tag eq "RECORD" )
	{

		my $ds = $parser->{eprints}->{dataset};
		my $item = $ds->make_object(
			$parser->{eprints}->{session},
			$parser->{eprints}->{data} );

	
		&{$parser->{eprints}->{function}}( 
			$parser->{eprints}->{session}, 
			$parser->{eprints}->{dataset},
			$item,
			$parser->{eprints}->{theirinfo});

		delete $parser->{eprints}->{data};
		return;
	}

	if( $tag eq "FIELD" )
	{
#cjg What non OO it has... (call the damn methods, chris!)
		my $fielddata = $parser->{eprints}->{currentdata};
		if( $fielddata eq "" ) { $fielddata = undef; }
		my $currfield = $parser->{eprints}->{currentfield};
		if( $parser->{eprints}->{fields}->{$currfield}->{multilang} )
		{
			my $ml = $parser->{eprints}->{currentmultilang};
			if( !defined $ml ) { $ml = {}; }

			if( defined $fielddata && $fielddata !~ m/^\s*$/ ) { $ml->{"?"} = $fielddata; }
			
			$fielddata = $ml;
		}
		if( $parser->{eprints}->{fields}->{$currfield}->{hasid} )
		{
			$fielddata = {
				main => $fielddata,
				id => $parser->{eprints}->{currentid}
			};
		}
			
		if( $parser->{eprints}->{fields}->{$currfield}->{multiple} )
		{
			push @{ $parser->{eprints}->{data}->{$currfield} }, $fielddata;
		} 
		else
		{
			$parser->{eprints}->{data}->{$currfield}=$fielddata;
		}
		delete $parser->{eprints}->{currentid};
		delete $parser->{eprints}->{currentfield};
		delete $parser->{eprints}->{currentdata};
		delete $parser->{eprints}->{currentmultilang};
		delete $parser->{eprints}->{currentlang};
		delete $parser->{eprints}->{currentspecial};
		delete $parser->{eprints}->{currentspecialpart};
		return;
	}

	if( $tag eq "PART" )
	{
		delete $parser->{eprints}->{currentspecialpart};
		return;
	}
	if( $tag eq "LANG" )
	{
		$parser->{eprints}->{currentmultilang}->{ $parser->{eprints}->{currentlang} } = $parser->{eprints}->{currentdata};
		$parser->{eprints}->{currentdata} = "";
		return;
	}
	$parser->xpcroak( "Unknown end tag: $tag" );
}

sub _handle_char
{
	my( $parser , $text ) = @_;

	if( !defined $parser->{eprints}->{currentdata} )
	{
		return;
	}

	if( $parser->{eprints}->{currentspecial} )
	{
		if( !defined $parser->{eprints}->{currentspecialpart} )
		{
			return;
		}
		$parser->{eprints}->{currentdata}->
			{$parser->{eprints}->{currentspecialpart}} .= $text;
	}
	else
	{	
		$parser->{eprints}->{currentdata}.= $text;
	}
	
}

1;
