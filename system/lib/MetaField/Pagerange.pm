######################################################################
#
# EPrints::MetaField::Pagerange;
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

B<EPrints::MetaField::Pagerange> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Pagerange;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

# note that this renders pages ranges differently from
# eprints 2.2
sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;

	unless( $value =~ m/^(\d+)-(\d+)$/ )
	{
		# value not in expected form. Ah, well. Muddle through.
		return $session->make_text( $value );
	}

	my( $a, $b ) = ( $1, $2 );

	# possibly there could be a non-breaking space after p.?

	if( $a == $b )
	{
		my $frag = $session->make_doc_fragment();
		$frag->appendChild( $session->make_text( "p." ) );
		$frag->appendChild( $session->render_nbsp );
		$frag->appendChild( $session->make_text( $a ) );
	}

#	consider compressing pageranges so that
#	207-209 is rendered as 207-9
#
#       if( length $a == length $b )
#       {
#       }

	my $frag = $session->make_doc_fragment();
	$frag->appendChild( $session->make_text( "pp." ) );
	$frag->appendChild( $session->render_nbsp );
	$frag->appendChild( $session->make_text( $a.'-'.$b ) );

	return $frag;
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff, $obj ) = @_;

	my @pages = split /-/, $value if( defined $value );
 	my $fromid = $self->{name}.$suffix."_from";
 	my $toid = $self->{name}.$suffix."_to";
		
	my $frag = $session->make_doc_fragment;

	$frag->appendChild( $session->make_element(
		"input",
		"accept-charset" => "utf-8",
		name => $fromid,
		value => $pages[0],
		size => 6,
		maxlength => 10 ) );

	$frag->appendChild( $session->make_text(" ") );
	$frag->appendChild( $session->html_phrase( 
		"lib/metafield:to" ) );
	$frag->appendChild( $session->make_text(" ") );

	$frag->appendChild( $session->make_element(
		"input",
		"accept-charset" => "utf-8",
		name => $toid,
		value => $pages[1],
		size => 6,
		maxlength => 10 ) );

	return [ [ { el=>$frag } ] ];
}

sub is_browsable
{
	return( 1 );
}

sub form_value_basic
{
	my( $self, $session, $suffix ) = @_;
	
	my $from = $session->param( $self->{name}.$suffix."_from" );
	my $to = $session->param( $self->{name}.$suffix."_to" );

	if( !defined $to || $to eq "" )
	{
		return( $from );
	}
		
	return( $from . "-" . $to );
}

sub get_search_group { return 'pagerange'; } 

######################################################################
1;
