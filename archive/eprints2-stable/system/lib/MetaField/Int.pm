######################################################################
#
# EPrints::MetaField::Int;
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

B<EPrints::MetaField::Int> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Int;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Basic );
}

use EPrints::MetaField::Basic;
use EPrints::Session;

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return $self->get_sql_name()." INTEGER".($notnull?" NOT NULL":"");
}

sub get_max_input_size
{
	my( $self ) = @_;

	return $self->get_digits;
}

sub get_digits
{
	my( $self ) = @_;

	return $self->{digits}
}

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	unless( EPrints::Utils::is_set( $value ) )
	{
		return "";
	}

	# just in case we still use eprints in year 200k 
	my $pad = $self->get_digits;
	return sprintf( "%0".$pad."d",$value );
}

sub render_search_input
{
	my( $self, $searchfield ) = trim_params(@_);
	
	return &SESSION->make_element( "input",
				"accept-charset" => "utf-8",
				name=>$searchfield->get_form_prefix,
				value=>$searchfield->get_value,
				size=>9,
				maxlength=>100 );
}

sub from_search_form
{
	my( $self, $prefix ) = trim_params(@_);

	my $val = &SESSION->param( $prefix );
	return unless defined $val;

	if( $val =~ m/^(\d+)?\-?(\d+)?/ )
	{
		return( $val );
	}
			
	return( undef,undef,undef, &SESSION->phrase( "lib/searchfield:int_err" ) );
}

sub render_search_value
{
	my( $self, $value ) = trim_params(@_);

	my $type = $self->get_type;

	if( $value =~ m/^([0-9]+)-([0-9]+)$/ )
	{
		return &SESSION->html_phrase(
			"lib/searchfield:desc_".$type."_between",
			from => &SESSION->make_text( $1 ),
			to => &SESSION->make_text( $2 ) );
	}

	if( $value =~ m/^-([0-9]+)$/ )
	{
		return &SESSION->html_phrase(
			"lib/searchfield:desc_".$type."_orless",
			to => &SESSION->make_text( $1 ) );
	}

	if( $value =~ m/^([0-9]+)-$/ )
	{
		return &SESSION->html_phrase(
			"lib/searchfield:desc_".$type."_ormore",
			from => &SESSION->make_text( $1 ) );
	}

	return &SESSION->make_text( $value );
}

sub get_search_conditions_not_ex
{
	my( $self, $dataset, $search_value, $match, $merge,
		$search_mode ) = trim_params(@_);
	
	# N
	# N-
	# -N
	# N-N

	if( $search_value =~ m/^\d+$/ )
	{
		return EPrints::SearchCondition->new( 
			'=', 
			$dataset,
			$self, 
			$search_value );
	}

	unless( $search_value=~ m/^(\d+)?\-(\d+)?$/ )
	{
		return EPrints::SearchCondition->new( 'FALSE' );
	}

	my @r = ();
	if( defined $1 && $1 ne "" )
	{
		push @r, EPrints::SearchCondition->new( 
				'>=',
				$dataset,
				$self,
				$1);
	}

	if( defined $2 && $2 ne "" )
	{
		push @r, EPrints::SearchCondition->new( 
				'<=',
				$dataset,
				$self,
				$2 );
	}

	if( scalar @r == 1 ) { return $r[0]; }
	if( scalar @r == 0 )
	{
		return EPrints::SearchCondition->new( 'FALSE' );
	}

	return EPrints::SearchCondition->new( "AND", @r );
}

sub get_search_group { return 'int'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{digits} = $EPrints::MetaField::FROM_CONFIG;
	return %defaults;
}

######################################################################
1;
