######################################################################
#
# EPrints::XML
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

B<EPrints::XML> - XML Abstraction Module

=head1 DESCRIPTION

EPrints can use either XML::DOM or XML::GDOME modules to generate
and process XML. Some of the functionality of these modules differs
so this module abstracts such functionality so that all the module
specific code is in one place. 

=over 4

=cut

package EPrints::XML;

#use EPrints::SystemSettings;

use Unicode::String qw(utf8 latin1);
use Carp;

@EPrints::XML::COMPRESS_TAGS = qw/br hr img link input meta/;

my $gdome = ( 
	 defined $EPrints::SystemSettings::conf->{enable_gdome} &&
	 $EPrints::SystemSettings::conf->{enable_gdome} );

if( $gdome )
{
	require EPrints::XML::GDOME;
}
else
{
	require EPrints::XML::DOM; 
}

use strict;
use bytes;


######################################################################
=pod

=item $doc = EPrints::XML::parse_xml_string( $string );

Return a DOM document describing the XML string %string.

If we are using GDOME then it will create an XML::GDOME document
instead.

In the event of an error in the XML file, report to STDERR and
return undef.

=cut
######################################################################

# in DOM specific module
	

######################################################################
=pod

=item $doc = EPrints::XML::parse_xml( $file, $basepath, $no_expand )

Return a DOM document describing the XML file specified by $file.
With the optional root path for looking for the DTD of $basepath. If
$noexpand is true then entities will not be expanded.

If we are using GDOME then it will create an XML::GDOME document
instead.

In the event of an error in the XML file, report to STDERR and
return undef.

=cut
######################################################################

# in required dom module

	
######################################################################
=pod

=item $boolean = is_dom( $node, @nodestrings )

 return true if node is an object of type XML::DOM/GDOME::$nodestring
 where $nodestring is any value in @nodestrings.

 if $nodestring is not defined then return true if $node is any 
 XML::DOM/GDOME object.

=cut
######################################################################

sub is_dom
{
	my( $node, @nodestrings ) = @_;

	return 1 if( scalar @nodestrings == 0 );

	foreach( @nodestrings )
	{
		my $v = $EPrints::XML::PREFIX.$_;
		return 1 if( substr( ref($node), 0, length( $v ) ) eq $v );
	}

	return 0;
}


######################################################################
=pod

=item EPrints::XML::dispose( $node )

Dispose of this node if needed. Only XML::DOM nodes need to be
disposed as they have cyclic references. XML::GDOME nodes are C structs.

=cut
######################################################################

# in required dom module


######################################################################
=pod

=item $newnode = EPrints::XML::clone_node( $node, $deep )

Clone the given DOM node and return the new node. Always does a deep
copy.

This function does different things for XML::DOM & XML::GDOME
but the result should be the same.

=cut
######################################################################

# in required dom module

######################################################################
=pod

=item $newnode = EPrints::XML::clone_and_own( $doc, $node, $deep )

This function abstracts the different ways that XML::DOM and 
XML::GDOME allow objects to be moved between documents. 

It returns a clone of $node but belonging to the document $doc no
matter what document $node belongs to. 

If $deep is true then the clone will also clone all nodes belonging
to $node, recursively.

=cut
######################################################################

# in required dom module

######################################################################
=pod

=item $string = EPrints::XML::to_string( $node, [$enc], [$noxmlns] )

Return the given node (and its children) as a UTF8 encoded string.

$enc is only used when $node is a document.

If $stripxmlns is true then all xmlns attributes are removed. Handy
for making legal XHTML.

Papers over some cracks, specifically that XML::GDOME does not 
support toString on a DocumentFragment, and that XML::GDOME does
not insert a space before the / in tags with no children, which
confuses some browsers. Eg. <br/> vs <br />

=cut
######################################################################

