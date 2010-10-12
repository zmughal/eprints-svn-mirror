######################################################################
#
# EPrints::XML::DOM
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

B<EPrints::XML::DOM> - DOM subs for EPrints::XML

=head1 DESCRIPTION

This module is not a package, it's a set of subroutines to be
loaded into EPrints::XML namespace if we're using XML::DOM

=over 4

=cut

require XML::DOM; 

# DOM runs really slowly if it checks all it's data is
# valid...
$XML::DOM::SafeMode = 0;

XML::DOM::setTagCompression( \&_xmldom_tag_compression );

$EPrints::XML::PREFIX = "XML::DOM::";

######################################################################
# 
# EPrints::XML::_xmldom_tag_compression( $tag, $elem )
#
# Only used by the DOM module.
#
######################################################################

sub _xmldom_tag_compression
{
	my ($tag, $elem) = @_;
	
	# Print empty br, hr and img tags like this: <br />
	foreach my $ctag ( @EPrints::XML::COMPRESS_TAGS )
	{
		return 2 if( $ctag eq $tag );
	}

	# Print other empty tags like this: <empty></empty>
	return 1;
}

sub parse_xml_string
{
	my( $string ) = @_;

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

sub parse_xml
{
	my( $file, $basepath, $no_expand ) = @_;

	unless( -r $file )
	{
		EPrints::Config::abort( "Can't read XML file: '$file'" );
	}

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
	my $doc = eval { $parser->parse( *XML ); };
	close XML;

	if( $@ )
	{
		my $err = $@;
		$err =~ s# at /.*##;
		print STDERR "Error parsing XML $file ($err)";
		return;
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

	$node->dispose;
}


sub clone_node
{
	my( $node, $deep ) = @_;

	if( !defined $node )
	{
		EPrints::abort "no node passed to clone_node";
	}

	return $node->cloneNode( $deep );
}

sub clone_and_own
{
	my( $node, $doc, $deep ) = @_;

	my $newnode;
	$deep = 0 unless defined $deep;

	# XML::DOM 
	$newnode = $node->cloneNode( $deep );
	$newnode->setOwnerDocument( $doc );

	return $newnode;
}

# ignores encoding!
sub document_to_string
{
	my( $doc, $enc ) = @_;

	return $doc->toString;
}

sub make_document
{
	# no params

	my $doc = new XML::DOM::Document();

	return $doc;
}