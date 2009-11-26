######################################################################
#
# EPrints::Search::Condition::Comparison
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

B<EPrints::Search::Condition::Comparison> - "Comparison" search condition

=head1 DESCRIPTION

Matches items which are < > = <= or => to a value.

=cut

package EPrints::Search::Condition::Comparison;

use EPrints::Search::Condition;

@ISA = qw( EPrints::Search::Condition );

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = {};
	$self->{op} = shift @params;
	$self->{dataset} = shift @params;
	$self->{field} = shift @params;
	$self->{params} = \@params;

	return bless $self, $class;
}




sub _item_matches
{
	my( $self, $item ) = @_;

 	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;
		
	my @values = $self->{field}->list_values( 
		$item->get_value( $self->{field}->get_name ) );
	my $op = $self->{op};
	my $right = $self->{params}->[0];
	if( $self->{field}->is_type( "year","int") )
	{
		foreach my $value ( @values )
		{
			return 1 if( $op eq "="  && $value == $right );
			return 1 if( $op eq ">"  && $value >  $right );
			return 1 if( $op eq "<"  && $value <  $right );
			return 1 if( $op eq ">=" && $value >= $right );
			return 1 if( $op eq "<=" && $value <= $right );
		}
	}
	else
	{
		foreach my $value ( @values )
		{
			return 1 if( $op eq "="  && $value eq $right );
			return 1 if( $op eq ">"  && $value gt $right );
			return 1 if( $op eq "<"  && $value lt $right );
			return 1 if( $op eq ">=" && $value ge $right );
			return 1 if( $op eq "<=" && $value le $right );
		}
	}

	return( 0 );
}

sub get_datetime_where_clause
{
	my( $self, $session ) = @_;
	
	my $database = $session->get_database;
	my $sql_col = $self->{field}->get_sql_name;

	my( $cmp, $eq ) = @{ { 
		'>=', [ '>', 1 ],
		'<=', [ '<', 1 ],
		'>', [ '>', 0 ],
		'<', [ '<', 0 ],
		'=', [ undef, 1 ] }->{$self->{op}} };
	my $timemap = [ 'year','month','day','hour','minute','second' ];

	my @parts = split( /[-: TZ]/, $self->{params}->[0] );
	my $nparts = scalar @parts;
	if( $self->{field}->is_type( "date" ) && $nparts > 3 )
	{
		$nparts = 3;
	}

	my @or = ();

	if( defined $cmp )
	{
		for( my $i=0;$i<$nparts;++$i )
		{
			my @and = ();
			for( my $j=0;$j<=$i;++$j )
			{	
				my $o = "=";
				if( $j==$i ) { $o = $cmp; }
				push @and, $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,$sql_col."_".$timemap->[$j])." ".$o." ".$database->quote_value( $parts[$j] ); 
			}
			push @or, "( ".join( " AND ", @and )." )";
		}
	}

	if( $eq )
	{
		my @and = ();
		for( my $i=0;$i<$nparts;++$i )
		{
			push @and, $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,$sql_col."_".$timemap->[$i])." = ".$database->quote_value( $parts[$i] ); 
		}
		push @or, "( ".join( " AND ", @and )." )";
	}

	return "(".join( " OR ", @or ).")";
}

sub get_op_val
{
	my( $self ) = @_;

	return 2 if( $self->{op} eq "=" );

	return 4;
}

sub get_query_joins
{
	my( $self, $joins, %opts ) = @_;

	my $field = $self->{field};
	my $dataset = $field->{dataset};

	$joins->{$dataset->confid} ||= { dataset => $dataset };
	$self->{join}->{alias} = $dataset->get_sql_table_name;

	if( $field->get_property( "multiple" ) )
	{
		my $table = $dataset->get_sql_sub_table_name( $field );
		my $idx = scalar(@{$joins->{$dataset->confid}->{'multiple'} ||= []});
		push @{$joins->{$dataset->confid}->{'multiple'}}, $self->{join} = {
			table => $table,
			alias => $idx . "_" . $table,
			key => $dataset->get_key_field->get_sql_name,
		};
	}
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $field = $self->{field};
	my $dataset = $field->{dataset};

	my $table = $self->{join}->{alias};
	my $q_table = $db->quote_identifier( $table );

	my $sql_name = $field->get_sql_name;

	my $op = $self->{op};

	if( $field->isa( "EPrints::MetaField::Name" ) )
	{
		my @logic;
		for(qw( given family ))
		{
			my $q_name = $db->quote_identifier( "$sql_name\_$_" );
			my $q_value = $db->quote_value( $self->{params}->[0]->{$_} );
			push @logic, "$q_table.$q_name $op $q_value";
		}
		return "(".join(") AND (", @logic).")";
	}
	elsif( $field->isa( "EPrints::MetaField::Date" ) )
	{
		return $self->_logic_time( %opts );
	}
	elsif( $field->isa( "EPrints::MetaField::Int" ) )
	{
		my $q_name = $db->quote_identifier( $sql_name );
		my $q_value = EPrints::Database::prep_int( $self->{params}->[0] );

		return "$q_table.$q_name $op $q_value";
	}
	else
	{
		my $q_name = $db->quote_identifier( $sql_name );
		my $q_value = $db->quote_value( $self->{params}->[0] );

		return "$q_table.$q_name $op $q_value";
	}
}

