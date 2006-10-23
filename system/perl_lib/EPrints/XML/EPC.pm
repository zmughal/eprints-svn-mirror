######################################################################
#
# EPrints::XML::EPC
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

B<EPrints::XML> - EPrints Control 

=head1 DESCRIPTION

Methods to process XML containing epc: - EPrints Control elements.

=over 4

=cut

package EPrints::XML::EPC;

use strict;


######################################################################
=pod

=item $xml = EPrints::XML::EPC::process( $xml, [%params] )

Using the given object and %params, collapse the elements <epc:phrase>
<epc:when>, <epc:if>, <epc:print> etc.

Also treats {foo} inside any attribute as if it were 
<epc:print expr="foo" />

=cut
######################################################################

sub process
{
	my( $node, %params ) = @_;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to epc process" );
	}
# cjg - Potential bug if: <ifset a><ifset b></></> and ifset a is disposed
# then ifset: b is processed it will crash.
	
	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->getTagName;
		$name =~ s/^epc://;

		# new style
		if( $name eq "if" )
		{
			return _process_if( $node, %params );
		}
		if( $name eq "choose" )
		{
			return _process_choose( $node, %params );
		}
		if( $name eq "print" )
		{
			return _process_print( $node, %params );
		}
		if( $name eq "phrase" )
		{
			return _process_phrase( $node, %params );
		}
		if( $name eq "pin" )
		{
			return _process_pin( $node, %params );
		}

	}

	my $collapsed = $params{session}->clone_for_me( $node );
	my $attrs = $collapsed->getAttributes;
	if( defined $attrs )
	{
		for( my $i = 0; $i<$attrs->getLength; ++$i )
		{
			my $attr = $attrs->item( $i );
			my $v = $attr->getValue;
			next unless( $v =~ m/\{/ );
			my $name = $attr->getName;
			my @r = EPrints::XML::EPC::split_script_attribute( $v, $name );
			my $newv='';
			for( my $i=0; $i<scalar @r; ++$i )
			{
				if( $i % 2 == 0 )
				{
					$newv.= $r[$i];
				}
				else
				{
					$newv.=EPrints::Script::print( $r[$i], \%params )->toString;
				}
			}
			$attr->setValue( $newv );
		}
	}

	$collapsed->appendChild( process_child_nodes( $node, %params ) );

	return $collapsed;
}

sub process_child_nodes
{
	my( $node, %params ) = @_;

	my $collapsed = $params{session}->make_doc_fragment;

	foreach my $child ( $node->getChildNodes )
	{
		$collapsed->appendChild(
			process( 
				$child,
				%params ) );			
	}

	return $collapsed;
}

