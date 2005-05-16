######################################################################
#
# EPrints::MetaField::Set;
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

B<EPrints::MetaField::Set> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Set;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Basic );
}

use EPrints::MetaField::Basic;

sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;

	return $self->render_option( $session , $value );
}

######################################################################
=pod

=item ( $options , $labels ) = $field->tags_and_labels( $session )

Return a reference to an array of options for this
field, plus an array of UTF-8 encoded labels for these options in the 
current language.

=cut
######################################################################

sub tags_and_labels
{
	my( $self , $session ) = @_;
	my %labels = ();
	foreach( @{$self->{options}} )
	{
		$labels{$_} = EPrints::Utils::tree_to_utf8( 
			$self->render_option( $session, $_ ) );
	}
	return ($self->{options}, \%labels);
}

######################################################################
=pod

=item $xhtml = $field->render_option( $session, $option )

Return the title of option $option in the language of $session as an 
XHTML DOM object.

=cut
######################################################################

sub render_option
{
	my( $self, $session, $option ) = @_;

	my $phrasename = $self->{confid}."_fieldopt_".$self->{name}."_".$option;

	return $session->html_phrase( $phrasename );
}


sub render_input_field_actual
{
	my( $self, $session, $value, $dataset, $type, $staff, $hidden_fields, $obj ) = @_;

	my $required = $self->get_property( "required" );
	if( defined $dataset && defined $type )
	{
		$required = $dataset->field_required_in_type( $self, $type );
	}

	my %settings;
	my $default = $value;
	$default = [ $value ] unless( $self->get_property( "multiple" ) );
	$default = [] if( !defined $value );

	# called as a seperate function because subject does this
	# bit differently, and overrides render_set_input.
	return $self->render_set_input( $session, $default, $required, $obj );
}

# basic input renderer for "set" type fields
sub render_set_input
{
	my( $self, $session, $default, $required, $obj ) = @_;

	my( $tags, $labels ) = $self->tags_and_labels( $session );

	if( $self->get_property( "input_style" ) ne "long" )
	{
		if( 
			!$self->get_property( "multiple" ) && 
			!$required ) 
		{
			# If it's not multiple and not required there 
			# must be a way to unselect it.
			$tags = [ "", @{$tags} ];
			my $unspec = $session->phrase( 
				"lib/metafield:unspecified_selection" );
			$labels = { ""=>$unspec, %{$labels} };
		}

		return( $session->render_option_list(
				values => $tags,
				labels => $labels,
				name => $self->{name},
				default => $default,
				multiple => $self->{multiple},
				height => $self->{input_rows}  ) );
	}


	if( $self->{multiple} )
	{
		$session->get_archive->log( "Using input_style long for a 'multiple' field. It's only intended for\nnon-multiple fields." );
	}

	my( $dl, $dt, $dd );
	$dl = $session->make_element( "dl", class=>"longset" );
	foreach my $opt ( @{$tags} )
	{
		$dt = $session->make_element( "dt" );
		$dt->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "radio",
			name => $self->{name},
			value => $opt,
			checked => ( $default->[0] eq $opt ?"checked":undef) ));
		$dt->appendChild( $session->make_text( " ".$labels->{$opt} ));
		$dl->appendChild( $dt );
		$dd = $session->make_element( "dd" );
		my $phrasename = $self->{confid}."_optdetails_".$self->{name}."_".$opt;
		$dd->appendChild( $session->html_phrase( $phrasename ));
		$dl->appendChild( $dd );
	}
	return $dl;
}

sub form_value_actual
{
	my( $self, $session ) = @_;
	
	my @values = $session->param( $self->{name} );
	
	if( scalar( @values ) == 0 )
	{
		return undef;
	}

	if( $self->get_property( "multiple" ) )
	{
		# Make sure all fields are unique
		# There could be two options with the same id,
		# especially in "subject"
		my %v;
		foreach( @values ) { $v{$_}=1; }
		delete $v{"-"}; # for the  ------- in defaults at top
		@values = keys %v;
		return \@values;
	}

	return $values[0];
}

# the ordering for set is NOT the same as for normal
# fields.
sub get_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	return $self->get_property( "options" );
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;
		
	return $self->render_option( $session, $value );
}

