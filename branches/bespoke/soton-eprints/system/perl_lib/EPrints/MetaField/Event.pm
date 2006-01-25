######################################################################
#
# EPrints::MetaField::Name;
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

B<EPrints::MetaField::Name> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Event;

use strict;
use warnings;

use Unicode::String qw( latin1 utf8 );

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

my $VARCHAR_SIZE = 255;

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	my $sqlname = $self->get_sql_name();
	my $param = ($notnull?" NOT NULL":"");
	my $vc = 'VARCHAR('.$VARCHAR_SIZE.')';

	return
		$sqlname.'_location '.$vc.' '.$param.', '.
		$sqlname.'_date '.$vc.' '.$param;
}


sub get_input_bits
{
	my( $self, $session ) = @_;

	my @namebits;
	
	push @namebits, "location";
	push @namebits, "date";	
	

	return @namebits;
}

sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;

	my $order = $self->get_property( "render_opts" )->{order};
	
	# If the render opt "order" is set to "gf" then we order
	# the name with given name first. 

	return $session->render_name( 
			$value, 
			defined $order && $order eq "gf" );
}


sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff, $obj ) = @_;

	my $parts = [];
	foreach( $self->get_input_bits( $session ) )
	{
		my $size = $self->{input_name_cols}->{$_};
		push @{$parts}, {el=>$session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $self->{name}.$suffix."_".$_,
			value => $value->{$_},
			size => $size,
			maxlength => $self->{maxlength} ) };
	}

	return [ $parts ];
}

sub get_input_col_titles
{
	my( $self, $session, $staff ) = @_;

	my @r = ();
	foreach my $bit ( $self->get_input_bits( $session ) )
	{
		# deal with some legacy in the phrase id's
		##seb: might need to do the same?!
		$bit = "location" if( $bit eq "location" );
		$bit = "date" if( $bit eq "date" );
		push @r, $session->html_phrase(	"lib/metafield:".$bit );
	}
	return \@r;
}

sub form_value_basic
{
	my( $self, $session, $suffix ) = @_;
	
	my $data = {};
	foreach( "location", "date" )
	{
		$data->{$_} = 
			$session->param( $self->{name}.$suffix."_".$_ );
	}

	unless( EPrints::Utils::is_set( $data ) )
	{
		return( undef );
	}

	return $data;
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	return $session->render_name( $value );
}



# INHERRITS get_search_conditions_not_ex, but it's not called.

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_name_cols} = $EPrints::MetaField::FROM_CONFIG;
#	$defaults{hide_honourific} = $EPrints::MetaField::FROM_CONFIG;
#	$defaults{hide_lineage} = $EPrints::MetaField::FROM_CONFIG;
#	$defaults{family_first} = $EPrints::MetaField::FROM_CONFIG;
	return %defaults;
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $list = $session->get_db()->get_values( $self, $dataset );

	return $list;

	#my $out = [];
	#foreach my $name ( @{$list} )
	#{
		#push @{$out}, $name->{family}.', '.$name->{given};
	#}
	#return $out;
}


sub to_xml_basic
{
	my( $self, $session, $v ) = @_;

	my $r = $session->make_doc_fragment;
	foreach( "location", "date" )
	{
		next unless( defined $v->{$_} && $v->{$_} ne "" );
		my $e = $session->make_element( "part", name=>$_ );
		$e->appendChild( $session->make_text( $v->{$_} ) );
		$r->appendChild( $e );
	}
	return $r;
}


######################################################################
1;
