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

use EPrints::MetaField;

BEGIN
{
	our( @ISA );
	@ISA = qw( EPrints::MetaField );
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
		return EPrints::Search::Condition->new( 
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
		return EPrints::Search::Condition->new( "PASS" );
	}

	return EPrints::Search::Condition->new( 
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
		return $self->get_index_codes_basic( $session, $value );
	}
	my( $codes, $grepcodes, $ignored ) = ( [], [], [] );
	foreach my $v (@{$value} )
	{		
		my( $c,$g,$i ) = $self->get_index_codes_basic( $session, $v );
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
		$session->get_repository->call( 
			"extract_words" ,
			$session,
			$value );
	my $newbadwords = [];
	foreach( @{$badwords} ) 
	{ 
		next if( $_ eq "" );
		push @{$newbadwords}, $_;
	}
	return( $codes, $newbadwords );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{text_index} = 1;
	$defaults{sql_index} = 0;
	return %defaults;
}

######################################################################
=pod

=item $val = $field->value_from_sql_row( $session, $row )

Shift and return the utf8 value of this field from the database input $row.

=cut
######################################################################

sub value_from_sql_row
{
	my( $self, $session, $row ) = @_;

	if( $session->{database}->isa( "EPrints::Database::mysql" ) )
	{
		utf8::decode( $row->[0] );
	}

	return shift @$row;
}

=item @row = $field->sql_row_from_value( $session, $value )

Returns the value as an appropriate value for the database.

Replaces invalid XML 1.0 code points with the Unicode substitution character (0xfffd), see http://www.w3.org/International/questions/qa-controls

=cut

sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	return( undef ) if !defined $value;

	$value =~ s/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/\x{fffd}/g;
	
	return( $value );
}

######################################################################
1;