sub _logic_time
{
	my( $self, %opts ) = @_;
	
	my $session = $opts{session};
	my $database = $session->get_database;
	my $table = $opts{table};
	my $sql_col = $self->{field}->get_sql_name;

	my( $cmp, $eq ) = @{ { 
		'>=', [ '>', 1 ],
		'<=', [ '<', 1 ],
		'>', [ '>', 0 ],
		'<', [ '<', 0 ],
		'=', [ undef, 1 ] }->{$self->{op}} };
	my $timemap = [ 'year','month','day','hour','minute','second' ];

	my @parts = split( /[-: TZ]/, $self->{params}->[0] );
	my $nparts = scalar @parts;
	if( $self->{field}->isa( "EPrints::MetaField::Date" ) && $nparts > 3 )
	{
		$nparts = 3;
	}

	my @or = ();

	if( defined $cmp )
	{
		for( my $i=0;$i<$nparts;++$i )
		{
			my @and = ();
			for( my $j=0;$j<=$i;++$j )
			{	
				my $o = "=";
				if( $j==$i ) { $o = $cmp; }
				push @and, $database->quote_identifier($table,$sql_col."_".$timemap->[$j])." ".$o." ".EPrints::Database::prep_int( $parts[$j] ); 
			}
			push @or, "( ".join( " AND ", @and )." )";
		}
	}

	if( $eq )
	{
		my @and = ();
		for( my $i=0;$i<$nparts;++$i )
		{
			push @and, $database->quote_identifier($table,$sql_col."_".$timemap->[$i])." = ".EPrints::Database::prep_int( $parts[$i] ); 
		}
		push @or, "( ".join( " AND ", @and )." )";
	}

	return "(".join( " OR ", @or ).")";
}

sub joins
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;

	# parent dataset
	if( $self->dataset->confid eq $opts{dataset}->confid )
	{
		# parent table
		if( !$self->{field}->get_property( "multiple" ) )
		{
			return ();
		}
		else
		{
			my $table = $self->table;
			return {
				type => "inner",
				table => $table,
				alias => "$prefix$table",
				key => $self->dataset->get_key_field->get_sql_name,
			};
		}
	}
	# join to another dataset
	else
	{
		my( $left_key, $right_key ) = $self->join_keys( $opts{dataset}, $self->dataset );
		my $main_table = $self->dataset->get_sql_table_name;
		my $main_key = $self->dataset->get_key_field->get_sql_name;
		# join to main table of child dataset
		if( !$self->{field}->get_property( "multiple" ) )
		{
			return {
				type => "inner",
				table => $main_table,
				alias => "$prefix$main_table",
				key => $right_key,
			};
		}
		else
		{
			my $table = $self->table;
			my $sql = "";
			$sql .= $db->quote_identifier( $main_table ) . " " . $db->quote_identifier( "$prefix$main_table" );
			$sql .= " INNER JOIN ". $db->quote_identifier( $table ) . " " . $db->quote_identifier( "$prefix$table" );
			$sql .= " ON ".$db->quote_identifier( "$prefix$main_table", $main_key )."=".$db->quote_identifier( "$prefix$table", $main_key );
			return {
				type => "inner",
				subquery => $sql,
				key => $right_key
			};
		}
	}
}

sub logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;
	if( $self->table eq $opts{dataset}->get_sql_table_name )
	{
		$prefix = "";
	}

	my $table = $prefix . $self->table;
	my $field = $self->{field};
	my $sql_name = $field->get_sql_name;

	if( $field->isa( "EPrints::MetaField::Name" ) )
	{
		my @logic;
		for(qw( given family ))
		{
			push @logic, sprintf("%s %s %s",
				$db->quote_identifier( $table, "$sql_name\_$_" ),
				$self->{op},
				$db->quote_value( $self->{params}->[0]->{$_} ) );
		}
		return "(".join(") AND (", @logic).")";
	}
	elsif( $field->isa( "EPrints::MetaField::Date" ) )
	{
		return $self->_logic_time( %opts, table => $table );
	}
	elsif( $field->isa( "EPrints::MetaField::Int" ) )
	{
		return sprintf("%s %s %s",
			$db->quote_identifier( $table, $sql_name ),
			$self->{op},
			EPrints::Database::prep_int( $self->{params}->[0] ) );
	}
	else
	{
		return sprintf("%s %s %s",
			$db->quote_identifier( $table, $sql_name ),
			$self->{op},
			$db->quote_value( $self->{params}->[0] ) );
	}
}

1;
