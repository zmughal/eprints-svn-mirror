######################################################################
#
# EPrints::MetaField::Text;
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

B<EPrints::MetaField::Text> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Text;

use strict;
use warnings;

use EPrints::MetaField::Basic;

BEGIN
{
	our( @ISA );
	@ISA = qw( EPrints::MetaField::Basic );
}



sub render_search_value
{
	my( $self, $session, $value ) = @_;

	my $valuedesc = $session->make_doc_fragment;
	$valuedesc->appendChild( $session->make_text( '"' ) );
	$valuedesc->appendChild( $session->make_text( $value ) );
	$valuedesc->appendChild( $session->make_text( '"' ) );
	my( $good, $bad ) = _extract_words( $session, $value );

	if( scalar(@{$bad}) )
	{
		my $igfrag = $session->make_doc_fragment;
		for( my $i=0; $i<scalar(@{$bad}); $i++ )
		{
			if( $i>0 )
			{
				$igfrag->appendChild(
					$session->make_text( 
						', ' ) );
			}
			$igfrag->appendChild(
				$session->make_text( 
					'"'.$bad->[$i].'"' ) );
		}
		$valuedesc->appendChild( 
			$session->html_phrase( 
				"lib/searchfield:desc_ignored",
				list => $igfrag ) );
	}

	return $valuedesc;
}


#sub split_search_value
#{
#	my( $self, $session, $value ) = @_;
#
#	my( $codes, $bad ) = _extract_words( $session, $value );
#
#	return @{$codes};
#}

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	if( $match eq "EQ" )
	{
		return EPrints::SearchCondition->new( 
			'=', 
			$dataset,
			$self, 
			$search_value );
	}

	# free text!

	# apply stemming and stuff
	my( $codes, $bad ) = _extract_words( $session, $search_value );

	# Just go "yeah" if stemming removed the word
	if( !EPrints::Utils::is_set( $codes->[0] ) )
	{
		return EPrints::SearchCondition->new( "PASS" );
	}

	return EPrints::SearchCondition->new( 
			'index',
 			$dataset,
			$self, 
			$codes->[0] );
}

sub get_search_group { return 'text'; }

sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	if( !$self->get_property( "multiple" ) )
	{
		return $self->get_index_codes_single( $session, $value );
	}
	my( $codes, $grepcodes, $ignored ) = ( [], [], [] );
	foreach my $v (@{$value} )
	{		
		my( $c,$g,$i ) = $self->get_index_codes_single( $session, $v );
		push @{$codes},@{$c};
		push @{$grepcodes},@{$g};
		push @{$ignored},@{$i};
	}

	return( $codes, $grepcodes, $ignored );
}

sub get_index_codes_single
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	$value = $self->which_bit( $value );

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	if( !$self->get_property( "multilang" ) )
	{
		return $self->get_index_codes_basic( $session, $value );
	}

	my( $codes, $grepcodes, $ignored ) = ( [], [], [] );

	foreach my $k (keys %{$value} )
	{		
		my( $c,$g,$i ) = $self->get_index_codes_basic( $session, $value->{$k} );
		push @{$codes},@{$c};
		push @{$grepcodes},@{$g};
		push @{$ignored},@{$i};
	}

	return( $codes, $grepcodes, $ignored );
}	

sub get_index_codes_basic
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	my( $codes, $badwords ) = _extract_words( $session, $value );

	return( $codes, [], $badwords );
}

# internal function to paper over some cracks in 2.2 
# text indexing config.
sub _extract_words
{
	my( $session, $value ) = @_;

	my( $codes, $badwords ) = 
		$session->get_archive()->call( 
			"extract_words" , 
			$value );
	my $newbadwords = [];
	foreach( @{$badwords} ) 
	{ 
		next if( $_ eq "" );
		push @{$newbadwords}, $_;
	}
	return( $codes, $newbadwords );
}



######################################################################
1;