sub to_string
{
	my( $node, $enc, $noxmlns ) = @_;

	$enc = 'utf-8' unless defined $enc;
	
	my @n = ();
	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $tagname = $node->getTagName;

		# lowercasing all tags screws up OAI.
		#$tagname = "\L$tagname";

		push @n, '<', $tagname;

		my $nnm = $node->getAttributes;
		my $done = {};
		foreach my $i ( 0..$nnm->getLength-1 )
		{
			my $attr = $nnm->item($i);
			my $name = $attr->getName;
			next if( $noxmlns && $name =~ m/^xmlns/ );
			next if( $done->{$attr->getName} );
			$done->{$attr->getName} = 1;
			# cjg Should probably escape these values.
			my $value = $attr->getValue;
			$value =~ s/&/&amp;/g;
			$value =~ s/"/&quot;/g;
			push @n, " ", $name."=\"".$value."\"";
		}

		#cjg This is bad. It makes nodes like <div /> if 
		# they are empty. Should make <div></div> like XML::DOM
		my $compress = 0;
		foreach my $ctag ( @EPrints::XML::COMPRESS_TAGS )
		{
			$compress = 1 if( $ctag eq $tagname );
		}
		if( $node->hasChildNodes )
		{
			$compress = 0;
		}

		if( $compress )
		{
			push @n," />";
		}
		else
		{
			push @n,">";
			foreach my $kid ( $node->getChildNodes )
			{
				push @n, to_string( $kid, $enc, $noxmlns );
			}
			push @n,"</",$tagname,">";
		}
	}
	elsif( is_dom( $node, "DocumentFragment" ) )
	{
		foreach my $kid ( $node->getChildNodes )
		{
			push @n, to_string( $kid, $enc, $noxmlns );
		}
	}
	elsif( EPrints::XML::is_dom( $node, "Document" ) )
	{
   		#my $docType  = $node->getDoctype();
	 	#my $elem     = $node->getDocumentElement();
		#push @n, $docType->toString, "\n";, to_string( $elem , $enc, $noxmlns);
		push @n, document_to_string( $node, $enc );
	}
	elsif( EPrints::XML::is_dom( 
			$node, 
			"Text", 
			"CDATASection", 
			"ProcessingInstruction",
			"EntityReference" ) )
	{
		push @n, $node->toString;
	}
	elsif( EPrints::XML::is_dom( $node, "Comment" ) )
	{
		push @n, "<!--",$node->getData, "-->"
	}
	else
	{
		print STDERR "EPrints::XML: Not sure how to turn node type ".$node->getNodeType."\ninto a string.\n";
	}

	return join '', @n;
}


######################################################################
=pod

=item $document = EPrints::XML::make_document()

Create and return an empty document.

=cut
######################################################################

# in required dom module

######################################################################
=pod

=item EPrints::XML::write_xml_file( $node, $filename )

Write the given XML node $node to file $filename.

=cut
######################################################################

sub write_xml_file
{
	my( $node, $filename ) = @_;

	unless( open( XMLFILE, ">$filename" ) )
	{
		EPrints::Config::abort( <<END );
Can't open to write to XML file: $filename
END
	}
	print XMLFILE EPrints::XML::to_string( $node, "utf-8" );
	close XMLFILE;
}

######################################################################
=pod

=item EPrints::XML::write_xhtml_file( $node, $filename )

Write the given XML node $node to file $filename with an XHTML doctype.

=cut
######################################################################

sub write_xhtml_file
{
	my( $node, $filename ) = @_;

	unless( open( XMLFILE, ">$filename" ) )
	{
		EPrints::Config::abort( <<END );
Can't open to write to XHTML file: $filename
END
		return;
	}
	print XMLFILE <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END

	print XMLFILE EPrints::XML::to_string( $node, "utf-8", 1 );

	close XMLFILE;
}

######################################################################
=pod

=item $elements = EPrints::XML::find_elements( $node, @list )

Return the first occurence of each of the elemnts named in the @list
within $node. Will not look inside named elements. Returns a reference
to a hash.

=cut
######################################################################

sub find_elements
{
	my( $node, @list ) = @_;

	my $found = {};

	foreach( @list ) { $found->{$_} = "no"; }

	&_find_elements2( $node, $found );

	foreach( keys %{$found} ) 
	{
		delete $found->{$_} if $found->{$_} eq "no";
	}
	return $found;
}

sub _find_elements2
{
	my( $node, $found ) = @_;
	if( is_dom( $node, "Element" ) )
	{
		my $name = $node->getTagName;
		$name =~ s/^ep://;
		if( defined $found->{$name} )
		{
			if( $found->{$name} eq "no" )
			{
				$found->{$name} = $node;
			}
			return;
		}
	}
	if( $node->hasChildNodes )
	{
		foreach my $c ( $node->getChildNodes )
		{
			_find_elements2( $c, $found );
		}
	}
}

######################################################################
=pod

=item EPrints::XML::tidy( $domtree, { collapse=>['element','element'...] }, [$indent] )

Neatly indent the DOM tree. 

Note that this should not be done to XHTML as the differenct between
white space and no white space does matter sometimes.

This method modifies the tree it is given. Possibly there should be
a version which returns a new version without modifying the tree.

Indent is the number of levels to ident by.

=cut
######################################################################

