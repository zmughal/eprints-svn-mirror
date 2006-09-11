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

	my $compiled = EPrints::Script::Compiler->new()->compile( $code, $state->{in} );

#print STDERR $compiled->debug;

	return $compiled->run( $state );
}

sub error
{
	my( $msg, $in, $pos, $code ) = @_;
#print STDERR "msg:$msg\n";
#print STDERR "POS:$pos\n";
	
	my $error = "Script in ".(defined $in?$in:"unknown").": ".$msg;
	if( defined $pos ) { $error.= " at character ".$pos; }
	if( defined $code ) { $error .= "\n".$code; }
	if( defined $code && defined $pos ) {  $error .=  "\n".(" "x$pos). "^ here"; }
	EPrints::abort( $error );
}

package EPrints::Script::Compiled;

sub debug
{
	my( $self, $depth ) = @_;

	$depth = $depth || 0;
	my $r = "";

	$r.= "  "x$depth;
	$r.= $self->{id};
	if( defined $self->{value} ) { $r.= " (".$self->{value}.")"; }
	if( defined $self->{pos} ) { $r.= "   #".$self->{pos}; }
	$r.= "\n";
	foreach( @{$self->{params}} )
	{
		$r.=debug( $_, $depth+1 );
	}
	return $r;
}

sub run
{
	my( $self, $state ) = @_;

	if( !defined $self->{id} ) 
	{
		$self->runtime_error( "No ID in tree node" );
	}

	if( $self->{id} eq "STRING" )
	{
		return [ $self->{value}, "STRING" ];
	}

	if( $self->{id} eq "VAR" )
	{
		my $r = $state->{$self->{value}};
		if( !defined $r )
		{
			#runtime_error( "Unknown state variable ".$self->{value} );
		
			return [ 0, "BOOLEAN" ];
		}
		return [ $r ];
	}

	my @params;
	foreach my $param ( @{$self->{params}} ) 
	{ 
		my $p = $param->run( $state ); 
		push @params, $p;
	}

	my $fn = "run_".$self->{id};

	no strict "refs";
	my $result = $self->$fn( $state, @params );
	use strict "refs";

	return $result;
}

sub runtime_error 
{ 
	my( $self, $msg ) = @_;

	error( $msg, $self->{in}, $self->{pos}, $self->{code} )
}

sub run_EQUALS
{
	my( $self, $state, $left, $right ) = @_;
	
	return [ $left->[0] eq $right->[0], "BOOLEAN" ];
}

sub run_NOTEQUALS
{
	my( $self, $state, $left, $right ) = @_;
	
	return [ $left->[0] ne $right->[0], "BOOLEAN" ];
}

sub run_NOT
{
	my( $self, $state, $left ) = @_;

	return [ !$left->[0], "BOOLEAN" ];
}

sub run_AND
{
	my( $self, $state, $left, $right ) = @_;
	
	return [ $left->[0] && $right->[0], "BOOLEAN" ];
}

sub run_OR
{
	my( $self, $state, $left, $right ) = @_;
	
	return [ $left->[0] || $right->[0], "BOOLEAN" ];
}

sub run_PROPERTY
{
	my( $self, $state, $objvar ) = @_;

	if( !defined $objvar->[0] )
	{
		$self->runtime_error( "can't get a property from undef".$self->{value} );
	}
	my $ref = ref($objvar->[0]);
	if( $ref !~ m/::/ )
	{
		$self->runtime_error( "can't get a property from a non-object: ".$self->{value} );
	}
	if( !$objvar->[0]->isa( "EPrints::DataObj" ) )
	{
		$self->runtime_error( "can't get a property from non-dataobj: ".$self->{value} );
	}

	return [ 
		$objvar->[0]->get_value( $self->{value} ),
		$objvar->[0]->get_dataset->get_field( $self->{value} ),
		$objvar->[0] ];
}

sub run_MAIN_ITEM_PROPERTY
{
	my( $self, $state ) = @_;

	return run_PROPERTY( $self, $state, [$state->{item}] );
}

sub run_reverse
{
	my( $self, $state, $string ) = @_;

	return [ reverse $string->[0], "STRING" ];
} 
	
sub run_is_set
{
	my( $self, $state, $param ) = @_;

	return [ EPrints::Utils::is_set( $param->[0] ), "BOOLEAN" ];
} 

sub run_one_of
{
	my( $self, $state, $string, @list ) = @_;

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
	my( $self, $state, $itemref ) = @_;

	if( !$itemref->[1]->isa( "EPrints::MetaField::Itemref" ) )
	{
		$self->runtime_error( "can't call as_item on anything but a value of type itemref" );
	}

	my $object = $itemref->[1]->get_item( $state->{session}, $itemref->[0] );

	return [ $object ];
}

########################################################


package EPrints::Script::Compiler;

use strict;

sub new
{
	my( $class ) = @_;

	return bless {}, $class;
}

