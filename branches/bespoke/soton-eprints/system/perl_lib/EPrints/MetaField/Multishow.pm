######################################################################
#
# EPrints::MetaField::Date;
#
######################################################################
#
#  This file is part of GNU EPrints 2.
#  
#  Copyright (c) 2000-2004 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 2 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 2 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 2; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Date> - no description

=head1 DESCRIPTION

not done

=over 4

=cut


package EPrints::MetaField::Multishow;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Basic);
}

use EPrints::MetaField::Basic;

sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;
	my $out;
	my $frag;
	my($dateValue,$locationValue);
	if(defined($value))
	{
		($dateValue,$locationValue) = split /[|]/,$value;
		
		if($dateValue ne "" && $locationValue ne "")
		{
			$frag = $session->make_doc_fragment();
			my $span = $session->make_element("span");
			$span->appendChild($session->make_text("".$locationValue." (".$dateValue."), "));
			#my $br = $session->make_element("br");
			$frag->appendChild($span);
			#$frag->appendChild($br);
			$out = $frag;
		}
		else
		{
			$out = $session->make_text("");
		}
	}
	

	return $out;
}
	


sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff, $obj ) = @_;
	my $frag;
	my @out = ();
	print STDERR ("Run the right get basic");
	my($dateValue,$locationValue);
	if(defined($value))
	{
		($dateValue,$locationValue) = split /[|]/,$value;
	}
	else
	{
		$dateValue = "";
		$locationValue = "";
	}
	$frag = $session->make_doc_fragment();
	#my $div = $session->make_element("div");
	my $location = $self->{name}.$suffix."_showlocation";
	$location = $session->make_element( "input",
				"accept-charset" => "utf-8",
				type => "text",
				name => $location,
				value => $locationValue,
				size => 25,
				maxlength => 40 );
	
	my $date = $self->{name}.$suffix."_showdate";
	$date = $session->make_element( "input",
				"accept-charset" => "utf-8",
				type => "text",
				name => $date,
				value => $dateValue,
				size => 25,
				maxlength => 40);
	$frag->appendChild($location);
	$frag->appendChild($session->make_text(" "));
	$frag->appendChild($date);
	
	#$frag->appendChild($div);
	return [ [ { el=>$frag } ] ];
}

sub form_value_basic
{
	my $out;

	my( $self, $session, $suffix ) = @_;
	my $date = $session->param( $self->{name}.$suffix."_showdate" );
	my $location = $session->param( $self->{name}.$suffix."_showlocation" );
	if($date eq "" && $location eq "")
	{
		$out = undef;
		
	}
	else
	{
		$out = $date."|".$location;
		print STDERR ("Value : ".$out."stored - form value basic\n");

	}
	return $out;
}


#sub get_value_label
#{
#	my( $self, $session, $value ) = @_;
#	my $frag = $session->make_doc_fragment();
#	my $list = $session->make_element("p");
#	
#	$list->appendChild($session->make_text("LABEL :: ".$value));
#	
#	$frag->appendChild($list);
#
#	return $frag;
#}

#sub render_search_input
#{
#	my( $self, $session, $searchfield ) = @_;
#	
#	return $session->make_element( "input",
#				"accept-charset" => "utf-8",
#				type => "text",
#				name => $searchfield->get_form_prefix,
#				value => $searchfield->get_value,
#				size => 21,
#				maxlength => 21 );
#}


#sub from_search_form
#{
#	my( $self, $session, $prefix ) = @_;
#
#	my $val = $session->param( $prefix );
#	return unless defined $val;
#
#	my $drange = $val;
#	$drange =~ s/-(\d\d\d\d(-\d\d(-\d\d)?)?)$/-/;
#	$drange =~ s/^(\d\d\d\d(-\d\d(-\d\d)?)?)(-?)$/$4/;
#
#	if( $drange eq "" || $drange eq "-" )
#	{
#		return( $val );
#	}
#			
#	return( undef,undef,undef, $session->phrase( "lib/searchfield:date_err" ) );
#}




#sub get_property_defaults
#{#
#	my( $self ) = @_;
#	my %defaults = ();
#	return %defaults;
#}

######################################################################
1;
