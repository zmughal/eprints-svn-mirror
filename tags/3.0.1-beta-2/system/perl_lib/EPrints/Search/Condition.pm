######################################################################
#
# EPrints::Search::Condition
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

B<EPrints::Search::Condition> - Atomic search condition.

=head1 DESCRIPTION

Represents a simple atomic search condition like 
abstract contains "fish" or date is bigger than 2000.

Can also represent a "AND" or "OR"'d list of sub-conditions, so
forming a tree-like data-structure.

Search conditions can be used either to create search results (as
a list of id's), or to test if a single object matches the 
condition.

This module should usually not be used directly. It is used
internally by EPrints::Search.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{op}
#     The ID of the simple search operation.
#
#  $self->{dataset}
#     The EPrints::Dataset we are searching.
#
#  $self->{field}
#     The EPrints::MetaField which this condition applies to.
#
#  $self->{params}
#     Array reference to Parameters to the op, varies depending on
#     the op.
#
#  $self->{subops}
#     Array reference containing sub-search conditions used by AND
#     and or conditions.
#
######################################################################

package EPrints::Search::Condition;

use strict;

# current conditional operators:

$EPrints::Search::Condition::operators = {
	'CANPASS'=>0,		#	should only be used in optimisation
	'PASS'=>0,		#	should only be used in optimisation
	'TRUE'=>0,		#	should only be used in optimisation
	'FALSE'=>0,		#	should only be used in optimisation

	'index'=>1,		#	dataset, field, value	
	'index_start'=>1,	#	dataset, field, value	

	'='=>2,			#	dataset, field, value
	'name_match'=>2,	#	dataset, field, value		

	'AND'=>3,		#	cond, cond...	
	'OR'=>3,		#	cond, cond...

	'is_null'=>4,		#	dataset, field	
	'>'=>4,			#	dataset, field, value		
	'<'=>4,			#	dataset, field, value		
	'>='=>4,		#	dataset, field, value		
	'<='=>4,		#	dataset, field, value		
	'in_subject'=>4,	#	dataset, field, value		

	'grep'=>4	};	#	dataset, field, value		


######################################################################
=pod

=item $scond = EPrints::Search::Condition->new( $op, @params );

Create a new search condition object with the given operation and
parameters.

=cut
######################################################################

sub new
{
	my( $class, $op, @params ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{op} = $op;
	if( $op eq "AND" || $op eq "OR" || $op eq "CANPASS" )
	{
		$self->{sub_ops} = \@params;
	}
	elsif( $op eq "FALSE" || $op eq "TRUE" || $op eq "PASS" )
	{
		; # no params
	}
	else
	{
		$self->{dataset} = shift @params;
		$self->{field} = shift @params;
		$self->{params} = \@params;
	}

	return $self;
}

######################################################################
=pod

=item $scond->copy_from( $scond2 );

Make this search condition the same as $scond2. Used by the optimiser
to shuffle things around.

=cut
######################################################################

sub copy_from
{
	my( $self, $cond ) = @_;

	foreach( keys %{$self} ) { delete $self->{$_}; }

	foreach( keys %{$cond} ) { $self->{$_} = $cond->{$_}; }
}

######################################################################
=pod

=item $desc = $scond->describe

Return a text description of the structure of this search condition
tree. Used for debugging.

=cut
######################################################################

sub describe
{
	my( $self, $indent ) = @_;
	
	$indent = 0 unless( defined $indent );

	my $ind = "\t"x$indent;
	++$indent;

	if( defined $self->{sub_ops} )
	{
		my @r = ();
		foreach( @{$self->{sub_ops}} )
		{
			push @r, $_->describe( $indent );
		}
		return $ind.$self->{op}."(\n".join(",\n",@r)."\n".$ind.")";
	}

	if( !defined $self->{field} )
	{
		return $ind.$self->{op};
	}	

	my @o = ();
	if( defined $self->{field} )
	{
		push @o, '$'.$self->{dataset}->id.".".$self->{field}->get_name;
	}	

	if( $self->{op} eq 'name_match' )
	{
		push @o, '"'.$self->{params}->[0]->{family}.'"';
		push @o, '"'.$self->{params}->[0]->{given}.'"';
	}

	if( defined $self->{params} )
	{
		foreach( @{$self->{params}} )
		{
			push @o, '"'.$_.'"';
		}
	}	
	my $op_desc = $ind.$self->{op}."(".join( ",", @o ).")";
	$op_desc.= " ... ".$self->get_table;
	return $op_desc;
}

######################################################################
=pod

=item $sql_table = $scond->get_table

Return the name of the actual SQL table which this condition is
concerned with.

=cut
######################################################################

sub get_table
{
	my( $self ) = @_;

	my $field = $self->{field};
	my $dataset = $self->{dataset};

	if( !defined $field )
	{
		return undef;
	}

	if( $self->{op} eq "index" || $self->{op} eq "index_start" )
	{
		return $dataset->get_sql_index_table_name;
	}	

	if( $field->get_property( "multiple" ) )
	{	
		return $dataset->get_sql_sub_table_name( $field );
	}	
	return $dataset->get_sql_table_name();
}

######################################################################
=pod

=item $bool = $scond->is_comparison

Return true if the OP is one of =, >, <, >=, <=

=cut
######################################################################

sub is_comparison
{
	my( $self ) = @_;

	return( 1 ) if( $self->{op} eq "=" );
	return( 1 ) if( $self->{op} eq "<=" );
	return( 1 ) if( $self->{op} eq ">=" );
	return( 1 ) if( $self->{op} eq "<" );
	return( 1 ) if( $self->{op} eq ">" );

	return( 0 );
}

######################################################################
=pod

=item $bool = $scond->is_control

Return true if the OP is one of AND, OR.

=cut
######################################################################

sub is_control
{
	my( $self ) = @_;

	return( 1 ) if( $self->{op} eq "AND" );
	return( 1 ) if( $self->{op} eq "OR" );

	return( 0 );
}

######################################################################
=pod

=item $bool = $scond->item_matches( $dataobj )

Return true if the given data object matches this search condition.

=cut
######################################################################

sub item_matches
{
	my( $self, $item ) = @_;

	if( $self->{op} eq "TRUE" )
	{
		return( 1 );
	}

	if( $self->{op} eq "FALSE" )
	{
		return( 0 );
	}

#	if( $self->{op} eq "NOT" )
#	{
#		my $r = $self->{sub_ops}->[0]->item_matches( $item );
#		return( !$r );
#	}

	if( $self->{op} eq "PASS" )
	{
		$item->get_session->get_repository->log( <<END );
PASS condition used in 'item_matches', should have been optimised!
END
		return( 0 );
	}

	if( $self->{op} eq "AND" )
	{
		foreach my $sub_op ( $self->ordered_ops )
		{
			my $r = $sub_op->item_matches( $item );
			return( 0 ) if( $r == 0 );
		}
		return( 1 );
	}

	if( $self->{op} eq "OR" )
	{
		foreach my $sub_op ( $self->ordered_ops )
		{
			my $r = $sub_op->item_matches( $item );
			return( 1 ) if( $r == 1 );
		}
		return( 0 );
	}

	if( $self->{op} eq "index" )
	{
		my( $codes, $grepcodes, $badwords ) =
			$self->{field}->get_index_codes(
				$item->get_session,
				$item->get_value( $self->{field}->get_name ) );

		foreach my $code ( @{$codes} )
		{
			return( 1 ) if( $code eq $self->{params}->[0] );
		}
		return( 0 );
	}

	if( $self->{op} eq "index_start" )
	{
		my( $codes, $grepcodes, $badwords ) =
			$self->{field}->get_index_codes(
				$item->get_session,
				$item->get_value( $self->{field}->get_name ) );

		my $p = $self->{params}->[0];
		foreach my $code ( @{$codes} )
		{
			return( 1 ) if( substr( $code, 0, length $p ) eq $p );
		}
		return( 0 );
	}

       	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	if( $self->{op} eq "grep" )
	{
		my( $codes, $grepcodes, $badwords ) =
			$self->{field}->get_index_codes(
				$item->get_session,
				$item->get_value( $self->{field}->get_name ) );

		my @re = ();
		foreach( @{$self->{params}} )
		{
			my $r = $_;
			$r =~ s/([^a-z0-9%?])/\\$1/gi;
			$r =~ s/\%/.*/g;
			$r =~ s/\?/./g;
			push @re, $r;
		}
			
		my $regexp = '^('.join( '|', @re ).')$';

		foreach my $grepcode ( @{$grepcodes} )
		{
			return( 1 ) if( $grepcode =~ m/$regexp/ );
		}
		return( 0 );
	}


	if( $self->{op} eq "in_subject" )
	{
		my @sub_ids = $self->{field}->list_values( 
			$item->get_value( $self->{field}->get_name ) );
		# true if {params}->[0] is the ancestor of any of the subjects
		# of the item.

		foreach my $sub_id ( @sub_ids )
		{
			my $s = EPrints::DataObj::Subject->new( 
					$item->get_session,
					$sub_id );	
			if( !defined $s )
			{
				$item->get_session->get_repository->log(
"Attempt to call item_matches on a searchfield with non-existant\n".
"subject id: '$_', item was #".$item->get_id );
				next;
			}

			foreach my $an_sub ( @{$s->get_value( "ancestors" )} )
			{
				return( 1 ) if( $an_sub eq $self->{params}->[0] );
			}
		}
		return( 0 );
	}

	if( $self->{op} eq "is_null" )
	{
		return $item->is_set( $self->{field}->get_name );
	}

	if( $self->{op} eq "name_match" )
	{
print STDERR "\n---name_match comparisson not done yet...\n";
		return 1;
	}


	#####################
	# Simple comparisons from here on in
	#
	# 3 different modes
	# 	int, year
	#	date (currently handled like text)
	#	other (text)

	if( $self->is_comparison )
	{
		my $mode = "string";
		$mode = "int" if( $self->{field}->is_type( "year","int") );
		$mode = "date" if( $self->{field}->is_type( "date","time" ) );
		
		my @values = $self->{field}->list_values( 
			$item->get_value( $self->{field}->get_name ) );
		foreach my $value ( @values )
		{
			if( _compare( 
				$mode,
				$value, 
				$self->{op}, 
				$self->{params}->[0] ) )
			{
				return( 1 );
			}
		}
		return( 0 );
	}

	print STDERR "Error in item_matches. End of function reached.\n".
			"The op code was: '".$self->{op}."'";

	return( 0 );
}

sub _compare
{
	my( $mode, $left, $op, $right ) = @_;

	if( $mode eq "int" )
	{
		return( $left == $right ) if( $op eq "=" );
		return( $left > $right ) if( $op eq ">" );
		return( $left < $right ) if( $op eq "<" );
		return( $left >= $right ) if( $op eq ">=" );
		return( $left <= $right ) if( $op eq "<=" );
		print STDERR "Bad op ($op) in _compare\n";
		return( 0 );
	}

	if( $mode eq "string" || $mode eq "date" )
	{
		return( $left eq $right ) if( $op eq "=" );
		return( $left gt $right ) if( $op eq ">" );
		return( $left lt $right ) if( $op eq "<" );
		return( $left ge $right ) if( $op eq ">=" );
		return( $left le $right ) if( $op eq "<=" );
		print STDERR "Bad op ($op) in _compare\n";
		return( 0 );
	}

	print STDERR "Bad mode ($mode) in _compare\n";
	return( 0 );
}

######################################################################
=pod

=item @ops = $scond->ordered_ops

AND or OR conditions only. Return the sub conditions ordered by 
approximate ease. This is used to make sure a TRUE or FALSE is
prcessed before an index-lookup, and that everthing else is is tried 
before a grep OP (which uses LIKE). This means that it can often
give up before the expensive operation is needed.

=cut
######################################################################

sub ordered_ops
{
	my( $self ) = @_;

	return sort { $a->get_op_val <=> $b->get_op_val } @{$self->{sub_ops}};
}

######################################################################
=pod

=item @ops = $scond->get_op_val

Return a number which roughly relates to how "hard" the OP of this 
condition is. Used to decide what order to process AND and OR 
sub-conditions.

=cut
######################################################################

sub get_op_val
{
	my( $self ) = @_;

	return $EPrints::Search::Condition::operators->{$self->{op}};
}


# return a reference to an array of ID's
# or ["ALL"] to represent the entire set.

######################################################################
=pod

=item $ids = $scond->process( $session, [$indent], [$filter] );

Return a reference to an array containing the ID's of items in
the database which match this condition.

If the search condition matches the whole dataset then it returns
["ALL"] rather than a huge list of ID's.

$indent is only used for debugging code. 

$filter is only used in ops of type "grep". It is a reference to
an array of ids of items to be greped, so that the grep does not
need to be applied to all values in the database.

=cut
######################################################################

sub process
{
	my( $self, $session, $i, $filter ) = @_;

	$i = 0 unless( defined $i );

	if( $self->{op} eq "TRUE" )
	{
		return ["ALL"];
	}
	if( $self->{op} eq "FALSE" )
	{
		return [];
	}

	if( $self->{op} eq "PASS" )
	{
		$session->get_repository->log( <<END );
PASS condition used in 'process', should have been optimised!
END
		return( 0 );
	}

	if( $self->{op} eq "AND" )
	{
#print STDERR "PROCESS: ".("  "x$i)."AND\n";
		my $set;
		foreach my $sub_op ( $self->ordered_ops )
		{
			my $r = $sub_op->process( $session, $i + 1, $set );
			if( scalar @{$r} == 0 )
			{
				$set = [];
				last;
			}
			if( !defined $set )
			{
				$set = $r;
				next;
			}
			$set = _merge( $r , $set, 1 );
		}
#print STDERR "PROCESS: ".("  "x$i)."/AND [".join(",",@{$set})."]\n";
		return $set;
	}

	if( $self->{op} eq "OR" )
	{
#print STDERR "PROCESS: ".("  "x$i)."OR\n";
		my $set;
		foreach my $sub_op ( $self->ordered_ops )
		{
			my $r = $sub_op->process( $session, $i + 1);
			if( !defined $set )
			{
				$set = $r;
				next;
			}
			$set = _merge( $r , $set, 0 );
		}
#print STDERR "PROCESS: ".("  "x$i)."/OR [".join(",",@{$set})."]\n";
		return $set;
	}

	my $r = [];
#print STDERR "PROCESS: ".("  "x$i).$self->describe;

	if( $self->{op} eq "index" )
	{
		my $where = "fieldword = '".EPrints::Database::prep_value( 
			$self->{field}->get_sql_name.":".$self->{params}->[0] )."'";
		$r = $session->get_database->get_index_ids( $self->get_table, $where );
	}
	if( $self->{op} eq "index_start" )
	{
		my $where = "fieldword LIKE '".EPrints::Database::prep_value( 
			$self->{field}->get_sql_name.":".$self->{params}->[0] )."%'";
		$r = $session->get_database->get_index_ids( $self->get_table, $where );
	}

       	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	if( $self->{op} eq "grep" )
	{
		if( !defined $filter )
		{
			print STDERR "WARNING: grep without filter! This is very inefficient.\n";	
			# cjg better logging?
		}

		my $where = "( M.fieldname = '$sql_col' AND (";
		my $first = 1;
		foreach my $cond (@{$self->{params}})
		{
			$where.=" OR " unless( $first );
			$first = 0;
			# not prepping like values...
			$where .= "M.grepstring LIKE '$cond'";
		}
		$where.="))";

 		my $gtable = $self->{dataset}->get_sql_grep_table_name;
		my $SSIZE = 50;
		my $total = scalar @{$filter};
		my $kfn = $keyfield->get_sql_name; # key field name
		for( my $i = 0; $i<$total; $i+=$SSIZE )
		{
			my $max = $i+$SSIZE;
			$max = $total-1 if( $max > $total - 1 );
			my @fset = @{$filter}[$i..$max];
			
			my $set = $session->get_database->search( 
				$keyfield, 
				{ M=>$gtable },
				$where.' AND ('.$kfn.'='.join(' OR '.$kfn.'=', @fset ).' )' );
                        $r = _merge( $r , $set, 0 );
		}
	
	}


	if( $self->{op} eq "in_subject" )
	{
		my $where = "( M.$sql_col = S.subjectid AND  S.ancestors='".EPrints::Database::prep_value( $self->{params}->[0] )."' )";
		$r = $session->get_database->search( 
			$keyfield, 
			{	
				S=>"subject_ancestors",
				M=>$self->get_table
			},
			$where );
	}


	if( $self->{op} eq "is_null" )
	{
		my $where;
		if( $self->{field}->is_type( "date", "time" ) )
		{
			$where = "(M.${sql_col}_year IS NULL)";
		}
		else
		{
			$where = "(M.$sql_col IS NULL OR ";
			$where .= "M.$sql_col = '')";
		}
		$r = $session->get_database->search( 
			$keyfield, 
			{ M=>$self->get_table },
			$where );
	}

	if( $self->{op} eq 'name_match' )
	{
		my $where = "(M.".$sql_col."_given = '".EPrints::Database::prep_value( $self->{params}->[0]->{given} )."' AND M.".$sql_col."_family = '".EPrints::Database::prep_value( $self->{params}->[0]->{family} )."')";
		$r = $session->get_database->search( 
			$keyfield, 
			{ M=>$self->get_table },
			$where );
	}


	if( $self->is_comparison )
	{
		my $where;
		if( $self->{field}->is_type( "date" ) )
		{
			my @parts = split( "-", $self->{params}->[0] );
			$where = "M.${sql_col}_year ".$self->{op}." "."'".EPrints::Database::prep_value( $parts[0] )."'";
			if( $parts[1] && $parts[1]+0 ) { $where.= " AND M.${sql_col}_month ".$self->{op}." "."'".EPrints::Database::prep_value( $parts[1] )."'"; }
			if( $parts[2] && $parts[2]+0 ) { $where.= " AND M.${sql_col}_day ".$self->{op}." "."'".EPrints::Database::prep_value( $parts[2] )."'"; }
		}
		elsif( $self->{field}->is_type( "time" ) )
		{
			# time searching needs more testing. Esp. boundary conditions.
			my @parts = split( /[-: ]/, $self->{params}->[0] );
			$where = "M.${sql_col}_year ".$self->{op}." "."'".EPrints::Database::prep_value( $parts[0] )."'";
			if( $parts[1] ) { $where.= " AND M.${sql_col}_month ".$self->{op}." "."'".EPrints::Database::prep_value( $parts[1] )."'"; }
			if( $parts[2] ) { $where.= " AND M.${sql_col}_day ".$self->{op}." "."'".EPrints::Database::prep_value( $parts[2] )."'"; }
			if( $parts[3] ) { $where.= " AND M.${sql_col}_hour ".$self->{op}." "."'".EPrints::Database::prep_value( $parts[3] )."'"; }
			if( $parts[4] ) { $where.= " AND M.${sql_col}_minute ".$self->{op}." "."'".EPrints::Database::prep_value( $parts[4] )."'"; }
			if( $parts[5] ) { $where.= " AND M.${sql_col}_second ".$self->{op}." "."'".EPrints::Database::prep_value( $parts[5] )."'"; }
		}
		elsif( $self->{field}->is_type( "pagerange","int","year" ) )
		{
			$where = "M.$sql_col ".$self->{op}." ".EPrints::Database::prep_int( $self->{params}->[0] );
		}
		else
		{
			$where = "M.$sql_col ".$self->{op}." "."'".EPrints::Database::prep_value( $self->{params}->[0] )."'";
		}
		$r = $session->get_database->search( 
			$keyfield, 
			{ M=>$self->get_table },
			$where );
	}
#$session->get_database->set_debug( 1 ); print STDERR "\n";
#$session->get_database->set_debug( 0 );

#	print STDERR " [".join(",",@{$r})."]";
#	print STDERR "\n";

	return $r;
}


######################################################################
=pod

=item @ops = $scond->optimise

Rearrange this condition tree so that it is more optimised.

For example an "OR" where one sub op is "TRUE" can be optimised to
just be "TRUE" itself.

=cut
######################################################################

# internal means don't strip canpass off the front.
sub optimise
{
	my( $self, $internal ) = @_;

	if( $self->is_control )
	{
		foreach my $sub_op ( @{$self->{sub_ops}} )
		{
			$sub_op->optimise( 1 );
		}

#		if( $self->{op} eq "NOT" )
#		{
#			if( $self->{sub_ops}->[0]->{op} eq "NOT" )
#			{
#				$self->copy_from( 
#					$self->{sub_ops}->[0]->{sub_ops}->[0] );
#			}
#
#			if( $self->{sub_ops}->[0]->{op} eq "TRUE" )
#			{
#				delete $self->{sub_ops};
#				$self->{op} = "FALSE";
#			}
#
#			if( $self->{sub_ops}->[0]->{op} eq "FALSE" )
#			{
#				delete $self->{sub_ops};
#				$self->{op} = "TRUE";
#			}
#		}

		if( $self->{op} eq "AND" || $self->{op} eq "OR" )
		{
			my $override = "TRUE";
			my $forget = "FALSE";
			if( $self->{op} eq "AND" )
			{
				$override = "FALSE";
				$forget = "TRUE";
			}

			# strip passes or become a canpass if all pass
			my $canpass = 1;
			my $mustpass = 0;
			my @passops = ();
			my @sureops = ();
			foreach my $sub_op ( @{$self->{sub_ops}} )
			{
				if( $sub_op->{op} eq "PASS" )
				{
					$mustpass = 1;
					next;
				}
				if( $sub_op->{op} eq "CANPASS" )
				{
					push @passops, $sub_op->{sub_ops}->[0];
					next;
				}
				push @sureops, $sub_op;
				$canpass = 0;
			}
			if( $canpass )
			{
				$self->{sub_ops} = \@passops;
			}
			else
			{
				$self->{sub_ops} = \@sureops;
			}
			

			# flatten sub opts with the same type
			# so OR( A, OR( B, C ) ) becomes OR(A,B,C)
			my $flat_ops = [];
			foreach my $sub_op ( @{$self->{sub_ops}} )
			{
				if( $sub_op->{op} eq $self->{op} )
				{
					push @{$flat_ops}, 
						@{$sub_op->{sub_ops}};
					next;
				}
				
				push @{$flat_ops}, $sub_op;
			}
			$self->{sub_ops} = $flat_ops;

			my $keep_ops = [];
			foreach my $sub_op ( @{$self->{sub_ops}} )
			{
				# if an OR contains TRUE or an
				# AND contains FALSE then we can
				# cancel it all out.
				if( $sub_op->{op} eq $override )
				{
					delete $self->{sub_ops};
					$self->{op} = $override;
					return;
				}

				if( $sub_op->{op} eq $forget )
				{
					next;
				}
				
				push @{$keep_ops}, $sub_op;
			}
			$self->{sub_ops} = $keep_ops;
			if( scalar @{$self->{sub_ops}} == 0 )
			{
				delete $self->{sub_ops};
				$self->{op} = "FALSE";	
			}
			elsif( scalar @{$self->{sub_ops}} == 1 )
			{
				$self->copy_from( $self->{sub_ops}->[0] );
			}

			if( $canpass || $mustpass )
			{
				my $newop = new EPrints::Search::Condition();
				$newop->copy_from( $self );
				$self->{op} = "CANPASS";
				$self->{sub_ops} = [ $newop ];
			}
		}
	}

	# do final clean up stuff, if any
	if( !$internal )
	{
		if( $self->{op} eq "CANPASS" )
		{
			my $sop = $self->{sub_ops}->[0];
			$self->copy_from( $sop );
		}
	}


}

# special handling if first item in the list is
# "ALL"
sub _merge
{
	my( $a, $b, $and ) = @_;

	$a = [] unless( defined $a );
	$b = [] unless( defined $b );
	my $a_all = ( defined $a->[0] && $a->[0] eq "ALL" );
	my $b_all = ( defined $b->[0] && $b->[0] eq "ALL" );
	if( $and )
	{
		return $b if( $a_all );
		return $a if( $b_all );
	}
	elsif( $a_all || $b_all )
	{
		# anything OR'd with "ALL" is "ALL"
		return [ "ALL" ];
	}

	my @c;
	if ($and) {
		my (%MARK);
		grep($MARK{$_}++,@{$a});
		@c = grep($MARK{$_},@{$b});
	} else {
		my (%MARK);
		foreach(@{$a}, @{$b}) {
			$MARK{$_}++;
		}
		@c = keys %MARK;
	}

	return \@c;
}



sub _name_cmp
{
	my( $family, $given, $in, $name ) = @_;

	my $nfamily = lc $name->{family};
	my $ngiven = substr( lc $name->{given}, 0, length( $given ) );

	if( $in )
	{
		$nfamily = substr( $nfamily, 0, length( $family ) );
	}

	return( 0 ) unless( lc $family eq $nfamily );
	return( 0 ) unless( lc $given eq $ngiven );
	return( 1 );
}

1;

######################################################################
=pod

=back

=cut
