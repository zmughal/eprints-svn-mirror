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

	my @tokens = token( $code );

	my $tree = parse_expr( \@tokens );

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
		EPrints::abort( "No ID in parse tree node.");
	}

	my $fn = "run_".$tree->{id};

	if( $tree->{id} eq "STRING" )
	{
		return $tree->{value};
	}

	if( $tree->{id} eq "VAR" )
	{
		my $r = $state->{$tree->{value}};
		if( !defined $r )
		{
			EPrints::abort( "Unknown state variable ".$tree->{value} );
		}
		return $r;
	}

	my @params;
	foreach( @{$tree->{params}} ) 
	{ 
		my $p = run( $_ , $state ); 
		push @params, $p;
	}

	no strict "refs";
	my $result = &$fn( $tree, @params );
	use strict "refs";

	debug( $tree );

	return $result;
}

sub run_EQUALS
{
	my( $tree, $left, $right ) = @_;
	
	return( $left eq $right );
}

sub run_NOTEQUALS
{
	my( $tree, $left, $right ) = @_;
	
	return( $left ne $right );
}

sub run_NOT
{
	my( $tree, $left ) = @_;

	return !$left;
}

sub run_AND
{
	my( $tree, $left, $right ) = @_;
	
	return( $left && $right );
}

sub run_OR
{
	my( $tree, $left, $right ) = @_;
	
	return( $left || $right );
}

sub run_PROPERTY
{
	my( $tree, $obj, $property ) = @_;

	if( !defined $obj )
	{
		EPrints::abort( "can't get a property from undef" );
	}
	if( !$obj->isa( "EPrints::DataObj" ) )
	{
		EPrints::abort( "can't get a property from a non-dataobj ($obj)" );
	}

	return $obj->get_value( $property );
}

sub run_reverse
{
	my( $tree, $string ) = @_;

	return reverse $string;
} 
	
sub run_is_set
{
	my( $tree, $obj, $property ) = @_;

	if( !defined $obj )
	{
		EPrints::abort( "can't get a property from undef" );
	}

	if( !$obj->isa( "EPrints::DataObj" ) )
	{
		EPrints::abort( "can't get a property from a non-dataobj" );
	}

	return $obj->is_set( $property );
} 

sub run_one_of
{
	my( $tree, $string, @list ) = @_;

	foreach( @list )
	{
		return 1 if( $string eq $_ );
	}
	return 0;
} 




sub token
{
	my( $code ) = @_;

	my @tokens = ();

	while( $code ne "" )
	{
		if( $code =~ s/^\s+// ) { next; }
		if( $code =~ s/^'([^']*)'// ) { push @tokens, { near=>$code, id=>'STRING',value=>$1 }; next; }
		if( $code =~ s/^"([^"]*)"// ) { push @tokens, { near=>$code, id=>'STRING',value=>$1 };  next;}
		if( $code =~ s/^\$([a-zA-Z0-9_-]+)// ) { push @tokens, { near=>$code, id=>'VAR',value=>$1 };  next;}
		if( $code =~ s/^\.([a-zA-Z0-9_-]+)// ) { push @tokens, { near=>$code, id=>'M_OR_P', value=>$1 };  next;}
		if( $code =~ s/^\(// ) { push @tokens, { near=>$code, id=>'OPEN_B' };  next;}
		if( $code =~ s/^\)// ) { push @tokens, { near=>$code, id=>'CLOSE_B' };  next;}
		if( $code =~ s/^=// ) { push @tokens, { near=>$code, id=>'EQUALS' };  next;}
		if( $code =~ s/^!=// ) { push @tokens, { near=>$code, id=>'NOTEQUALS' };  next;}
		if( $code =~ s/^,// ) { push @tokens, { near=>$code, id=>'COMMA' };  next;}
		if( $code =~ s/^!// ) { push @tokens, { near=>$code, id=>'NOT' };  next;}
		if( $code =~ s/^and// ) { push @tokens, { near=>$code, id=>'AND' };  next;}
		if( $code =~ s/^or// ) { push @tokens, { near=>$code, id=>'OR' };  next;}
		die "Unknown code: $code\n";
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

	my $tree = parse_func_expr( $tokens );

	return $tree;
}

sub parse_func_expr
{
	my( $tokens ) = @_;

	my $tree = parse_b_expr( $tokens );

	while( defined $tokens->[0] && $tokens->[0]->{id} eq "M_OR_P" )
	{	
		my $subj = $tree;
		$tree = shift @$tokens;
		if( defined $tokens->[0]->{id} && $tokens->[0]->{id} eq "OPEN_B" )
		{
			shift @$tokens; #consume "("
			$tree->{id} = $tree->{value};
			$tree->{params} = [ $subj, @{parse_list( $tokens )} ];
			if( $tokens->[0]->{id} ne "CLOSE_B" )
			{
				EPrints::abort( "expected closing method bracket near ".$tokens->[0]->{near} );
			}
			shift @$tokens; #consume ")"
		}
		else
		{
			$tree->{id} = "PROPERTY";
			$tree->{params} = [ $subj, { id=>"STRING", value=>$tree->{value} } ];
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
			die "expected closing bracket";
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

	die "Expected '(' or string or variable";
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
	

my $x=<<__;
EXPR = AND_EXPR + ("or + EXPR)?
AND_EXPR = OR_EXPR + ( "and" + AND_EXPR )?
OR_EXPR = TEST_EXPR + ( "or + OR_EXPR )?
TEST_EXPR = NOT_EXPR + ( ("="||"!=") + TEST_EXPR )?
NOT_EXPR = ("!")? + FUNC_EXPR
FUNC_EXPR = B_EXPR + FUNCOROP*
FUNCORPROP = M_OR_P || M_OR_P + "(" + LIST + ")"

B_EXPR = THING || "(" + EXPR + ")"
THING = VAR || STRING

LIST = "" || EXPR + ( "," + EXPR )*

__



