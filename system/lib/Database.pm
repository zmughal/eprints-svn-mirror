######################################################################
#
# EPrints Database Access Module
#
#  Provides access to the backend database. All database access done
#  via this module, in the hope that the backend can be replaced
#  as easily as possible.
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

package EPrints::Database;

use DBI;
use EPrints::Deletion;
use EPrints::EPrint;
use EPrints::Subscription;

#
# Table names
#


#
# Counters
#
@EPrints::Database::counters = ( "eprintid" );


#
#
# ID of next buffer table. This can safely reset to zero each time
# The module restarts as it is only used for temporary tables.
#
my $NEXTBUFFER = 0;

######################################################################
#
# connection_handle build_connection_string( %params )
#                                            
#  Build the string to use to connect via DBI
#  params are:
#     db_host, db_port, db_name and db_sock.
#  Only db_name is required.
#
######################################################################

## WP1: BAD
sub build_connection_string
{
	my( %params ) = @_;

        # build the connection string
        my $dsn = "DBI:mysql:database=$params{db_name}";
        if( defined $params{db_host} )
        {
                $dsn.= ";host=".$params{db_host};
        }
        if( defined $params{db_port} )
        {
                $dsn.= ";port=".$params{db_port};
        }
        if( defined $params{db_sock} )
        {
                $dsn.= ";socket=".$params{db_sock};
        }
        return $dsn;
}



######################################################################
#
# EPrints::Database new( $session )
#                        EPrints::Session
#                          
#  Connect to the database.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class , $session) = @_;

	my $self = {};
	bless $self, $class;
	$self->{session} = $session;

	# Connect to the database
	$self->{dbh} = DBI->connect( 
		build_connection_string( 
			db_host => $session->get_archive()->get_conf("db_host"),
			db_sock => $session->get_archive()->get_conf("db_sock"),
			db_port => $session->get_archive()->get_conf("db_port"),
			db_name => $session->get_archive()->get_conf("db_name") ),
	        $session->get_archive()->get_conf("db_user"),
	        $session->get_archive()->get_conf("db_pass") );

#	        { PrintError => 0, AutoCommit => 1 } );

	if( !defined $self->{dbh} )
	{
		return( undef );
	}

	#$self->{dbh}->trace( 2 );

	return( $self );
}



######################################################################
#
# disconnect()
#
#  Disconnects from the EPrints database. Should always be done
#  before any script exits.
#
######################################################################

## WP1: BAD
sub disconnect
{
	my( $self ) = @_;
	
	# Make sure that we don't disconnect twice, or inappropriately
	if( defined $self->{dbh} )
	{
		$self->{dbh}->disconnect() ||
			$self->{session}->get_archive()->log( "Database disconnect error: ".
				$self->{dbh}->errstr );
	}
}


######################################################################
#
# $error = error()
# string 
# 
#  Gives details of any errors that have occurred
#
######################################################################

## WP1: BAD
sub error
{
	my( $self ) = @_;
	
	return $self->{dbh}->errstr;
}


######################################################################
#
# $success = create_archive_tables()
# boolean 
#
#  Creates the archive tables (user, archive and buffer) from the
#  metadata tables.
#
######################################################################

## WP1: BAD
sub create_archive_tables
{
	my( $self ) = @_;
	
	my $success = 1;

	foreach( "user" , "inbox" , "buffer" , "archive" ,
		 "document" , "subject" , "subscription" , "deletion" )
	{
		$success = $success && $self->_create_table( 
			$self->{session}->get_archive()->get_data_set( $_ ) );
	}

	#$success = $success && $self->_create_tempmap_table();

	$success = $success && $self->_create_counter_table();
	
	return( $success );
}
		


######################################################################
#
# $success = _create_table( $dataset )
# boolean                   EPrints::DataSet
#
#  Create a database table to contain the given dataset.
#
#  The aux. function has an extra parameter which means the table
#  has no primary key, this is for purposes of recursive table 
#  creation (aux. tables have no primary key)
#
######################################################################

## WP1: BAD
sub _create_table
{
	my( $self, $dataset ) = @_;
	
	my $rv = 1;

	my $keyfield = $dataset->get_key_field()->clone;

	my $fieldword = EPrints::MetaField->new( 
		undef,
		{ 
			name => "fieldword", 
			type => "text"
		} );

	$rv = $rv & $self->_create_table_aux(
			$dataset->get_sql_index_table_name,
			$dataset,
			0, # no primary key
			( $keyfield , $fieldword ) );

	$rv = $rv && $self->_create_table_aux( 
				$dataset->get_sql_table_name, 
				$dataset, 
				1, 
				$dataset->get_fields() );

	return $rv;
}

