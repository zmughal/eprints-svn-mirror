######################################################################
#
# EPrints::MetaField::Boolean;
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

B<EPrints::MetaField::Boolean> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Boolean;

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

	return $self->get_sql_name()." SET('TRUE','FALSE')".($notnull?" NOT NULL":"");
}

sub get_index_codes
{
	my( $self, $value ) = trim_params(@_);

	return( [], [], [] );
}


sub render_single_value
{
	my( $self, $value, $dont_link ) = trim_params(@_);

	return &SESSION->html_phrase(
		"lib/metafield:".($value eq "TRUE"?"true":"false") );
}


sub get_basic_input_elements
{
	my( $self, $value, $suffix, $staff, $obj ) = trim_params(@_);

	my( $div , $id);
 	$id = $self->{name}.$suffix;
		
	if( $self->{input_style} eq "menu" )
	{
		my %settings = (
			height=>2,
			values=>[ "TRUE", "FALSE" ],
			labels=>{
TRUE=> &SESSION->phrase( $self->{confid}."_fieldopt_".$self->{name}."_TRUE"),
FALSE=> &SESSION->phrase( $self->{confid}."_fieldopt_".$self->{name}."_FALSE")
			},
			name=>$id,
			default=>$value
		);
		return [[{ el=>&SESSION->render_option_list( %settings ) }]];
	}

	if( $self->{input_style} eq "radio" )
	{
		# render as radio buttons

		my $true = &SESSION->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "radio",
			checked=>( defined $value && $value eq 
					"TRUE" ? "checked" : undef ),
			name => $id,
			value => "TRUE" );
		my $false = &SESSION->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "radio",
			checked=>( defined $value && $value ne 
					"TRUE" ? "checked" : undef ),
			name => $id,
			value => "FALSE" );
		return [[{ el=>&SESSION->html_phrase(
			$self->{confid}."_radio_".$self->{name},
			true=>$true,
			false=>$false ) }]];
	}
			
	# render as checkbox (ugly)
	return [[{ el=>&SESSION->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "checkbox",
				checked=>( defined $value && $value eq 
						"TRUE" ? "checked" : undef ),
				name => $id,
				value => "TRUE" ) }]];
}

sub form_value_basic
{
	my( $self, $suffix ) = trim_params(@_);
	
	my $form_val = &SESSION->param( $self->{name}.$suffix );
	my $true = 0;
	if( 
		$self->{input_style} eq "radio" || 
		$self->{input_style} eq "menu" )
	{
			$true = (defined $form_val && $form_val eq "TRUE");
	}
	else
	{
		$true = defined $form_val;
	}
	return ( $true ? "TRUE" : "FALSE" );
}

sub get_unsorted_values
{
	my( $self, $dataset, %opts ) = trim_params(@_);

	return [ "TRUE", "FALSE" ];
}


sub render_search_input
{
	my( $self, $searchfield ) = trim_params(@_);
	
	# Boolean: Popup menu

	my @bool_tags = ( "EITHER", "TRUE", "FALSE" );
	my %bool_labels = ( 
"EITHER" => &SESSION->phrase( "lib/searchfield:bool_nopref" ),
"TRUE"   => &SESSION->phrase( "lib/searchfield:bool_yes" ),
"FALSE"  => &SESSION->phrase( "lib/searchfield:bool_no" ) );

	my $value = $searchfield->get_value;	
	return &SESSION->render_option_list(
		name => $searchfield->get_form_prefix,
		values => \@bool_tags,
		default => ( defined $value ? $value : $bool_tags[0] ),
		labels => \%bool_labels );
}

sub from_search_form
{
	my( $self, $prefix ) = trim_params(@_);

	my $val = &SESSION->param( $prefix );

	return unless defined $val;

	return( "FALSE" ) if( $val eq "FALSE" );
	return( "TRUE" ) if( $val eq "TRUE" );
	return;
}

sub render_search_description
{
	my( $self, $sfname, $value, $merge, $match ) = trim_params(@_);

	if( $value eq "TRUE" )
	{
		return &SESSION->html_phrase(
			"lib/searchfield:desc_true",
			name => $sfname );
	}

	return &SESSION->html_phrase(
		"lib/searchfield:desc_false",
		name => $sfname );
}


sub get_search_conditions_not_ex
{
	my( $self, $dataset, $search_value, $match, $merge,
		$search_mode ) = trim_params(@_);
	
	return EPrints::SearchCondition->new( 
		'=', 
		$dataset,
		$self, 
		$search_value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_style} = 0;
	return %defaults;
}

######################################################################
1;
