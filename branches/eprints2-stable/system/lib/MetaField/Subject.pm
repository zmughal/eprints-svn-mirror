######################################################################
#
# EPrints::MetaField::Subject;
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

B<EPrints::MetaField::Subject> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# top

package EPrints::MetaField::Subject;

use strict;
use warnings;

BEGIN
{
	our( @ISA );
	
	@ISA = qw( EPrints::MetaField::Set );
}

use EPrints::MetaField::Set;
use EPrints::Session;

sub render_single_value
{
	my( $self, $value, $dont_link ) = trim_params(@_);

	my $subject = new EPrints::Subject( $value );
	if( !defined $subject )
	{
		return &SESSION->make_text( "?? $value ??" );
	}

	return $subject->render_with_path( $self->get_property( "top" ) );
}

######################################################################
=pod

=item $subject = $field->get_top_subject()

Return the top EPrints::Subject object for this field. Only meaningful
for "subject" type fields.

=cut
######################################################################

sub get_top_subject
{
	my( $self ) = trim_params(@_);

	my $topid = $self->get_property( "top" );
	if( !defined $topid )
	{
		&SESSION->render_error( &SESSION->make_text( 
			'Subject field name "'.$self->get_name().'" has '.
			'no "top" property.' ) );
		exit;
	}
		
	my $topsubject = EPrints::Subject->new( $topid );

	if( !defined $topsubject )
	{
		&SESSION->render_error( &SESSION->make_text( 
			'The top level subject (id='.$topid.') for field '.
			'"'.$self->get_name().'" does not exist. The '.
			'site admin probably has not run import_subjects. '.
			'See the documentation for more information.' ) );
		exit;
	}
	
	return $topsubject;
}

sub render_set_input
{
	my( $self, $default, $required, $obj ) = trim_params(@_);


	my $topsubj = $self->get_top_subject();

	my ( $pairs ) = $topsubj->get_subjects( 
		!($self->{showall}), 
		$self->{showtop},
		0,
		($self->{input_style} eq "short"?1:0) );

	if( !$self->get_property( "multiple" ) && !$required )
	{
		# If it's not multiple and not required there 
		# must be a way to unselect it.
		my $unspec = &SESSION->phrase( 
			"lib/metafield:unspecified_selection" ) ;
		$pairs = [ [ "", $unspec ], @{$pairs} ];
	}

	return &SESSION->render_option_list(
		pairs => $pairs,
		defaults_at_top => 1,
		name => $self->{name},
		default => $default,
		multiple => $self->{multiple},
		height => $self->{input_rows}  );

} 

sub get_unsorted_values
{
	my( $self, $dataset, %opts ) = trim_params(@_);

	my $topsubj = $self->get_top_subject();
	my ( $pairs ) = $topsubj->get_subjects( 
		0 , 
		!$opts{hidetoplevel} , 
		$opts{nestids} );
	my $pair;
	my $v = [];
	foreach $pair ( @{$pairs} )
	{
		push @{$v}, $pair->[0];
	}
	return $v;
}

sub get_value_label
{
	my( $self, $value ) = trim_params(@_);

	my $subj = EPrints::Subject->new( $value );
	if( !defined $subj )
	{
		return &SESSION->make_text( "?? Bad Subject: ".$value." ??" );
	}
	return $subj->render_description();
}

sub render_search_set_input
{
	my( $self, $searchfield ) = trim_params(@_);

	my $prefix = $searchfield->get_form_prefix;
	my $value = $searchfield->get_value;
	
	my $topsubj = $self->get_top_subject();
	my ( $pairs ) = $topsubj->get_subjects( 0, 0 );
	my $max_rows =  $self->get_property( "search_rows" );

	#splice( @{$pairs}, 0, 0, [ "NONE", "(Any)" ] ); #cjg

	my $height = scalar @$pairs;
	$height = $max_rows if( $height > $max_rows );

	my @defaults = ();
	# Do we have any values already?
	if( defined $value && $value ne "" )
	{
		@defaults = split /\s/, $value;
	}

	return &SESSION->render_option_list( 
		name => $prefix,
		defaults_at_top => 1,
		default => \@defaults,
		multiple => 1,
		pairs => $pairs,
		height => $height );
}	

sub get_search_conditions_not_ex
{
	my( $self, $dataset, $search_value, $match, $merge,
		$search_mode ) = trim_params(@_);
	
	return EPrints::SearchCondition->new( 
		'in_subject', 
		$dataset,
		$self, 
		$search_value );
}

sub get_search_group { return 'subject'; }

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_style} = 0;
	$defaults{showall} = 0;
	$defaults{showtop} = 0;
	$defaults{nestids} = 1;
	$defaults{top} = "subjects";
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
}

sub get_values
{
	my( $self, $dataset, %opts ) = trim_params(@_);

	my $topsubj = $self->get_top_subject();
	my ( $pairs ) = $topsubj->get_subjects(
		0,
		1,
		0 );
	my @outvalues;
	foreach my $pair ( @{$pairs} )
	{
		push @outvalues, $pair->[0];
	}
	return \@outvalues;
}

######################################################################
1;