# $rv = _create_table_aux( $tablename, $dataset, $setkey, @fields )
# boolean                  string      |         boolean  array of
#                                      EPrints::DataSet   EPrint::MetaField

## WP1: BAD
sub _create_table_aux
{
	my( $self, $tablename, $dataset, $setkey, @fields ) = @_;
	
	my $field;
	my $rv = 1;

	# Construct the SQL statement
	my $sql = "CREATE TABLE $tablename (";
	my $key = undef;
	my @indices;
	my $first = 1;
	# Iterate through the columns
	foreach $field (@fields)
	{
		if ( $field->get_property( "multiple" ) )
		{ 	
			# make an aux. table for a multiple field
			# which will contain the same type as the
			# key of this table paired with the non-
			# multiple version of this field.
			# auxfield and keyfield must be indexed or 
			# there's not much point. 

			my $auxfield = $field->clone;
			$auxfield->set_property( "multiple", 0 );
			my $keyfield = $dataset->get_key_field()->clone;
			my $pos = EPrints::MetaField->new( 
				undef,
				{ 
					name => "pos", 
					type => "int",
				} );
			my @auxfields = ( $keyfield, $pos, $auxfield );
			my $rv = $rv && $self->_create_table_aux(	
				$dataset->get_sql_sub_table_name( $field ),
				$dataset,
				0, # no primary key
				@auxfields );
			next;
		}
		if ( $first )
		{
			$first = 0;
		} 
		else 
		{
			$sql .= ", ";
		}
		my $notnull = 0;
			
		# First field is primary key.
		if( !defined $key && $setkey)
		{
			$key = $field;
			$notnull = 1;
		}
		else
		{
			my( $index ) = $field->get_sql_index();
			if( defined $index )
			{
				$notnull = 1;
				push @indices, $index;
			}
		}
		$sql .= $field->get_sql_type( $notnull );

	}
	if ( $setkey )	
	{
		$sql .= ", PRIMARY KEY (".$key->get_name().")";
	}

	
	foreach (@indices)
	{
		$sql .= ", $_";
	}
	
	$sql .= ");";
	

	# Send to the database
	$rv = $rv && $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
#
# $success = add_record( $dataset, $data )
# boolean                |         Structured Data
#                        EPrints::DataSet     
#
#  Add data to the given table. 
#
######################################################################

## WP1: BAD
sub add_record
{
	my( $self, $dataset, $data ) = @_;

	my $table = $dataset->get_sql_table_name();
	
	my $keyfield = $dataset->get_key_field();

	# To save duplication of code, all this function does is insert
	# a stub entry, then call the update method which does the hard
	# work.

	my $sql = "INSERT INTO ".$dataset->get_sql_table_name()." ";
	$sql   .= " (".$dataset->get_key_field()->get_name().") ";
	$sql   .= "VALUES (\"".
	          prep_value( $data->{$dataset->get_key_field()->get_name()} )."\")";

	# Send to the database
	my $rv = $self->do( $sql );

	# Now add the ACTUAL data:
	$self->update( $dataset , $data );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
#
# $munged = prep_value( $value )
#
# [STATIC]
#  Modify value such that " becomes \" and \ becomes \\ 
#  Returns "" if $value is undefined.
#
######################################################################

## WP1: BAD
sub prep_value
{
	my( $value ) = @_; 
	
	if( !defined $value )
	{
		return "";
	}
	
	$value =~ s/["\\.'%]/\\$&/g;
	return $value;
}

######################################################################
#
# $success = update( $dataset, $data )
# boolean            |         structured data
#                    EPrints::DataSet
#
#  Updates the record described by the $data.  
#
######################################################################

## WP1: BAD
sub update
{
	my( $self, $dataset, $data ) = @_;
	#my( $database_self, $dataset_ds, $struct_md_data ) = @_;

	my $rv = 1;
	my $sql;

	my @fields = $dataset->get_fields();

	my $keyfield = $dataset->get_key_field();

	my $keyvalue = prep_value( $data->{$keyfield->get_name()} );

	# The same WHERE clause will be used a few times, so lets define
	# it now:
	my $where = $keyfield->get_name()." = \"$keyvalue\"";

	my $indextable = $dataset->get_sql_index_table_name();
	$sql = "DELETE FROM $indextable WHERE $where";
	$rv = $rv && $self->do( $sql );

	my @aux;
	my %values = ();
	my $field;
	foreach( @fields ) 
	{
		if( $field->get_property( "multiple" ) ) 
		{ 
			push @aux,$field;
		}
		else 
		{
			# clearout the freetext search index table for this field.

			if( $field->is_type( "name" ) )
			{
				$values{$_->get_name()."_given"} = 
					$data->{$field->get_name()}->{given};
				$values{$_->get_name()."_family"} = 
					$data->{$field->get_name()}->{family};
			}
			else
			{
				$values{$field->get_name()} =
					$data->{$field->get_name()};
			}
			if( $field->is_text_indexable )
			{ 
				$self->_freetext_index( 
					$dataset, 
					$keyvalue, 
					$field, 
					$data->{$field->get_name()} );
			}
		}
	}
	
	$sql = "UPDATE ".$dataset->get_sql_table_name()." SET ";
	my $first=1;
	foreach( keys %values ) {
		if( $first )
		{
			$first = 0;
		}
		else
		{
			$sql.= ", ";
		}
		$sql.= "$_ = \"".prep_value( $values{$_} )."\"";
	}
	$sql.=" WHERE $where";
	
	$rv = $rv && $self->do( $sql );

	# Erase old, and insert new, values into aux-tables.
	my $multifield;
	foreach $multifield ( @aux )
	{
		my $auxtable = $dataset->get_sql_sub_table_name( $multifield );
		$sql = "DELETE FROM $auxtable WHERE $where";
		$rv = $rv && $self->do( $sql );

		# skip to next table if there are no values at all for this
		# one.
		if( !defined $data->{$multifield->get_name()} )
		{
			next;
		}
		my $position=0;
		my $namefield;
		foreach $namefield ( @{$data->{$multifield->get_name()}} )
		{
			$sql = "INSERT INTO $auxtable (".
			       $keyfield->get_name().", pos, ";
			if( $multifield->is_type( "name" ) )
			{
				$sql .= $multifield->get_name()."_given, ";
				$sql .= $multifield->get_name()."_family";
			}
			else
			{
				$sql .= $multifield->get_name();
			}
			$sql .= ") VALUES (\"$keyvalue\",\"$position\", ";
			if( $multifield->is_type( "name" ) )
			{
				$sql .= "\"".prep_value( $namefield->{given} )."\", ";
				$sql .= "\"".prep_value( $namefield->{family} )."\"";
			}
			else
			{
				$sql .= "\"".prep_value( $namefield )."\"";
			}
			$sql.=")";
	                $rv = $rv && $self->do( $sql );

			if( $multifield->is_text_indexable )
			{
				$self->_freetext_index( 
					$dataset, 
					$keyvalue, 
					$multifield, 
					$namefield );
			}

			++$position;
		}
	}
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
#
# $success = remove( $table, $field, $value )
#
#  Attempts to remove a record from $table, where $field=$value.
#  Typically, $field will be the key field and value the ID.
#
######################################################################

## WP1: BAD
sub remove
{
die "remove not fini_cjgshed";# don't forget to prep values
	my( $self, $tableid, $field, $value ) = @_;

	my $table = table_name( $tableid );
	
	my $sql = "DELETE FROM $table WHERE $field LIKE \"$value\";";

	my $rv = $self->do( $sql );

	# Return with an error if unsuccessful
	return( defined $rv )
}


######################################################################
#
# $success = _create_counter_table()
#
#  Creates the counter table.
#
######################################################################

## WP1: BAD
sub _create_counter_table
{
	my( $self ) = @_;

	my $counter_ds = $self->{session}->get_archive()->get_data_set( "counter" );
	
	# The table creation SQL
	my $sql = "CREATE TABLE ".$counter_ds->get_sql_table_name().
		"(countername VARCHAR(255) PRIMARY KEY, counter INT NOT NULL);";
	
	# Send to the database
	my $sth = $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( 0 ) unless defined( $sth );

	my $counter;
	# Create the counters 
	foreach $counter (@EPrints::Database::counters)
	{
		$sql = "INSERT INTO ".$counter_ds->get_sql_table_name()." VALUES ".
			"(\"$counter\", 0);";

		$sth = $self->do( $sql );
		
		# Return with an error if unsuccessful
		return( 0 ) unless defined( $sth );
	}
	
	# Everything OK
	return( 1 );
}

######################################################################
#
# $success = _create_tempmap_table()
#
#  Creates the temporary table map table.
#
######################################################################

## WP1: BAD
sub _create_tempmap_table
{
	my( $self ) = @_;
	
	# The table creation SQL
	my $ds = $self->{session}->get_archive()->get_data_set( "tempmap" );
	my $sql = "CREATE TABLE ".$ds->get_sql_table_name()." ".
		"(tableid INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT, ".
		"created DATETIME NOT NULL)";
	
	# Send to the database
	my $sth = $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( 0 ) unless defined( $sth );

	# Everything OK
	return( 1 );
}


######################################################################
#
# $count = counter_next( $counter )
#
#  Return the next value for the named counter. Returns undef if the
#  counter doesn't exist.
#
######################################################################

## WP1: BAD
sub counter_next
{
	# still not appy with this #cjg (prep values too?)
	my( $self, $counter ) = @_;

	my $ds = $self->{session}->get_archive()->get_data_set( "counter" );

	# Update the counter	
	my $sql = "UPDATE ".$ds->get_sql_table_name()." SET counter=".
		"LAST_INSERT_ID(counter+1) WHERE countername LIKE \"$counter\";";
	
	# Send to the database
	my $rows_affected = $self->do( $sql );

	# Return with an error if unsuccessful
	return( undef ) unless( $rows_affected==1 );

	# Get the value of the counter
	$sql = "SELECT LAST_INSERT_ID();";
	my @row = $self->{dbh}->selectrow_array( $sql );

	return( $row[0] );
}

######################################################################
#
# $cacheid = create_cache( $keyname )
#
######################################################################

## WP1: BAD
sub create_cache
{
	my ( $self , $keyname ) = @_;

	my $sql;

	my $ds = $self->{session}->get_archive()->get_data_set( "tempmap" );
	$sql = "INSERT INTO ".$ds->get_sql_table_name()." VALUES ( NULL , NOW() )";
	
	$self->do( $sql );

	$sql = "SELECT LAST_INSERT_ID()";


	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my ( $id ) = $sth->fetchrow_array;

	my $tmptable  = "cache".$id;

        $sql = "CREATE TABLE $tmptable ".
	       "( $keyname VARCHAR(255) NOT NULL)";

	$self->do( $sql );
	
	return $tmptable;
}



## WP1: BAD
sub create_buffer
{
	my ( $self , $keyname ) = @_;


	my $tmptable = "searchbuffer".($NEXTBUFFER++);

        my $sql = "CREATE TEMPORARY TABLE $tmptable ".
	          "( $keyname VARCHAR(255) NOT NULL, INDEX($keyname))";

	$self->do( $sql );
	
	return $tmptable;
}


######################################################################
#
# $buffer = buffer( $table, $auxtables{}, $conditions)
#
#  perform a search and store the keys of the results in
#  a buffer tmp table.
#
######################################################################

## WP1: BAD
sub _make_select
{
	my( $self, $keyfield, $tables, $conditions ) = @_;
	
	my $sql = "SELECT ".((keys %{$tables})[0]).".".
	          $keyfield->get_name()." FROM ";
	my $first = 1;
	foreach( keys %{$tables} )
	{
		$sql .= " INNER JOIN" unless( $first );
		$sql .= " ${$tables}{$_} AS $_";
		$sql .= " USING (".$keyfield->get_name().")" unless( $first );
		$first = 0;
	}
	if( defined $conditions )
	{
		$sql .= " WHERE $conditions";
	}

	return $sql;
}

## WP1: BAD
sub buffer
{
	my( $self, $keyfield, $tables, $conditions , $orbuffer , $keep ) = @_;

	# can we be REALLY lazy here?
	if( !defined $orbuffer && !$keep && !defined $conditions && scalar(keys %{$tables})==1 ) {
		# We're just going to copy from one table into a brand new one.
		# Might as well just return the ID of the previous table.
		
		return (values %{$tables})[0];
		
	}

	my $sql = $self->_make_select( $keyfield, $tables, $conditions );

	my $targetbuffer;

	if( defined $orbuffer )
	{
		$targetbuffer = $orbuffer;
	} 
	elsif( $keep )
	{
		$targetbuffer = $self->create_cache( $keyfield->get_name() );
	}
	else
	{
		$targetbuffer = $self->create_buffer( $keyfield->get_name() );
	}

	$self->do( "INSERT INTO $targetbuffer $sql" );

	return( $targetbuffer );
}

## WP1: BAD
sub distinct_and_limit
{
	my( $self, $buffer, $keyfield, $max ) = @_;

	my $tmptable = $self->create_buffer( $keyfield->get_name() );

	my $sql = "INSERT INTO $tmptable SELECT DISTINCT ".$keyfield->get_name().
	          " FROM $buffer";

	if( defined $max )
	{
		$sql.= " LIMIT $max";
	}
	$self->do( $sql );

	if( defined $max )
	{
		my $count = $self->count_buffer( $tmptable );
		return( $tmptable , ($count >= $max) );
	}
	else
	{
		return( $tmptable , 0 );
	}
}

## WP1: BAD
sub drop_cache
{
	my ( $self , $tmptable ) = @_;
	# sanity check! Dropping the wrong table could be
	# VERY bad.	
	if ( $tmptable =~ m/^cache(\d+)$/ )
	{
		my $sql;
		my $ds = $self->{session}->get_archive()->get_data_set( "tempmap" );

		$sql = "DELETE FROM ".$ds->get_sql_table_name().
		       " WHERE tableid = $1";

		$self->do( $sql );

        	$sql = "DROP TABLE $tmptable";

		$self->do( $sql );
		
	}
	else
	{
		$self->{session}->get_archive()->log( "Bad Cache ID: $tmptable" );
	}

}

## WP1: BAD
sub count_buffer
{
	my ( $self , $buffer ) = @_;

	my $sql = "SELECT COUNT(*) FROM $buffer";


	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my ( $count ) = $sth->fetchrow_array;

	return $count;
}

## WP1: BAD
sub from_buffer 
{
	my ( $self , $tableid , $buffer ) = @_;
	return $self->_get( $tableid, 1 , $buffer );
}

## WP1: BAD
sub get_single
{
	my ( $self , $tableid , $value ) = @_;
	return ($self->_get( $tableid, 0 , $value ))[0];
}

## WP1: BAD
sub get_all
{
	my ( $self , $tableid ) = @_;
	return $self->_get( $tableid, 2 );
}

## WP1: BAD
sub _get 
{
	my ( $self , $dataset , $mode , $param ) = @_;

	# mode 0 = one or none entries from a given primary key
	# mode 1 = many entries from a buffer table
	# mode 2 = return the whole table (careful now)

	my $table = $dataset->get_sql_table_name();

	my @fields = $dataset->get_fields();

	my $field = undef;
	my $keyfield = $fields[0];
	my $kn = $keyfield->get_name();

	my $cols = "";
	my @aux = ();
	my $first = 1;
	foreach $field (@fields) {
		if ( $field->get_property( "multiple" ) )
		{ 
			push @aux,$field;
		}
		else 
		{
			if ($first)
			{
				$first = 0;
			}
			else
			{
				$cols .= ", ";
			}
			if ( $field->is_type( "name" ) )
			{
				$cols .= "M.".$field->get_name()."_given, ".
				         "M.".$field->get_name()."_family";
			}
			else 
			{
				$cols .= "M.".$field->get_name();
			}
		}
	}
	my $sql;
	if ( $mode == 0 )
	{
		$sql = "SELECT $cols FROM $table AS M ".
		       "WHERE M.$kn = \"".prep_value( $param )."\"";
	}
	elsif ( $mode == 1 )	
	{
		$sql = "SELECT $cols FROM $param AS C, $table AS M ".
		       "WHERE M.$kn = C.$kn";
	}
	elsif ( $mode == 2 )	
	{
		$sql = "SELECT $cols FROM $table AS M";
	}
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my @data = ();
	my @row;
	my %lookup = ();
	my $count = 0;
	while( @row = $sth->fetchrow_array ) 
	{
		my $record = {};
		$lookup{$row[0]} = $count;
		foreach $field ( @fields ) { 
			if( $field->get_property( "multiple" ) )
			{
				$record->{$field->{name}} = [];
			}
			else 
			{
				my $value;
				if( $field->is_type( "name" ) )
				{
					$value = {};
					$value->{given} = shift @row;
					$value->{family} = shift @row;
				} 
				else
				{
					$value = shift @row;
				}
				$record->{$field->get_name()} = $value;
			}
		}
		$data[$count] = $record;
		$count++;
	}

	my $multifield;
	foreach $multifield ( @aux )
	{
		my $mn = $multifield->get_name();
		my $col = "M.$mn";
		if( $multifield->is_type( "name" ) )
		{
			$col = "M.$mn\_given,M.$mn\_family";
		}
		
		if( $mode == 0 )	
		{
			$sql = "SELECT M.$kn, M.pos, $col FROM ";
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
			$sql.= "WHERE M.$kn=\"".prep_value( $param )."\"";
		}
		elsif( $mode == 1)
		{
			$sql = "SELECT M.$kn,M.pos,$col FROM ";
			$sql.= "$param AS C, ";
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
			$sql.= "WHERE M.$kn=C.$kn";
		}	
		elsif( $mode == 2)
		{
			$sql = "SELECT M.$kn,M.pos,$col FROM ";
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
		}
		$sth = $self->prepare( $sql );
		$self->execute( $sth, $sql );
		my ( $id , $pos , @values);
		while( ($id , $pos , @values) = $sth->fetchrow_array ) 
		{
			my $n = $lookup{ $id };
			my $value;
			if( $multifield->is_type( "name" ) )
			{
				$value = {};
				$value->{given} = shift @values;
				$value->{family} = shift @values;
			} 
			else
			{
				$value = shift @values;
			}
			$data[$n]->{$mn}->[$pos] = $value;
		}
	}	

	foreach( @data )
	{
		$_ = $dataset->make_object( $self->{session} ,  $_);
	}

	return @data;
}

## WP1: BAD
sub do 
{
	my ( $self , $sql ) = @_;

	my $result = $self->{dbh}->do( $sql );

	if ( !$result ) {
		print "<pre>--------\n";
		print "dpDBErr:\n";
		print "$sql\n";
		print "----------</pre>\n";
	}
	$self->{session}->get_archive()->log( "Database do debug: $sql" );

	return $result;
}

## WP1: BAD
sub prepare 
{
	my ( $self , $sql ) = @_;

	my $result = $self->{dbh}->prepare( $sql );

	if ( !$result ) {
		print "<pre>--------\n";
		print "prepDBErr:\n";
		print "$sql\n";
		print "----------</pre>\n";
	}

	return $result;
}

## WP1: BAD
sub execute 
{
	my ( $self , $sth , $sql ) = @_;

	my $result = $sth->execute;

	if ( !$result ) {
		print "<pre>--------\n";
		print "execDBErr:\n";
		print "$sql\n";
		print "----------</pre>\n";
	}
	$self->{session}->get_archive()->log( "Database execute debug: $sql" );

	return $result;
}

## WP1: BAD
sub benchmark
{
	my ( $self , $keyfield , $tables , $where ) = @_;

	my $sql = $self->_make_select( $keyfield, $tables, $where );

	$sql= "EXPLAIN $sql";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my @info = $sth->fetchrow_array;

	return $info[6];

}	

## WP1: BAD
sub exists
{
	my( $self, $dataset, $id ) = @_;

	if( !defined $id )
	{
		return undef;
	}
	
	my $keyfield = $dataset->get_key_field();

	my $sql = "SELECT ".$keyfield->get_name().
		" FROM ".$dataset->get_sql_table_name()." WHERE ".
		$keyfield->get_name()." = \"".prep_value( $id )."\";";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );

	if( $sth->fetchrow_array )
	{ 
		return 1;
	}
	return 0;
}

## WP1: BAD
sub _freetext_index
{
	my( $self , $dataset , $id , $field , $value ) = @_;
				# nb. id is already escaped

	my $rv = 1;
	if( !defined $value || $value eq "" )
	{
		return $rv;
	}

	my $keyfield = $dataset->get_key_field();

	my $indextable = $dataset->get_sql_index_table_name();
	
	my( $good , $bad ) = $self->{session}->get_archive()->call( "extract_words" , $value );

	my $sql;
	foreach( @{$good} )
	{
		$sql = "INSERT INTO $indextable ( ".$keyfield->get_name()." , fieldword ) VALUES ";
		$sql.= "( \"$id\" , \"".prep_value($field->get_name().":$_")."\")";
		$rv = $rv && $self->do( $sql );
	} 
	return $rv;
}


## WP1: BAD
sub table_name
{
	my( $tableid ) = @_;
#cjg
EPrints::Session::bomb();
}


1; # For use/require success
