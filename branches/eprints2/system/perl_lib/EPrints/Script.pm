#!/usr/bin/perl -w -I/opt/eprints3/perl_lib
######################################################################
#
# EPrints::Script
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

B<EPrints::Script> - Mini-scripting language for use in workflow and citations.

=head1 DESCRIPTION

This module processes simple eprints mini-scripts.

 my $result = execute( "$eprint.type = 'article'", { eprint=>$eprint } );

The syntax is

 $var := dataobj or string or datastructure
 "string" := string
 'string' := string
 !boolean := boolean 
 string = string := boolean
 string := string := boolean
 boolean or boolean := boolean
 boolean and boolean := boolean
 dataobj.property := string or datastructure
 dataobj.is_set( fieldname ) := boolean
 string.one_of( string, string, string... ) := boolean

=cut

package EPrints::Script;

use strict;

sub execute
{
	my( $code, $state ) = @_;

#print STDERR "Exec: $code\n";
#foreach( keys %{$state} ) { print STDERR "$_: ".$state->{$_}."\n"; }

	my @tokens = token( $code );

	my $tree = parse_expr( \@tokens );

#print STDERR debug( $tree );

	my $result = run( $tree, $state );

	return $result;
}

sub debug
{
	my( $tree, $depth ) = @_;

	$depth = $depth || 0;
	my $r = "";

	$r.= "  "x$depth;
	$r.= $tree->{id};
	if( defined $tree->{value} ) { $r.= " (".$tree->{value}.")"; }
	if( defined $tree->{pos} ) { $r.= "   #".$tree->{pos}; }
	$r.= "\n";
	foreach( @{$tree->{params}} )
	{
		$r.=debug( $_, $depth+1 );
	}
	return $r;
}

sub run
{
	my( $tree, $state ) = @_;

	if( !defined $tree->{id} ) 
	{
		runtime_error( "No ID in parse tree node", $tree->{code}, $tree->{pos} );
	}

	my $fn = "run_".$tree->{id};

	if( $tree->{id} eq "STRING" )
	{
		return [ $tree->{value}, "STRING" ];
	}

	if( $tree->{id} eq "VAR" )
	{
		my $r = $state->{$tree->{value}};
		if( !defined $r )
		{
			#runtime_error( "Unknown state variable ".$tree->{value}, $tree->{code}, $tree->{pos} );
		
			return [ 0, "BOOLEAN" ];
		}
		return [ $r ];
	}

	my @params;
	foreach( @{$tree->{params}} ) 
	{ 
		my $p = run( $_ , $state ); 
		push @params, $p;
	}
#print STDERR "Call: $fn( $tree, ".join(",",@params ).")\n";
	no strict "refs";
	my $result = &$fn( $tree, $state, @params );
	use strict "refs";

	return $result;
}

sub run_EQUALS
{
	my( $tree, $state, $left, $right ) = @_;
	
	return [ $left->[0] eq $right->[0], "BOOLEAN" ];
}

sub run_NOTEQUALS
{
	my( $tree, $state, $left, $right ) = @_;
	
	return [ $left->[0] ne $right->[0], "BOOLEAN" ];
}

sub run_NOT
{
	my( $tree, $state, $left ) = @_;

	return [ !$left->[0], "BOOLEAN" ];
}

sub run_AND
{
	my( $tree, $state, $left, $right ) = @_;
	
	return [ $left->[0] && $right->[0], "BOOLEAN" ];
}

sub run_OR
{
	my( $tree, $state, $left, $right ) = @_;
	
	return [ $left->[0] || $right->[0], "BOOLEAN" ];
}

sub run_PROPERTY
{
	my( $tree, $state, $objvar, $property ) = @_;

	if( !defined $tree )
	{
		runtime_error( "no parse tree", $tree->{code}, $tree->{pos} );
	}
	if( !defined $objvar->[0] )
	{
		runtime_error( "can't get a property from undef".$tree->{value}, $tree->{code}, $tree->{pos} );
	}
	my $ref = ref($objvar->[0]);
	if( $ref !~ m/::/ )
	{
		runtime_error( "can't get a property from a non-object: ".$tree->{value}, $tree->{code}, $tree->{pos} );
	}
	if( !$objvar->[0]->isa( "EPrints::DataObj" ) )
	{
		runtime_error( "can't get a property from non-dataobj: ".$tree->{value}, $tree->{code}, $tree->{pos} );
	}

	return [ 
		$objvar->[0]->get_value( $property->[0] ), 
		$objvar->[0]->get_dataset->get_field( $property->[0] ),
		$objvar->[0] ];
}