sub tidy 
{
	my( $node, $opts, $indent ) = @_;

	my $name = $node->getNodeName;
	if( defined $opts->{collapse} )
	{
		foreach my $col_id ( @{$opts->{collapse}} )
		{
			return if $col_id eq $name;
		}
	}

	# tidys the node in it's own document so we don't require $session
	my $doc = $node->getOwnerDocument;

	$indent = $indent || 0;

	if( !defined $node )
	{
		EPrints::abort( "Attempt to call EPrints::XML::tidy on a undefined node." );
	}

	my $state = "empty";
	my $text = "";
	foreach my $c ( $node->getChildNodes )
	{
		unless( EPrints::XML::is_dom( $c, "Text", "CDATASection", "EntityReference" ) ) {
			$state = "complex";
			last;
		}

		unless( EPrints::XML::is_dom( $c, "Text" ) ) { $state = "text"; }
		next if $state eq "text";
		$text.=$c->nodeValue;
		$state = "simpletext";
	}
	if( $state eq "simpletext" )
	{
		$text =~ s/^\s*//;
		$text =~ s/\s*$//;
		foreach my $c ( $node->getChildNodes )
		{
			$node->removeChild( $c );
		}
		$node->appendChild( $doc->createTextNode( $text ) );
		return;
	}
	return if $state eq "text";
	return if $state eq "empty";
	$text = "";
	my $replacement = $doc->createDocumentFragment;
	$replacement->appendChild( $doc->createTextNode( "\n" ) );
	foreach my $c ( $node->getChildNodes )
	{
		tidy($c,$opts,$indent+1);
		$node->removeChild( $c );
		if( EPrints::XML::is_dom( $c, "Text" ) )
		{
			$text.= $c->nodeValue;
			next;
		}
		$text =~ s/^\s*//;	
		$text =~ s/\s*$//;	
		if( $text ne "" )
		{
			$replacement->appendChild( $doc->createTextNode( "  "x($indent+1) ) );
			$replacement->appendChild( $doc->createTextNode( $text ) );
			$replacement->appendChild( $doc->createTextNode( "\n" ) );
			$text = "";
		}
		$replacement->appendChild( $doc->createTextNode( "  "x($indent+1) ) );
		$replacement->appendChild( $c );
		$replacement->appendChild( $doc->createTextNode( "\n" ) );
	}
	$text =~ s/^\s*//;	
	$text =~ s/\s*$//;	
	if( $text ne "" )
	{
		$replacement->appendChild( $doc->createTextNode( "  "x($indent+1) ) );
		$replacement->appendChild( $doc->createTextNode( $text ) );
		$replacement->appendChild( $doc->createTextNode( "\n" ) );
	}
	$replacement->appendChild( $doc->createTextNode( "  "x($indent) ) );
	$node->appendChild( $replacement );
}


######################################################################
=pod

=item $namespace = EPrints::XML::namespace( $thing, $version )

Return the namespace for the given version of the eprints xml.

=cut
######################################################################

sub namespace
{
	my( $thing, $version ) = @_;

	if( $thing eq "data" )
	{
               	return "http://eprints.org/ep2/data/2.0" if( $version eq "2" );
                return "http://eprints.org/ep2/data" if( $version eq "1" );
		return undef;
	}

	return undef;
}

######################################################################
# Debug code, don't use!
######################################################################

sub debug_xml
{
	my( $node, $depth ) = @_;

	#push @{$x}, $node;
	print STDERR ">"."  "x$depth;
	print STDERR "DEBUG(".ref($node).")\n";
	if( is_dom( $node, "Document", "Element" ) )
	{
		foreach my $c ( $node->getChildNodes )
		{
			debug_xml( $c, $depth+1 );
		}
	}

	print STDERR "  "x$depth;
	print STDERR "(".ref($node).")\n";
	print STDERR "  "x$depth;
	print STDERR $node->toString."\n";
	print STDERR "<\n";
}

######################################################################
1;
######################################################################
=pod

=back

=cut
######################################################################











__DATA__

if( $gdome )
{
	require XML::GDOME;
}
else
{
	require XML::DOM; 
	# DOM runs really slowly if it checks all it's data is
	# valid...
	$XML::DOM::SafeMode = 0;
	XML::DOM::setTagCompression( \&_xmldom_tag_compression );
}

$EPrints::XML::PREFIX = "XML::GDOME::";
$EPrints::XML::PREFIX = "XML::DOM::";

sub parse_xml_string
{
	my( $string ) = @_;

	if( $gdome )
	{
		my $doc;
		# For some reason the GDOME constants give an error,
		# using their values instead (could cause a problem if
		# they change in a subsequent version).

		my $opts = 8; #GDOME_LOAD_COMPLETE_ATTRS
		#unless( $no_expand )
		#{
			#$opts += 4; #GDOME_LOAD_SUBSTITUTE_ENTITIES
		#}
		$doc = XML::GDOME->createDocFromString( $string, $opts );
	}
	else
	{
		my $doc;
		my( %c ) = (
			Namespaces => 1,
			ParseParamEnt => 1,
			ErrorContext => 2,
			NoLWP => 1 );
		$c{ParseParamEnt} = 0;
		my $parser =  XML::DOM::Parser->new( %c );

		$doc = eval { $parser->parse( $string ); };
		if( $@ )
		{
			my $err = $@;
			$err =~ s# at /.*##;
			$err =~ s#\sXML::Parser::Expat.*$##s;
			print STDERR "Error parsing XML $string";
			return;
		}
		return $doc;
	}
}

