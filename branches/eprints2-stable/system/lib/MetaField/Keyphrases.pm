######################################################################
#
# EPrints::MetaField::Keyphrases;
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

B<EPrints::MetaField::Keyphrases> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Keyphrases;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Longtext );
}

use EPrints::MetaField::Longtext;

sub is_browsable
{
	return( 0 );
}


sub get_search_group { return 'keyphrases'; }

sub get_index_codes_basic
{
	my( $self, $value ) = trim_params(@_);

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	my( $codes, $badwords ) = trim_phrase($value);

	return( $codes, [], [] );
}

sub split_search_value
{
	my( $self, $value ) = trim_params(@_);

	return split /,/, $value;
}

sub trim_phrase($$)
{
	my( $phrase ) = trim_params(@_);

	my $codes = [];
	
	# phrases are lowercased
	$phrase = "\L$phrase"; 

	# get rid of non alphanumerics or whitespace
	$phrase =~ s/[^a-z0-9\s]//g;
	
	# top and tail whitespace
	$phrase =~ s/^\s*//;
	$phrase =~ s/\s*$//;

	# multiple whitespace to single space
	$phrase =~ s/\s+/ /g;

	if( $phrase ne '' ) { push @{$codes}, $phrase; }

	return( $codes, [] );
}

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
	my( $codes, $bad ) = trim_phrase($search_value);

	# Just go "yeah" if stemming removed the word
	if( !EPrints::Utils::is_set( $codes->[0] ) )
	{
		return EPrints::SearchCondition->new( "TRUE" );
	}

	return EPrints::SearchCondition->new( 
			'index',
 			$dataset,
			$self, 
			$codes->[0] );
}

######################################################################
1;