sub run_reverse
{
	my( $tree, $state, $string ) = @_;

	return [ reverse $string->[0], "STRING" ];
} 
	
sub run_is_set
{
	my( $tree, $state, $param ) = @_;

	return [ EPrints::Utils::is_set( $param->[0] ), "BOOLEAN" ];
} 

sub run_one_of
{
	my( $tree, $state, $string, @list ) = @_;

	if( !defined $string )
	{
		return [ 0, "BOOLEAN" ];
	}

	foreach( @list )
	{
		return [ 1, "BOOLEAN" ] if( $string eq $_ );
	}
	return [ 0, "BOOLEAN" ];
} 

sub run_as_item # maybe change later
{
	my( $tree, $state, $itemref ) = @_;

	if( !$itemref->[1]->isa( "EPrints::MetaField::Itemref" ) )
	{
		runtime_error( "can't call as_item on anything but a value of type itemref", $tree->{code}, $tree->{pos} );
	}

	my $object = $itemref->[1]->get_item( $state->{session}, $itemref->[0] );

	return [ $object ];
}

########################################################


sub token
{
	my( $code ) = @_;

	my @tokens = ();

	my $fullcode = $code;
	my $len = length $code;

	while( $code ne "" )
	{
		my $pos = $len-length $code;
		if( $code =~ s/^\s+// ) { next; }
		if( $code =~ s/^'([^']*)'// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'STRING',value=>$1 }; next; }
		if( $code =~ s/^"([^"]*)"// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'STRING',value=>$1 };  next;}
		if( $code =~ s/^\$([a-zA-Z0-9_-]+)// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'VAR',value=>$1 };  next;}
		if( $code =~ s/^\.([a-zA-Z0-9_-]+)// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'M_OR_P', value=>$1 };  next;}
		if( $code =~ s/^\(// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'OPEN_B' };  next;}
		if( $code =~ s/^\)// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'CLOSE_B' };  next;}
		if( $code =~ s/^=// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'EQUALS' };  next;}
		if( $code =~ s/^!=// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'NOTEQUALS' };  next;}
		if( $code =~ s/^,// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'COMMA' };  next;}
		if( $code =~ s/^!// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'NOT' };  next;}
		if( $code =~ s/^and// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'AND' };  next;}
		if( $code =~ s/^or// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'OR' };  next;}
		if( $code =~ s/^([a-zA-Z][a-zA-Z0-9_-]*)// ) { push @tokens, { code=>\$fullcode, pos=>$pos, id=>'FNAME', value=>$1 };  next;}
		parse_error( "Parse error", \$fullcode, $pos );
	}

	return @tokens;
}

sub parse_expr
{
	my( $tokens ) = @_;

	my $tree = parse_and_expr( $tokens );
	
	if( defined $tokens->[0] && $tokens->[0]->{id} eq "OR" )
	{
		my $subj = $tree;
		$tree = shift @$tokens;
		$tree->{params} = [ $subj, parse_expr( $tokens ) ];
	}

	return $tree;

}

sub parse_and_expr
{
	my( $tokens ) = @_;

	my $tree = parse_test_expr( $tokens );
	
	if( defined $tokens->[0] && $tokens->[0]->{id} eq "AND" )
	{
		my $subj = $tree;
		$tree = shift @$tokens;
		$tree->{params} = [ $subj, parse_and_expr( $tokens ) ];
	}

	return $tree;
}


sub parse_test_expr
{
	my( $tokens ) = @_;

	my $tree = parse_not_expr( $tokens );
	
	if( defined $tokens->[0] && ( $tokens->[0]->{id} eq "EQUALS" || $tokens->[0]->{id} eq "NOTEQUALS" ) )
	{
		my $subj =  $tree;
		$tree = shift @$tokens;
		$tree->{params} = [ $subj, parse_test_expr( $tokens ) ];
	}

	return $tree;
}

sub parse_not_expr
{
	my( $tokens ) = @_;
	
	if( defined $tokens->[0] && ( $tokens->[0]->{id} eq "NOT" ) )
	{
		my $tree = shift @$tokens;
		$tree->{params} = [ parse_not_expr( $tokens ) ];
		return $tree;
	}

	my $tree = parse_method_expr( $tokens );

	return $tree;
}

sub parse_method_expr
{
	my( $tokens ) = @_;

	my $tree = parse_b_expr( $tokens );

	while( defined $tokens->[0] && $tokens->[0]->{id} eq "M_OR_P" )
	{	
		my $subj = $tree;
		$tree = shift @$tokens;

		if( defined $tokens->[0] && $tokens->[0]->{id} eq "OPEN_B" )
		{
			shift @$tokens; #consume "("
			$tree->{id} = $tree->{value};
			$tree->{params} = [ $subj, @{parse_list( $tokens )} ]; # like ( $self, @params ) in Perl
			if( $tokens->[0]->{id} ne "CLOSE_B" )
			{
				parse_error( "expected closing method bracket", $tokens->[0]->{code}, $tokens->[0]->{pos} );
			}
			shift @$tokens; #consume ")"
		}
		else
		{
			$tree->{id} = "PROPERTY";
			$tree->{params} = [ $subj, { id=>"STRING", value=>$tree->{value}, code=>$tree->{code}, pos=>$tree->{pos} } ];
		}
	}

	return $tree;
}

sub parse_b_expr
{
	my( $tokens ) = @_;

	if( $tokens->[0]->{id} eq "OPEN_B" )
	{
		shift @$tokens; #consume "("
		my $tree = parse_expr( $tokens );
		if( $tokens->[0]->{id} ne "CLOSE_B" )
		{
			parse_error( "expected closing bracket", $tokens->[0]->{code}, $tokens->[0]->{pos} );
		}
		shift @$tokens; #consume ")"
		return $tree;
	}

	if( $tokens->[0]->{id} eq "STRING" )
	{
		return shift @$tokens;
	}

	if( $tokens->[0]->{id} eq "VAR" )
	{
		return shift @$tokens;
	}

	if( $tokens->[0]->{id} eq "FNAME" )
	{
		my $func = shift @$tokens;

		unless( defined $tokens->[0]->{id} && $tokens->[0]->{id} eq "OPEN_B" )
		{
			parse_error( "expected opening function bracket", $tokens->[0]->{code}, $tokens->[0]->{pos} );
		}
		shift @$tokens; #consume "("

		$func->{id} = $func->{value};
		$func->{params} = [ @{parse_list( $tokens )} ];

		if( $tokens->[0]->{id} ne "CLOSE_B" )
		{
			parse_error( "expected function method bracket", $tokens->[0]->{code}, $tokens->[0]->{pos} );
		}
		shift @$tokens; #consume ")"

		return $func;
	}


	parse_error( "expected '(', string, variable or function", $tokens->[0]->{code}, $tokens->[0]->{pos} );
}

sub parse_list
{
	my( $tokens ) = @_;

	return [] if( $tokens->[0]->{id} eq "CLOSE_B" );

	my $values = [];
	push @$values, parse_expr( $tokens );
	while (  $tokens->[0]->{id} eq "COMMA"  )
	{
		shift @$tokens; # consume COMMA;
		push @$values, parse_expr( $tokens );
	}
	
	return $values;
}

sub parse_error 
{ 
	my( $msg, $code, $pos ) = @_;
	error( $msg, $code, $pos );
}	
sub runtime_error 
{ 
	my( $msg, $code, $pos ) = @_;
	error( $msg, $code, $pos );
}

sub error
{
	my( $msg, $code, $pos ) = @_;
#print STDERR "msg:$msg\n";
#print STDERR "POS:$pos\n";
	my $error = "$msg at byte $pos\n";	
	$error .= ${$code}."\n";
	$error .= " "x$pos;
	$error .= "^ here";
	EPrints::abort( $error );
}

my $x=<<__;
EXPR = AND_EXPR + ("or + EXPR)?
AND_EXPR = OR_EXPR + ( "and" + AND_EXPR )?
OR_EXPR = TEST_EXPR + ( "or + OR_EXPR )?
TEST_EXPR = NOT_EXPR + ( ("="||"!=") + TEST_EXPR )?
NOT_EXPR = ("!")? + METH_EXPR
METH_EXPR = B_EXPR + METHOROP*
METHORPROP = M_OR_P || M_OR_P + "(" + LIST + ")"

B_EXPR = THING || "(" + EXPR + ")"
THING = VAR || STRING || FUNC

LIST = "" || EXPR + ( "," + EXPR )*
FUNC = FNAME + "(" + LIST + ")"

__