sub _process_pin
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "name" ) )
	{
		EPrints::abort( "In ".$params{in}.": pin element with no ref attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $ref = $node->getAttribute( "name" );

	if( !defined $params{pindata}->{inserts}->{$ref} )
	{
		$params{session}->get_repository->log(
"missing parameter \"$ref\" when making phrase \"".$params{pindata}->{phraseid}."\"" );
		return $params{session}->make_text( "[pin missing: $ref]" );
	}

	my $retnode;	
	if( $params{pindata}->{used}->{$ref} )
	{
		$retnode = EPrints::XML::clone_node( 
				$params{pindata}->{inserts}->{$ref}, 1 );
	}
	else
	{
		$retnode = $params{pindata}->{inserts}->{$ref};
		$params{pindata}->{used}->{$ref} = 1;
	}

	if( $node->hasChildNodes )
	{	
		$retnode->appendChild( process_child_nodes( $node, %params ) );
	}

	return $retnode;
}


sub _process_phrase
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "ref" ) )
	{
		EPrints::abort( "In ".$params{in}.": phrase element with no ref attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $ref = $node->getAttribute( "ref" );

	my %pins = ();
	foreach my $param ( $node->getChildNodes )
	{
		next unless( $param->getTagName eq "param" );

		if( !$param->hasAttribute( "name" ) )
		{
			EPrints::abort( "In ".$params{in}.": param element in phrase with no name attribute.\n".substr( $param->toString, 0, 100 ) );
		}
		my $name = $param->getAttribute( "name" );
		
		$pins{$name} = process_child_nodes( $param, %params );
	}

	my $collapsed = $params{session}->html_phrase( $ref, %pins );

#	print $collapsed->toString."\n";

	return $collapsed;
}

sub _process_print
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "expr" ) )
	{
		EPrints::abort( "In ".$params{in}.": print element with no expr attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $expr = $node->getAttribute( "expr" );
	if( $expr =~ m/^\s*$/ )
	{
		EPrints::abort( "In ".$params{in}.": print element with empty expr attribute.\n".substr( $node->toString, 0, 100 ) );
	}

	my $opts = "";
	# apply any render opts
	if( $node->hasAttribute( "opts" ) )
	{
		$opts = $node->getAttribute( "opts" );
	}

	return EPrints::Script::print( $expr, \%params, $opts );
}	

sub _process_if
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "test" ) )
	{
		EPrints::abort( "In ".$params{in}.": if element with no test attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $test = $node->getAttribute( "test" );
	if( $test =~ m/^\s*$/ )
	{
		EPrints::abort( "In ".$params{in}.": if element with empty test attribute.\n".substr( $node->toString, 0, 100 ) );
	}

	my $result = EPrints::Script::execute( $test, \%params );
#	print STDERR  "IFTEST:::".$test." == $result\n";

	my $collapsed = $params{session}->make_doc_fragment;

	if( $result->[0] )
	{
		$collapsed->appendChild( process_child_nodes( $node, %params ) );
	}

	return $collapsed;
}

sub _process_choose
{
	my( $node, %params ) = @_;

	my $collapsed = $params{session}->make_doc_fragment;

	# when
	foreach my $child ( $node->getChildNodes )
	{
		next unless( EPrints::XML::is_dom( $child, "Element" ) );
		my $name = $child->getTagName;
		$name=~s/^ep://;
		$name=~s/^epc://;
		next unless $name eq "when";
		
		if( !$child->hasAttribute( "test" ) )
		{
			EPrints::abort( "In ".$params{in}.": when element with no test attribute.\n".substr( $child->toString, 0, 100 ) );
		}
		my $test = $child->getAttribute( "test" );
		if( $test =~ m/^\s*$/ )
		{
			EPrints::abort( "In ".$params{in}.": when element with empty test attribute.\n".substr( $child->toString, 0, 100 ) );
		}
		my $result = EPrints::Script::execute( $test, \%params );
#		print STDERR  "WHENTEST:::".$test." == $result\n";
		if( $result->[0] )
		{
			$collapsed->appendChild( process_child_nodes( $child, %params ) );
			return $collapsed;
		}
	}

	# otherwise
	foreach my $child ( $node->getChildNodes )
	{
		next unless( EPrints::XML::is_dom( $child, "Element" ) );
		my $name = $child->getTagName;
		$name=~s/^ep://;
		$name=~s/^epc://;
		next unless $name eq "otherwise";
		
		$collapsed->appendChild( process_child_nodes( $child, %params ) );
		return $collapsed;
	}

	# no otherwise...
	return $collapsed;
}




sub split_script_attribute
{
	my( $value, $what ) = @_;

	my @r = ();

	# outer loop when in text.
	my $depth = 0;
	OUTCODE: while( length( $value ) )
	{
		$value=~s/^([^{]*)//;
		push @r, $1;
		last unless $value=~s/^\{//;
		$depth = 1;
		my $c = ""; 
		INCODE: while( $depth>0 && length( $value ) )
		{
			if( $value=~s/^\{// )
			{
				++$depth;
				$c.="{";
				next INCODE;
			}
			if( $value=~s/^\}// )
			{
				--$depth;
				$c.="}" if( $depth>0 );
				next INCODE;
			}
			if( $value=~s/^('[^']*')// )
			{
				$c.=$1;
				next INCODE;
			}
			if( $value=~s/^("[^"]*")// )
			{
				$c.=$1;
				next INCODE;
			}
			unless( $value=~s/^([^"'\{\}]+)// )
			{
				print STDERR "Error parsing attribute $what near: $value\n";
				last OUTCODE;
			}
			$c.=$1;
		}
		push @r, $c;
	}

	return @r;
}



######################################################################
1;
######################################################################
=pod

=back

=cut
######################################################################

