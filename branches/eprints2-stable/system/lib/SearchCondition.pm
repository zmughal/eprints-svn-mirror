######################################################################
#
# EPrints::SearchCondition
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

B<EPrints::SearchCondition> - undocumented

=head1 DESCRIPTION

Represents a simple atomic search condition like 
abstract contains "fish" or date is bigger than 2000.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

package EPrints::SearchCondition;

use EPrints::Database;

use strict;

# current conditional operators:

$EPrints::SearchCondition::operators = {
	'TRUE'=>0,		#	should only be used in optimisation
	'FALSE'=>0,		#	should only be used in optimisation

	'freetext'=>1,		#	dataset, field, value	

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


sub new
{
	my( $class, $op, @params ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{op} = $op;
	if( $op eq "AND" || $op eq "OR" )
	{
		$self->{sub_ops} = \@params;
	}
	elsif( $op eq "FALSE" || $op eq "TRUE" )
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

sub copy_from
{
	my( $self, $cond ) = @_;

	foreach( keys %{$self} ) { delete $self->{$_}; }

	foreach( keys %{$cond} ) { $self->{$_} = $cond->{$_}; }
}

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

sub get_table
{
	my( $self ) = @_;

	my $field = $self->{field};
	my $dataset = $self->{dataset};

	if( !defined $field )
	{
		return undef;
	}

	if( $self->{op} eq "freetext" )
	{
		return $dataset->get_sql_index_table_name;
	}	

	if( $field->get_property( "multiple" ) )
	{	
		return $dataset->get_sql_sub_table_name( $self->{field} );
	}	


	return $dataset->get_sql_table_name();
}

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

sub is_control
{
	my( $self ) = @_;

	return( 1 ) if( $self->{op} eq "AND" );
	return( 1 ) if( $self->{op} eq "OR" );

	return( 0 );
}

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

	if( $self->{op} eq "freetext" )
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

       	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	if( $self->{op} eq "grep" )
	{
		my( $codes, $new_grepcodes, $badwords ) =
			get_codes(
				$item->get_session,
				$item->get_dataset,
				$self->{field},
				$item );
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
print STDERR "REGEXP:$regexp\n";
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
			my $s = EPrints::Subject->new( 
					$item->get_session,
					$sub_id );	
			if( !defined $s )
			{
				$item->get_session->get_archive->log(
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
		$mode = "date" if( $self->{field}->is_type( "date" ) );
		
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

sub ordered_ops
{
	my( $self ) = @_;

	return sort { $a->get_op_val <=> $b->get_op_val } @{$self->{sub_ops}};
}


# If filter is set then it can be used as a filter on results.
# especially if there is a "LIKE" type operation.

# return a reference to an array of ID's
# or ["ALL"] to represent the entire set.

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

	if( $self->{op} eq "freetext" )
	{
		my $where = "fieldword = '".EPrints::Database::prep_value( 
			$self->{field}->get_sql_name.":".$self->{params}->[0] )."'";
		$r = $session->get_db()->get_index_ids( $self->get_table, $where );
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

 		my $gtable = $self->{dataset}->get_sql_index_table_name."_grep"; 
		my $SSIZE = 50;
		my $total = scalar @{$filter};
		my $kfn = $keyfield->get_sql_name; # key field name
		for( my $i = 0; $i<$total; $i+=$SSIZE )
		{
			my $max = $i+$SSIZE;
			$max = $total-1 if( $max > $total - 1 );
			my @fset = @{$filter}[$i..$max];
			
			my $set = $session->get_db->search( 
				$keyfield, 
				{ M=>$gtable },
				$where.' AND ('.$kfn.'='.join(' OR '.$kfn.'=', @fset ).' )' );
                        $r = _merge( $r , $set, 0 );
		}
	
	}


	if( $self->{op} eq "in_subject" )
	{
		my $where = "( M.$sql_col = S.subjectid AND  S.ancestors='".EPrints::Database::prep_value( $self->{params}->[0] )."' )";
		$r = $session->get_db->search( 
			$keyfield, 
			{	
				S=>"subject_ancestors",
				M=>$self->get_table
			},
			$where );
	}


	if( $self->{op} eq "is_null" )
	{
		my $where = "(M.$sql_col IS NULL OR ";
		$where .= "M.$sql_col = '')";
		$r = $session->get_db->search( 
			$keyfield, 
			{ M=>$self->get_table },
			$where );
	}

	if( $self->is_comparison )
	{
		my $where = "M.$sql_col ".$self->{op}." ".
			"'".EPrints::Database::prep_value( $self->{params}->[0] )."'";
		$r = $session->get_db->search( 
			$keyfield, 
			{ M=>$self->get_table },
			$where );
	}
#$session->get_db->set_debug( 1 ); print STDERR "\n";
#$session->get_db->set_debug( 0 );

#	print STDERR " [".join(",",@{$r})."]";
#	print STDERR "\n";

	return $r;
}

sub get_op_val
{
	my( $self ) = @_;

	return $EPrints::SearchCondition::operators->{$self->{op}};
}



# cjg
# I'm not sure if this helps, but it doesn't hurt either.
sub optimise
{
	my( $self ) = @_;

	if( $self->is_control )
	{
		foreach my $sub_op ( @{$self->{sub_ops}} )
		{
			$sub_op->optimise;
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
			my $keep_ops = [];
			foreach my $sub_op ( @{$self->{sub_ops}} )
			{
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

				if( $sub_op->{op} eq $self->{op} )
				{
					push @{$self->{sub_ops}}, 
						@{$sub_op->{sub_ops}};
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
			if( scalar @{$self->{sub_ops}} == 1 )
			{
				$self->copy_from( $self->{sub_ops}->[0] );
			}
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
	if( $and )
	{
		return $b if( $a->[0] eq "ALL" );
		return $a if( $b->[0] eq "ALL" );
	}
	elsif( $a->[0] eq "ALL" || $b->[0] eq "ALL" )
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

