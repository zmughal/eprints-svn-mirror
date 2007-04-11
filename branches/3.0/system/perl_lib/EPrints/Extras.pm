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

        my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".$value."</fragment>" ); };
        if( $@ )
        {
                my $err = $@;
                $err =~ s# at /.*##;
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( "Error parsing XML: ".$err ) );
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


######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success

