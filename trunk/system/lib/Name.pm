######################################################################
#
#  Routines for handling names
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

package EPrints::Name;

use EPrints::Log;

use strict;


######################################################################
#
# $html = format_name( $namespec, $familylast )
#
#  Takes a name (a reference to a hash containing keys
#  "family" and "given" and returns it rendered 
#  for screen display.
#
######################################################################

sub format_name
{
	my( $name, $familylast ) = @_;

	if( $familylast )
	{
		return "$$name{given} $$name{family}";
	}
print "<sigh>\n" if (!defined $$name{given});
		
	return "$$name{family}, $$name{given}";
}

######################################################################
#
# $html = format_names( $namelist, $familylast )
#
#  Takes a list of names and formats them 
#  for screen display.
#
######################################################################

sub format_names
{
	my ( $namelist , $familylast ) = @_;
	my $html = "";
	my $i;
	my @names = @{$namelist};

	for( $i=0; $i<=$#names; $i++ )
	{
		if( $i==$#names && $#names > 0 )
		{
			# If it's the last name and there's >1 name, add " and "
			$html .= " and ";
		}
		elsif( $i > 0 )
		{
			$html .= ", ";
		}
		$html .= format_name( $names[$i] , $familylast );
		
	}

	return( $html );
}



######################################################################
#
# $newvalue = add_name( $oldvalue, $surname, $firstname )
#
#  Adds the given name to the list of names in $oldvalue.
#
######################################################################

sub add_name
{
	my( $oldvalue, $surname, $firstname ) = @_;
	
	my $new_value = ( defined $oldvalue ? $oldvalue : ":" );

	$new_value .= "$surname,$firstname:";
	
	return( $new_value );
}


######################################################################
#
# $namespec = import_names( $list, $join_char )
#
#  Formats a list of names into the internal format used by EPrints.
#  $join_char is the character that separates names in the old list.
#
######################################################################

sub import_names
{
	my( $list, $join_char ) = @_;
	
	my @oldnames = split /\s*$join_char\s*/, $list;
	my $n;	

	my $namelist = undef;

	foreach $n (@oldnames)
	{
		if( $n =~ /,/ )
		{
			# It's in the form surname, first names (we hope)
			my( $surname, $firstnames ) = split /\,\s*/, $n;
			$namelist = EPrints::Name::add_name( $namelist,
			                                     $surname,
			                                     $firstnames );
		}
		else
		{
			# Form firstname surname
			my( $surname, $firstnames ) = EPrints::Name::split_name( $n );
			$namelist = EPrints::Name::add_name( $namelist, $surname, $firstnames )
				if( defined $surname );
		}
	}

	return( $namelist );
}


######################################################################
#
# ( $surname, $firstnames ) = split_name( $name )
#
#  This utility method splits a name into surname and firstname parts.
#  It recognises when a comma is used to put the surname first. It
#  also recognises words like "van" and "van der" as part of the surname.
#  (Technically termed in the code "middle bits".)
#
######################################################################

sub split_name
{
	my( $name ) = @_;
	
	# If the name is empty, return undef
	return( undef ) if( !defined $name || $name eq "" );

	my @names = split /\s+/, $name;
	
	my $middle_bits = 0;

	# If there's more than one part to the name, count how many "middle bits"
	# there are (i.e. words like "van" and "de" that are part of the surname,
	# but aren't the last word in the name)
	if( $#names >= 1 )
	{
		my @known_middle_bits = ( "van", "de", "von", "der" );
		
		my $i;
		for( $i = $#names - 1; $i > 0; $i-- )
		{
			my $possible_middle_bit = $names[$#names-1];
			my $is_middle_bit = 0;
		
			foreach (@known_middle_bits)
			{
				$is_middle_bit = 1 if( (lc $_) eq (lc $possible_middle_bit) );
			}

			if( $is_middle_bit )
			{
				$middle_bits++;
			}
			else
			{
				$i = 0;
			}
		}
	}
		
	# Now split the name up
	my $firstnames = "";
	my $surname = "";
	my $i;

	if( $middle_bits )
	{	
		my $i;

		# Collect the surname
		for( $i = $#names; $i >= $#names-$middle_bits; $i-- )
		{
			$surname = $names[$i]." ".$surname;
		}
		
		# Remove trailing spaces
		$surname =~ s/\s*$//;

		for( $i=0; $i<$#names-$middle_bits; $i++ )
		{
			$firstnames .= " " if ($i>0);
			$firstnames .= $names[$i];
		}
	}
	else
	{
		$surname = $names[$#names];

		for( $i=0; $i<$#names; $i++ )
		{
			$firstnames .= " " if ($i>0);
			$firstnames .= $names[$i];
		}
	}

	my @result = ( $surname, $firstnames );
	
	return( @result );
}

1;