sub ordervalue_single
{
	my( $self , $value , $session , $langid ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	my $label = $self->get_value_label( $session, $value );
	return EPrints::Utils::tree_to_utf8( $label );
}

sub render_search_input
{
	my( $self, $session, $searchfield ) = @_;
	
	my $frag = $session->make_doc_fragment;
	
	$frag->appendChild( $self->render_search_set_input( 
				$session,
				$searchfield ) );

	if( $self->get_property( "multiple" ) )
	{
		my @set_tags = ( "ANY", "ALL" );
		my %set_labels = ( 
			"ANY" => $session->phrase( "lib/searchfield:set_any" ),
			"ALL" => $session->phrase( "lib/searchfield:set_all" ) );


		$frag->appendChild( $session->make_text(" ") );
		$frag->appendChild( 
			$session->render_option_list(
				name=>$searchfield->get_form_prefix."_merge",
				values=>\@set_tags,
				default=>$searchfield->get_merge,
				labels=>\%set_labels ) );
	}

	return $frag;
}

sub render_search_set_input
{
	my( $self, $session, $searchfield ) = @_;

	my $prefix = $searchfield->get_form_prefix;
	my $value = $searchfield->get_value;

	my( $tags, $labels ) = ( [], {} );
	# find all the fields we're searching to get their options
	# too if we need to!
	my @allfields = @{$searchfield->get_fields};
	if( scalar @allfields == 1 )
	{
		( $tags, $labels ) = $self->tags_and_labels( $session );
	}
	else
	{
		my( $t ) = {};
		foreach my $field ( @allfields )
		{
			my ( $t2, $l2 ) = $field->tags_and_labels( $session );
			foreach( @{$t2} ) { $t->{$_}=1; }
			foreach( keys %{$l2} ) { $labels->{$_}=$l2->{$_}; }
		}
		my @tags = keys %{$t};
		$tags = \@tags;
	}

	my $max_rows =  $self->get_property( "search_rows" );

	my $height = scalar @$tags;
	$height = $max_rows if( $height > $max_rows );

	my @defaults = ();;
	# Do we have any values already?
	if( defined $value && $value ne "" )
	{
		@defaults = split /\s/, $value;
	}

	return $session->render_option_list( 
		name => $prefix,
		default => \@defaults,
		multiple => 1,
		labels => $labels,
		values => $tags,
		height => $height );
}	

sub from_search_form
{
	my( $self, $session, $prefix ) = @_;

	my @vals = ();
	foreach( $session->param( $prefix ) )
	{
		next if m/^\s*$/;
		# ignore the "--------" divider.
		next if m/^-$/;
		push @vals,$_;
	}
		
	return if( scalar @vals == 0 );

#	foreach (@vals)
#	{
#		return if( $_ eq "NONE" );
#	}

	# We have some values. Join them together.
	my $val = join ' ', @vals;

	# ANY or ALL?
	my $merge = $session->param( $prefix."_merge" );
	$merge = "ANY" unless( defined $merge );
	
	return( $val, $merge );
}

	
sub render_search_description
{
	my( $self, $session, $sfname, $value, $merge, $match ) = @_;

	my $phraseid;
	if( $merge eq "ANY" )
	{
		$phraseid = "lib/searchfield:desc_any_in";
	}
	else
	{
		$phraseid = "lib/searchfield:desc_all_in";
	}

	my $valuedesc = $session->make_doc_fragment;
	my @list = split( ' ',  $value );
	for( my $i=0; $i<scalar @list; ++$i )
	{
		if( $i>0 )
		{
			$valuedesc->appendChild( $session->make_text( ", " ) );
		}
		$valuedesc->appendChild( $session->make_text( '"' ) );
		$valuedesc->appendChild(
			$self->get_value_label( $session, $list[$i] ) );
		$valuedesc->appendChild( $session->make_text( '"' ) );
	}

	return $session->html_phrase(
		$phraseid,
		name => $sfname, 
		value => $valuedesc ); 
}

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	return EPrints::SearchCondition->new( 
		'=', 
		$dataset,
		$self, 
		$search_value );
}

sub get_search_group { return 'set'; }

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_style} = 0;
	$defaults{input_rows} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{search_rows} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{options} = $EPrints::MetaField::REQUIRED;
	return %defaults;
}

######################################################################
1;
