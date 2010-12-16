######################################################################
#
# EPrints::XML::GDOME
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

B<EPrints::XML::GDOME> - GDOME subs for EPrints::XML

=head1 DESCRIPTION

This module is not a package, it's a set of subroutines to be
loaded into EPrints::XML namespace if we're using XML::GDOME

=over 4

=cut

require XML::GDOME;

$EPrints::XML::PREFIX = "XML::GDOME::";

sub parse_xml_string
{
	my( $string ) = @_;

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

	return $doc;
}

sub parse_xml
{
	my( $file, $basepath, $no_expand ) = @_;

	unless( -r $file )
	{
		EPrints::Config::abort( "Can't read XML file: '$file'" );
	}

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
	my $doc = XML::GDOME->createDocFromURI( $tmpfile, $opts );
	if( defined $basepath )
	{
		unlink( $tmpfile );
	}
	return $doc;
}

sub dispose
{
	my( $node ) = @_;

	if( !defined $node )
	{
		EPrints::abort( "attempt to dispose an undefined dom node" );
	}
}


sub clone_node
{
	my( $node, $deep ) = @_;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to clone_node" );
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

	if( !defined $node )
	{
		EPrints::abort( "no node passed to clone_and_own" );
	}

	my $newnode;
	$deep = 0 unless defined $deep;

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

	return $newnode;
}

sub document_to_string
{
	my( $doc, $enc ) = @_;

	return $doc->toStringEnc( $enc );
}

sub make_document
{
	# no params

	my $doc = XML::GDOME->createDocument( undef, "thing", undef );
	$doc->removeChild( $doc->getFirstChild );

	return $doc;
}