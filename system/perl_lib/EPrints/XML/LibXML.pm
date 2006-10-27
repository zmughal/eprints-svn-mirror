######################################################################
#
# EPrints::XML::LibXML
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

B<EPrints::XML::LibXML> - LibXML subs for EPrints::XML

=head1 DESCRIPTION

This module is not a package, it's a set of subroutines to be
loaded into EPrints::XML namespace if we're using XML::LibXML

=over 4

=cut

use XML::LibXML;
# $XML::LibXML::skipXMLDeclaration = 1; # Same behaviour as XML::DOM

$EPrints::XML::PREFIX = "XML::LibXML::";

##############################################################################
# DOM spec fixes
##############################################################################

{
	no warnings; # don't complain about redefinition
	# incorrectly set to '#cdata'
	*XML::LibXML::CDATASection::nodeName = sub { '#cdata-section' };
}
# these aren't set at all
*XML::LibXML::Document::nodeName = sub { '#document' };
*XML::LibXML::DocumentFragment::nodeName = sub { '#document-fragment' };

# incorrectly set to 'text'
*XML::LibXML::Text::nodeName = sub { '#text' };

##############################################################################
# GDOME compatibility
##############################################################################

# Make getElementsByTagName use LocalName, because EPrints doesn't use
# namespacing when searching DOM trees
*XML::LibXML::Element::getElementsByTagName =
*XML::LibXML::Document::getElementsByTagName =
*XML::LibXML::DocumentFragment::getElementsByTagName =
	\&XML::LibXML::Element::getElementsByLocalName;

# LibXML doesn't set a root element on $doc->appendChild (unused, but could
# cause problems)
*XML::LibXML::Document::appendChild = sub {
		my( $self, $node ) = @_;
		$self->SUPER::appendChild( $node );
		$self->setDocumentElement( $node );
		return $node;
	};

##############################################################################

our $PARSER = XML::LibXML->new();

=item $doc = parse_xml_string( $string )

Create a new DOM document from $string.

=cut

sub parse_xml_string
{
	my( $string ) = @_;

	return $PARSER->parse_string( $string );
}

=item $doc = parse_xml( $filename [, $basepath [, $no_expand]] )

Parse $filename and return it as a new DOM document.

=cut

sub parse_xml
{
	my( $file, $basepath, $no_expand ) = @_;

	unless( -r $file )
	{
		EPrints::Config::abort( "Can't read XML file: '$file'" );
	}

#	my $tmpfile = $file;
#	if( defined $basepath )
#	{	
#		$tmpfile =~ s#/#_#g;
#		$tmpfile = $basepath."/".$tmpfile;
#		symlink( $file, $tmpfile );
#	}
	my $fh;
	open( $fh, $file );
	my $doc = $PARSER->parse_fh( $fh, $basepath );
	close $fh;
#	if( defined $basepath )
#	{
#		unlink( $tmpfile );
#	}

	return $doc;
}

=item dispose( $node )

Unused

=cut

sub dispose
{
	my( $node ) = @_;

	if( !defined $node )
	{
		EPrints::abort( "attempt to dispose an undefined dom node" );
	}
}

=item $node = clone_node( $node [, $deep] )

Clone $node and return it, optionally descending into child nodes ($deep).

=cut

sub clone_node
{
	my( $node, $deep ) = @_;

	$deep ||= 0;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to clone_node" );
	}

	if( is_dom( $node, "DocumentFragment" ) )
	{
		my $doc = $node->getOwner;
		my $f = $doc->createDocumentFragment;
		return $f unless $deep;
		
		foreach my $c ( $node->getChildNodes )
		{
			$f->appendChild( $c->cloneNode( $deep ) );
		}
		return $f;
	}

	my $newnode = $node->cloneNode( $deep );

	return $newnode;
}

=item $node = clone_and_own( $node, $doc [, $deep] )

Clone $node and set its owner to $doc. Optionally clone child nodes with $deep.

=cut

sub clone_and_own
{
	my( $node, $doc, $deep ) = @_;
	$deep ||= 0;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to clone_and_own" );
	}

	if( is_dom( $node, "DocumentFragment" ) )
	{
		my $f = $doc->createDocumentFragment;
		return $f unless $deep;

		foreach my $c ( $node->getChildNodes )
		{
			$f->appendChild( $c->cloneNode( $deep ));
		}

		return $f;
	}

	my $newnode = $node->cloneNode( $deep );
#	$newnode->setOwnerDocument( $doc );

	return $newnode;
}

=item $string = document_to_string( $doc, $enc )

Return DOM document $doc as a string in encoding $enc.

=cut

sub document_to_string
{
	my( $doc, $enc ) = @_;

	$doc->setEncoding( $enc );

	return $doc->toString();
}

=item $doc = make_document()

Return a new, empty DOM document.

=cut

sub make_document
{
	# no params

	# leave ($version, $encoding) blank to avoid getting a declaration
	# *implicitly* utf8
	return XML::LibXML::Document->new();
}

__END__

=back