sub compile
{
	my( $self, $code, $in ) = @_;

	$in = "unknown" unless defined $in;

	$self->{code} = $code;
	$self->{in} = $in;	
	$self->{tokens} = [];

	$self->tokenise;
	
	if( scalar @{$self->{tokens}} == 0 ) 
	{
		#$state->{session}->get_repository->log( "Script in: ".$state->{in}.": Empty script." );
		return [ 0, "BOOLEAN" ];
	}
		
	return $self->compile_expr;
}


sub tokenise
{
	my( $self ) = @_;

	my @tokens;

	my $code = $self->{code};
	my $len = length $code;

	while( $code ne "" )
	{
		my $pos = $len-length $code;
		if( $code =~ s/^\s+// ) { next; }
		if( $code =~ s/^'([^']*)'// ) { push @tokens, { pos=>$pos, id=>'STRING',value=>$1 }; next; }
		if( $code =~ s/^"([^"]*)"// ) { push @tokens, { pos=>$pos, id=>'STRING',value=>$1 };  next;}
		if( $code =~ s/^\$// ) { push @tokens, { pos=>$pos, id=>'DOLLAR',value=>$1 };  next;}
		if( $code =~ s/^\.// ) { push @tokens, { pos=>$pos, id=>'DOT', value=>$1 };  next;}
		if( $code =~ s/^\(// ) { push @tokens, { pos=>$pos, id=>'OPEN_B' };  next;}
		if( $code =~ s/^\)// ) { push @tokens, { pos=>$pos, id=>'CLOSE_B' };  next;}
		if( $code =~ s/^\{// ) { push @tokens, { pos=>$pos, id=>'OPEN_C' };  next;}
		if( $code =~ s/^\}// ) { push @tokens, { pos=>$pos, id=>'CLOSE_C' };  next;}
		if( $code =~ s/^=// ) { push @tokens, { pos=>$pos, id=>'EQUALS' };  next;}
		if( $code =~ s/^!=// ) { push @tokens, { pos=>$pos, id=>'NOTEQUALS' };  next;}
		if( $code =~ s/^,// ) { push @tokens, { pos=>$pos, id=>'COMMA' };  next;}
		if( $code =~ s/^!// ) { push @tokens, { pos=>$pos, id=>'NOT' };  next;}
		if( $code =~ s/^and// ) { push @tokens, { pos=>$pos, id=>'AND' };  next;}
		if( $code =~ s/^or// ) { push @tokens, { pos=>$pos, id=>'OR' };  next;}
		if( $code =~ s/^([a-zA-Z][a-zA-Z0-9_-]*)// ) { push @tokens, { pos=>$pos, id=>'IDENT', value=>$1 };  next;}
		$self->compile_error( "Parse error" );
	}

	$self->{tokens} = [];
	foreach my $token ( @tokens )
	{	
		$token->{in} = $self->{in};
		$token->{code} = $self->{code};
		push @{$self->{tokens}}, bless $token, "EPrints::Script::Compiled";
	}

}

sub give_me
{
	my( $self, $want, $err_msg ) = @_;

	my $token = shift @{$self->{tokens}}; # pull off list

	if( !defined $token || $token->{id} ne $want )
	{
		if( !defined $err_msg )
		{
			$err_msg = "Expected $want";
		}	
		if( !defined $token )
		{
			$err_msg.=" (found end of script)";
		}
		else
		{
			$err_msg.=" (found ".$token->{id}.")";
		}
		$self->compile_error( $err_msg );
	}

	return $token;
}

sub next_is
{
	my( $self, $type ) = @_;

	return 0 if !defined $self->{tokens}->[0];

	return( $self->{tokens}->[0]->{id} eq $type );
}

sub compile_expr
{
	my( $self ) = @_;

	my $tree = $self->compile_and_expr;
	
	if( $self->next_is( "OR" ) )
	{
		my $left = $tree;
		my $or = $self->give_me( "OR" );
		my $right = $self->compile_expr;	
		$or->{params} = [ $left, $right ];
		return $or;
	}

	return $tree;

}

sub compile_and_expr
{
	my( $self ) = @_;

	my $tree = $self->compile_test_expr;
	
	if( $self->next_is( "AND" ) )
	{
		my $left = $tree;
		my $and = $self->give_me( "AND" );
		my $right = $self->compile_and_expr;	
		$and->{params} = [ $left, $right ];
		return $and;
	}

	return $tree;
}


sub compile_test_expr
{
	my( $self ) = @_;

	my $tree = $self->compile_not_expr;
	
	if( $self->next_is( "EQUALS" ) )
	{
		my $left = $tree;
		my $eq = $self->give_me( "EQUALS" );
		my $right = $self->compile_test_expr;	
		$eq->{params} = [ $left, $right ];
		return $eq;
	}
	if( $self->next_is( "NOTEQUALS" ) )
	{
		my $left = $tree;
		my $neq = $self->give_me( "NOTEQUALS" );
		my $right = $self->compile_test_expr;	
		$neq->{params} = [ $left, $right ];
		return $neq;
	}

	return $tree;
}

sub compile_not_expr
{
	my( $self ) = @_;

	if( $self->next_is( "NOT" ) )	
	{
		my $not = $self->give_me( "NOT" );
		my $param = $self->compile_not_expr;
		$not->{params} = [ $param ];
		return $not;
	}

	return $self->compile_method_expr;
}

# METH_EXPR = B_EXPR + METH_OR_PROP*
# METH_OR_PROP = "{" + ident + "}"		# property	
#              | "." + ident + "(" + LIST + ")"	# method

sub compile_method_expr
{
	my( $self ) = @_;

	my $tree = $self->compile_b_expr;

	while( $self->next_is( "DOT" ) || $self->next_is( "OPEN_C" ) )
	{	
		# method.
		if( $self->next_is( "DOT" ) )
		{
			$self->give_me( "DOT" );
			
			my $method_on = $tree;

			$tree = $self->give_me( "IDENT", "expected method name after dot" );
			
			$self->give_me( "OPEN_B", "expected opening method bracket" ); 

			$tree->{id} = $tree->{value};
			$tree->{params} = [ $method_on, @{$self->compile_list} ]; # like ( $self, @params ) in Perl

			$self->give_me( "CLOSE_B", "expected closing method bracket" ); 

			next;
		}

		# property.
		if( $self->next_is( "OPEN_C" ) )
		{
			$self->give_me( "OPEN_C", "expected opening curly bracket" ); 
			
			my $prop_on = $tree;

			$tree = $self->give_me( "IDENT", "expected property name after {" );

			$tree->{id} = "PROPERTY";
			$tree->{params} = [ $prop_on ];

			$self->give_me( "CLOSE_C", "expected closing curly bracket" ); 

			next;
		}

		$self->compile_error( "odd error. this code should be unreachable" );
	}

	return $tree;
}

sub compile_b_expr
{
	my( $self ) = @_;

	if( !defined $self->{tokens}->[0] )
	{
		$self->compile_error( "expected '(', string, variable or function" );
	}

	if( $self->next_is( "OPEN_B" ) )
	{
		$self->give_me( "OPEN_B", "expected opening bracket" ); 
		my $tree = $self->compile_expr;
		$self->give_me( "CLOSE_B", "expected closing bracket" ); 
		return $tree;
	}

	return $self->compile_thing;
}

# THING = VAR 
#       | string
#       | ident				# item param shortcut
#       | ident + "(" + LIST + ")"	# function
# VAR   = "\$" + IDENT

sub compile_thing
{
	my( $self ) = @_;

	if( $self->next_is( "STRING" ) )
	{
		return $self->give_me( "STRING" );
	}

	if( $self->next_is( "DOLLAR" ) )
	{
		$self->give_me( "DOLLAR", "Expected dollar" );
		my $var = $self->give_me( "IDENT", "Expected state variable name" );
		$var->{id} = "VAR";
		return $var;
	}

	my $ident = $self->give_me( "IDENT", "Expected function, main-item parameter name, string or state variable" );

	# function
	if( $self->next_is( "OPEN_B" ) )
	{
		$self->give_me( "OPEN_B", "Expected open bracket" );

		$ident->{id} = $ident->{value};
		$ident->{params} = [ @{$self->compile_list} ];

		$self->give_me( "CLOSE_B", "Expected close bracket" );

		return $ident;
	}

	# must be an ident by itself (shortcut for $item{foo}

	$ident->{id} = "MAIN_ITEM_PROPERTY";
	return $ident;
}

sub compile_list
{
	my( $self ) = @_;

	return [] if( $self->next_is( "CLOSE_B" ) );

	my $values = [];
	push @$values, $self->compile_expr;
	while( $self->next_is( "COMMA" ) )
	{
		$self->give_me( "COMMA", "Expected comma" );
		push @$values, $self->compile_expr;
	}
	
	return $values;
}

sub compile_error 
{ 
	my( $self, $msg ) = @_;

	EPrints::Script::error( $msg, $self->{in}, $self->{tokens}->[0]->{pos}, $self->{code} );
}	

my $x=<<__;
EXPR = AND_EXPR + ( "or" + EXPR)?
AND_EXPR = OR_EXPR + ( "and" + AND_EXPR )?
OR_EXPR = TEST_EXPR + ( "or" + OR_EXPR )?
TEST_EXPR = NOT_EXPR + ( TESTOP + TEST_EXPR )?
TEST_OP = "=" 
        | "!=" 
NOT_EXPR = ("!")? + METH_EXPR
METH_EXPR = B_EXPR + METH_OR_PROP*
METH_OR_PROP = "{" + ident + "}"		# property	
             | "." + ident + "(" + LIST + ")"	# method
B_EXPR = THING 
       | "(" + EXPR + ")"
THING = VAR 
      | string
      | ident				# item param shortcut
      | ident + "(" + LIST + ")"	# function
VAR = "\$" + IDENT

LIST = "" 
     | EXPR + ( "," + EXPR )*

__



