######################################################################
#
# EPrints::MetaField::Text;
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

B<EPrints::MetaField::Text> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Text;

use strict;
use warnings;

use EPrints::MetaField::Basic;
use EPrints::Session;

BEGIN
{
	our( @ISA );
	@ISA = qw( EPrints::MetaField::Basic );
}



sub render_search_value
{
	my( $self, $value ) = trim_params(@_);

	my $valuedesc = &SESSION->make_doc_fragment;
	$valuedesc->appendChild( &SESSION->make_text( '"' ) );
	$valuedesc->appendChild( &SESSION->make_text( $value ) );
	$valuedesc->appendChild( &SESSION->make_text( '"' ) );
	my( $good, $bad ) = _extract_words( $value );

	if( scalar(@{$bad}) )
	{
		my $igfrag = &SESSION->make_doc_fragment;
		for( my $i=0; $i<scalar(@{$bad}); $i++ )
		{
			if( $i>0 )
			{
				$igfrag->appendChild(
					&SESSION->make_text( 
						', ' ) );
			}
			$igfrag->appendChild(
				&SESSION->make_text( 
					'"'.$bad->[$i].'"' ) );
		}
		$valuedesc->appendChild( 
			&SESSION->html_phrase( 
				"lib/searchfield:desc_ignored",
				list => $igfrag ) );
	}

	return $valuedesc;
}


#sub split_search_value
#{
#	my( $self, $value ) = trim_params(@_);
#
#	my( $codes, $bad ) = _extract_words( $value );
#
#	return @{$codes};
#}

sub get_search_conditions_not_ex
{
	my( $self, $dataset, $search_value, $match, $merge,
		$search_mode ) = trim_params(@_);
	
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
	my( $codes, $bad ) = _extract_words( $search_value );

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
	my( $self, $value ) = trim_params(@_);

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	if( !$self->get_property( "multiple" ) )
	{
		return $self->get_index_codes_single( $value );
	}
	my( $codes, $grepcodes, $ignored ) = ( [], [], [] );
	foreach my $v (@{$value} )
	{		
		my( $c,$g,$i ) = $self->get_index_codes_single( $v );
		push @{$codes},@{$c};
		push @{$grepcodes},@{$g};
		push @{$ignored},@{$i};
	}

	return( $codes, $grepcodes, $ignored );
}

sub get_index_codes_single
{
	my( $self, $value ) = trim_params(@_);

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	$value = $self->which_bit( $value );

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	if( !$self->get_property( "multilang" ) )
	{
		return $self->get_index_codes_basic( $value );
	}

	my( $codes, $grepcodes, $ignored ) = ( [], [], [] );

	foreach my $k (keys %{$value} )
	{		
		my( $c,$g,$i ) = $self->get_index_codes_basic( $value->{$k} );
		push @{$codes},@{$c};
		push @{$grepcodes},@{$g};
		push @{$ignored},@{$i};
	}

	return( $codes, $grepcodes, $ignored );
}	

sub get_index_codes_basic
{
	my( $self, $value ) = trim_params(@_);

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	my( $codes, $badwords ) = _extract_words( $value );

	return( $codes, [], $badwords );
}

# internal function to paper over some cracks in 2.2 
# text indexing config.
sub _extract_words
{
	my( $value ) = trim_params(@_);

	my( $codes, $badwords ) = &ARCHIVE->call( "extract_words" , $value );
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