sub parse_xml
{
	my( $file, $basepath, $no_expand ) = @_;

	unless( -r $file )
	{
		EPrints::Config::abort( "Can't read XML file: '$file'" );
	}

	my $doc;
	if( $gdome )
	{
		my $tmpfile = $file;
		if( defined $basepath )
		{	
			$tmpfile =~ s#/#_#g;
			$tmpfile = $basepath."/".$tmpfile;
			symlink( $file, $tmpfile );
		}

		# For some reason the GDOME constants give an error,
		# using their values instead (could cause a problem if
		# they change in a subsequent version).

		my $opts = 8; #GDOME_LOAD_COMPLETE_ATTRS
		unless( $no_expand )
		{
			$opts += 4; #GDOME_LOAD_SUBSTITUTE_ENTITIES
		}
		$doc = XML::GDOME->createDocFromURI( $tmpfile, $opts );
		if( defined $basepath )
		{
			unlink( $tmpfile );
		}
	}
	else
	{

		my( %c ) = (
			Base => $basepath,
			Namespaces => 1,
			ParseParamEnt => 1,
			ErrorContext => 2,
			NoLWP => 1 );
		if( $no_expand )
		{
			$c{ParseParamEnt} = 0;
		}
		my $parser =  XML::DOM::Parser->new( %c );

		unless( open( XML, $file ) )
		{
			print STDERR "Error opening XML file: $file\n";
			return;
		}
		$doc = eval { $parser->parse( *XML ); };
		close XML;
		if( $@ )
		{
			my $err = $@;
			$err =~ s# at /.*##;
			print STDERR "Error parsing XML $file ($err)";
			return;
		}
	}

	return $doc;
}

sub dispose
{
	my( $node ) = @_;

	if( !defined $node )
	{
		EPrints::abort "attempt to dispose an undefined dom node";
	}

	if( !$gdome )
	{
		$node->dispose;
	}
}


sub clone_node
{
	my( $node, $deep ) = @_;

	if( !defined $node )
	{
		EPrints::abort "no node passed to clone_node";
	}

	# XML::DOM is easy
	if( !$gdome )
	{
		return $node->cloneNode( $deep );
	}

	if( is_dom( $node, "DocumentFragment" ) )
	{
		my $doc = $node->getOwnerDocument;
		my $f = $doc->createDocumentFragment;
		return $f unless $deep;
		
		foreach my $c ( $node->getChildNodes )
		{
			$f->appendChild( $c->cloneNode( 1 ) );
		}
		return $f;
	}
	my $doc = $node->getOwnerDocument;
	my $newnode = $node->cloneNode( 1 );
	$doc->importNode( $newnode, 1 );
	return $newnode;

}

sub clone_and_own
{
	my( $node, $doc, $deep ) = @_;

	my $newnode;
	$deep = 0 unless defined $deep;

	if( $gdome )
	{
		# XML::GDOME
		if( is_dom( $node, "DocumentFragment" ) )
		{
			$newnode = $doc->createDocumentFragment;

			if( $deep )
			{	
				foreach my $c ( $node->getChildNodes )
				{
					$newnode->appendChild( 
						$doc->importNode( $c, 1 ) );
				}
			}
		}
		else
		{
			$newnode = $doc->importNode( $node, $deep );
			# bug in importNode NOT being deep that it does
			# not appear to clone attributes, so lets work
			# around it!

			my $attrs = $node->getAttributes;
			if( $attrs )
			{
				for my $i ( 0..$attrs->getLength-1 )
				{
					my $attr = $attrs->item( $i );
					my $k = $attr->getName;
					my $v = $attr->getValue;
					$newnode->setAttribute( $k, $v );
				}
			}
		}

	}
	else
	{
		# XML::DOM 
		$newnode = $node->cloneNode( $deep );
		$newnode->setOwnerDocument( $doc );
	}
	return $newnode;
}

sub document_to_string
{
	my( $doc, $enc ) = @_;

	if( $gdome )
	{
		return $doc->toStringEnc( $enc );
	}
	else
	{
		return $doc->toString;
	}
}

sub make_document
{
	# no params

	# XML::DOM
	if( !$gdome )
	{
		my $doc = new XML::DOM::Document();
	
		return $doc;
	}
	
	# XML::GDOME
	my $doc = XML::GDOME->createDocument( undef, "thing", undef );
	$doc->removeChild( $doc->getFirstChild );

	return $doc;
}
