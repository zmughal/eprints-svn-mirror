######################################################################
#
# EPrints::Extras;
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

B<EPrints::Extras> - Alternate versions of certain methods.

=head1 DESCRIPTION

This module contains methods provided as alternates to the
default render or input methods.

=head1 METHODS

=over 4

=cut 

package EPrints::Extras;

use warnings;
use strict;



######################################################################
=pod

=item $xhtml = EPrints::Extras::render_xhtml_field( $session, $field,
$value )

Return an XHTML DOM object of the contents of $value. In the case of
an error parsing the XML in $value return an XHTML DOM object 
describing the problem.

This is intented to be used by the render_single_value metadata 
field option, as an alternative to the default text renderer. 

This allows through any XML element, so could cause problems if
people start using SCRIPT to make pop-up windows. A later version
may allow a limited set of elements only.

=cut
######################################################################

sub render_xhtml_field
{
	my( $session , $field , $value ) = @_;

	if( !defined $value ) { return $session->make_doc_fragment; }
        my( %c ) = (
                ParseParamEnt => 0,
                ErrorContext => 2,
                NoLWP => 1 );

		local $SIG{__DIE__};
        my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".$value."</fragment>" ); };
        if( $@ )
        {
                my $err = $@;
                $err =~ s# at /.*##;
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( "Error parsing XML in render_xhtml_field: ".$err ) );
		return $pre;
        }
	my $fragment = $session->make_doc_fragment;
	my $top = ($doc->getElementsByTagName( "fragment" ))[0];
	foreach my $node ( $top->getChildNodes )
	{
		$fragment->appendChild(
			$session->clone_for_me( $node, 1 ) );
	}
	EPrints::XML::dispose( $doc );
		
	return $fragment;
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_preformatted_field( $session, $field, $value )

Return an XHTML DOM object of the contents of $value.

The contents of $value will be rendered in an HTML <pre>
element. 

=cut
######################################################################

sub render_preformatted_field
{
	my( $session , $field , $value ) = @_;

	my $pre = $session->make_element( "pre" );
	$value =~ s/\r\n/\n/g;
	$pre->appendChild( $session->make_text( $value ) );
		
	return $pre;
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_hightlighted_field( $session, $field, $value )

Return an XHTML DOM object of the contents of $value.

The contents of $value will be rendered in an HTML <pre>
element. 

=cut
######################################################################

sub render_highlighted_field
{
	my( $session , $field , $value, $alllangs, $nolink, $object ) = @_;

	my $div = $session->make_element( "div", class=>"ep_highlight" );
	my $v=$field->render_value_actual( $session, $value, $alllangs, $nolink, $object );
	$div->appendChild( $v );	
	return $div;
}

sub render_lookup_list
{
	my( $session, $rows ) = @_;

	my $ul = $session->make_element( "ul" );

	my $first = 1;
	foreach my $row (@$rows)
	{
		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );
		if( $first )
		{
			$li->setAttribute( "class", "ep_first" );
			$first = 0;
		}
		if( defined($row->{xhtml}) )
		{
			$li->appendChild( $row->{xhtml} );
		}
		elsif( defined($row->{desc}) )
		{
			$li->appendChild( $session->make_text( $row->{desc} ) );
		}
		my @values = @{$row->{values}};
		my $ul = $session->make_element( "ul" );
		$li->appendChild( $ul );
		for(my $i = 0; $i < @values; $i+=2)
		{
			my( $name, $value ) = @values[$i,$i+1];
			my $li = $session->make_element( "li", id => $name );
			$ul->appendChild( $li );
			$li->appendChild( $session->make_text( $value ) );
		}
	}

	return $ul;
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_url_truncate_end( $session, $field, $value )

Hyper link the URL but truncate the end part if it gets longer 
than 50 characters.

=cut
######################################################################

sub render_url_truncate_end
{
	my( $session, $field, $value ) = @_;

	my $len = 50;	
	my $link = $session->render_link( $value );
	my $text = $value;
	if( length( $value ) > $len )
	{
		$text = substr( $value, 0, $len )."...";
	}
	$link->appendChild( $session->make_text( $text ) );
	return $link
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_url_truncate_middle( $session, $field, $value )

Hyper link the URL but truncate the middle part if it gets longer 
than 50 characters.

=cut
######################################################################

sub render_url_truncate_middle
{
	my( $session, $field, $value ) = @_;

	my $len = 50;	
	my $link = $session->render_link( $value );
	my $text = $value;
	if( length( $value ) > $len )
	{
		$text = substr( $value, 0, $len/2 )."...".substr( $value, -$len/2, -1 );
	}
	$link->appendChild( $session->make_text( $text ) );
	return $link
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_related_url( $session, $field, $value )

Hyper link the URL but truncate the middle part if it gets longer 
than 50 characters.

=cut
######################################################################

sub render_related_url
{
	my( $session, $field, $value ) = @_;

	my $f = $field->get_property( "fields_cache" );
	my $fmap = {};	
	foreach my $field_conf ( @{$f} )
	{
		my $fieldname = $field_conf->{name};
		my $field = $field->{dataset}->get_field( $fieldname );
		$fmap->{$field_conf->{sub_name}} = $field;
	}

	my $ul = $session->make_element( "ul" );
	foreach my $row ( @{$value} )
	{
		my $li = $session->make_element( "li" );
		my $link = $session->render_link( $row->{url} );
		if( defined $row->{type} )
		{
			$link->appendChild( $fmap->{type}->render_single_value( $session, $row->{type} ) );
		}
		else
		{
			my $text = $row->{url};
			if( length( $text ) > 40 ) { $text = substr( $value, 0, 40 )."..."; }
			$link->appendChild( $session->make_text( $text ) );
		}
		$li->appendChild( $link );
		$ul->appendChild( $li );
	}

	return $ul;
}

######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success

