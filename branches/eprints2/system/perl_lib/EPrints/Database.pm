######################################################################
#
# EPrints::Database
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

B<EPrints::Database> - a connection to the SQL database for an eprints
session.

=head1 DESCRIPTION

EPrints Database Access Module

Provides access to the backend database. All database access done
via this module, in the hope that the backend can be replaced
as easily as possible.

Not quite all the SQL is in the module. There is some in EPrints::SearchField,
EPrints::SearchExpression & EPrints::MetaField.

The database object is created automatically when you start a new
eprints session. To get a handle on it use:

$db = $session->get_archive

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{session}
#     The EPrints::Session which is associated with this database 
#     connection.
#
#  $self->{debug}
#     If true then SQL is logged.
#
#  $self->{dbh}
#     The handle on the actual database connection.
#
######################################################################

package EPrints::Database;

use DBI;
use Carp;

#use EPrints::EPrint;
use EPrints::Subscription;

use strict;
my $DEBUG_SQL = 0;

# this may not be the current version of eprints, it's the version
# of eprints where the current desired db configuration became standard.
$EPrints::Database::DBVersion = "2.3.99.3";

# cjg not using transactions so there is a (very small) chance of
# dupping on a counter. 

#
# Counters
#
@EPrints::Database::counters = ( "eprintid", "userid", "subscriptionid","historyid" );


# ID of next buffer table. This can safely reset to zero each time
# The module restarts as it is only used for temporary tables.
#
my $NEXTBUFFER = 0;
my %TEMPTABLES = ();

######################################################################
=pod

=item $dbstr = EPrints::Database::build_connection_string( %params )

Build the string to use to connect to the database via DBI. %params 
must contain dbname, and may also contain dbport, dbhost and dbsock.

=cut
######################################################################

sub build_connection_string
{
	my( %params ) = @_;

        # build the connection string
        my $dsn = "DBI:mysql:database=$params{dbname}";
        if( defined $params{dbhost} )
        {
                $dsn.= ";host=".$params{dbhost};
        }
        if( defined $params{dbport} )
        {
                $dsn.= ";port=".$params{dbport};
        }
        if( defined $params{dbsock} )
        {
                $dsn.= ";mysql_socket=".$params{dbsock};
        }
        return $dsn;
}


######################################################################
=pod

=item $db = EPrints::Database->new( $session )

Create a connection to the database.

=cut
######################################################################

sub new
{
	my( $class , $session) = @_;

	my $self = {};
	bless $self, $class;
	$self->{session} = $session;

	$self->connect;

	if( !defined $self->{dbh} ) { return( undef ); }

	$self->{debug} = $DEBUG_SQL;
	if( $session->{noise} == 3 )
	{
		$self->{debug} = 1;
	}


	return( $self );
}

######################################################################
=pod

=item $foo = $db->connect

Connects to the database. 

=cut
######################################################################

sub connect
{
	my( $self ) = @_;

	# Connect to the database
	$self->{dbh} = DBI->connect( 
		build_connection_string( 
			dbhost => $self->{session}->get_archive()->get_conf("dbhost"),
			dbsock => $self->{session}->get_archive()->get_conf("dbsock"),
			dbport => $self->{session}->get_archive()->get_conf("dbport"),
			dbname => $self->{session}->get_archive()->get_conf("dbname") ),
	        $self->{session}->get_archive()->get_conf("dbuser"),
	        $self->{session}->get_archive()->get_conf("dbpass") );

	return unless defined $self->{dbh};	

	if( $self->{session}->{noise} >= 4 )
	{
		$self->{dbh}->trace( 2 );
	}
}


######################################################################
=pod

=item $foo = $db->disconnect

Disconnects from the EPrints database. Should always be done
before any script exits.

=cut
######################################################################

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
=pod

=item $errstr = $db->error

Return a string describing the last SQL error.

=cut
######################################################################

sub error
{
	my( $self ) = @_;
	
	return $self->{dbh}->errstr;
}


######################################################################
=pod

=item $success = $db->create_archive_tables

Create all the SQL tables for each dataset.

=cut
######################################################################

sub create_archive_tables
{
	my( $self ) = @_;
	
	my $success = 1;

	foreach( &EPrints::DataSet::get_sql_dataset_ids )
	{
		$success = $success && $self->create_dataset_tables( 
			$self->{session}->get_archive()->get_dataset( $_ ) );
	}

	$success = $success && $self->_create_cachemap_table();

	$success = $success && $self->_create_counter_table();

	$success = $success && $self->_create_indexqueue_table();

	$success = $success && $self->_create_permission_table();

	$self->create_version_table;	
	
	$self->set_version( $EPrints::Database::DBVersion );
	
	return( $success );
}
		

######################################################################
=pod

=item $success = $db->create_dataset_tables( $dataset )

Create all the SQL tables for a single dataset.

=cut
######################################################################


sub create_dataset_tables
{
	my( $self, $dataset ) = @_;
	
	my $rv = 1;

	$rv = $rv && $self->create_dataset_index_tables( $dataset );

	$rv = $rv && $self->create_dataset_ordervalues_tables( $dataset );

	# Create the main tables
	$rv = $rv && $self->create_table( 
				$dataset->get_sql_table_name, 
				$dataset, 
				1, 
				$dataset->get_fields( 1 ) );

	return $rv;
}

######################################################################
=pod

=item $success = $db->create_dataset_index_tables( $dataset )

Create all the index tables for a single dataset.

=cut
######################################################################

sub create_dataset_index_tables
{
	my( $self, $dataset ) = @_;
	
	my $rv = 1;

	my $keyfield = $dataset->get_key_field()->clone;

	my $field_fieldword = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "fieldword", 
		type => "text");
	my $field_pos = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "pos", 
		type => "int" );
	my $field_ids = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "ids", 
		type => "longtext");

	$rv = $rv & $self->create_table(
		$dataset->get_sql_index_table_name,
		$dataset,
		0, # no primary key
		( $field_fieldword, $field_pos, $field_ids ) );

	#######################

		
	my $field_fieldname = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "fieldname", 
		type => "text" );
	my $field_grepstring = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "grepstring", 
		type => "text");

	$rv = $rv & $self->create_table(
		$dataset->get_sql_grep_table_name,
		$dataset,
		0, # no primary key
		( $keyfield, $field_fieldname, $field_grepstring ) );


	return 0 unless $rv;
	###########################

	my $field_field = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "field", 
		type => "text" );
	my $field_word = EPrints::MetaField->new( 
		archive=> $self->{session}->get_archive(),
		name => "word", 
		type => "text");

	$rv = $rv & $self->create_table(
		$dataset->get_sql_rindex_table_name,
		$dataset,
		0, # no primary key
		( $keyfield, $field_field, $field_word ) );



	return $rv;
}

######################################################################
=pod

=item $success = $db->create_dataset_ordervalues_tables( $dataset )

Create all the ordervalues tables for a single dataset.

=cut
######################################################################

sub create_dataset_ordervalues_tables
{
	my( $self, $dataset ) = @_;
	
	my $rv = 1;

	my $keyfield = $dataset->get_key_field()->clone;
	# Create sort values table. These will be used when ordering search
	# results.
	my @fields = $dataset->get_fields( 1 );
	# remove the key field
	splice( @fields, 0, 1 ); 
	my @orderfields = ( $keyfield );
	foreach my $field ( @fields )
	{
		my $fname = $field->get_sql_name();
		push @orderfields, EPrints::MetaField->new( 
					archive=> $self->{session}->get_archive(),
					name => $fname,
					type => "longtext" );
	}
	foreach my $langid ( @{$self->{session}->get_archive()->get_conf( "languages" )} )
	{
		my $order_table = $dataset->get_ordervalues_table_name( $langid );

		$rv = $rv && $self->create_table( 
			$order_table,
			$dataset, 
			1, 
			@orderfields );
		return 0 unless $rv;
	}

	return $rv;
}

######################################################################
=pod

=item  $success = $db->create_table( $tablename, $dataset, $setkey, @fields );

Create the tables used to store metadata for this dataset: the main
table and any required for multiple or mulitlang fields.

=cut
######################################################################

sub create_table
{
	my( $self, $tablename, $dataset, $setkey, @fields ) = @_;
	
	my $field;
	my $rv = 1;


	# build the sub-tables first
	foreach $field (@fields)
	{
		next unless ( $field->get_property( "multiple" ) || $field->get_property( "multilang" ) );
		# make an aux. table for a multiple field
		# which will contain the same type as the
		# key of this table paired with the non-
		# multiple version of this field.
		# auxfield and keyfield must be indexed or 
		# there's not much point. 

		my $auxfield = $field->clone;
		$auxfield->set_property( "multiple", 0 );
		$auxfield->set_property( "multilang", 0 );
		my $keyfield = $dataset->get_key_field()->clone;
#print $field->get_name()."\n";
#foreach( keys %{$auxfield} ) { print "* $_ => ".$auxfield->{$_}."\n"; }
#print "\n\n";

		# cjg Hmmmm
		#  Multiple ->
		# [key] [cnt] [field]
		#  Lang ->
		# [key] [lang] [field]
		#  Multiple + Lang ->
		# [key] [pos] [lang] [field]

		my @auxfields = ( $keyfield );
		if ( $field->get_property( "multiple" ) )
		{
			my $pos = EPrints::MetaField->new( 
				archive=> $self->{session}->get_archive(),
				name => "pos", 
				type => "int" );
			push @auxfields,$pos;
		}
		if ( $field->get_property( "multilang" ) )
		{
			my $lang = EPrints::MetaField->new( 
				archive=> $self->{session}->get_archive(),
				name => "lang", 
				type => "langid" );
			push @auxfields,$lang;
		}
		push @auxfields,$auxfield;
		my $rv = $rv && $self->create_table(	
			$dataset->get_sql_sub_table_name( $field ),
			$dataset,
			0, # no primary key
			@auxfields );
	}

	# Construct the SQL statement
	my $sql = "CREATE TABLE $tablename (";
	my $key = undef;
	my @indices;
	my $first = 1;
	foreach $field (@fields)
	{
		next if( $field->get_property( "multiple" ) );
		next if( $field->get_property( "multilang" ) );

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
				push @indices, $index;
			}
		}
		$sql .= $field->get_sql_type( $notnull );

	}
	if ( $setkey )	
	{
		$sql .= ", PRIMARY KEY (".$key->get_sql_name().")";
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
=pod

=item $success = $db->add_record( $dataset, $data )

Add the given data as a new record in the given dataset. $data is
a reference to a hash containing values structured for a record in
the that dataset.

=cut
######################################################################

sub add_record
{
	my( $self, $dataset, $data ) = @_;

	my $table = $dataset->get_sql_table_name();
	
	my $keyfield = $dataset->get_key_field();

	# To save duplication of code, all this function does is insert
	# a stub entry, then call the update method which does the hard
	# work.

	my $sql = "INSERT INTO ".$dataset->get_sql_table_name()." ";
	$sql   .= " (".$dataset->get_key_field()->get_sql_name().") ";
	$sql   .= "VALUES (\"".
	          prep_value( $data->{$dataset->get_key_field()->get_sql_name()} )."\")";

	# Send to the database
	my $rv = $self->do( $sql );

	EPrints::Index::insert_ordervalues( $self->{session}, $dataset, $data );

	# Now add the ACTUAL data:
	$self->update( $dataset , $data );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
=pod

=item $mungedvalue = EPrints::Database::prep_value( $value )

Escape a value for SQL. Modify value such that " becomes \" and \ 
becomes \\ and ' becomes \'

=cut
######################################################################

sub prep_value
{
	my( $value ) = @_; 
	
	return "" unless( defined $value );
	$value =~ s/["\\']/\\$&/g;
	return $value;
}


######################################################################
=pod

=item $mungedvalue = EPrints::Database::prep_like_value( $value )

Escape an value for an SQL like field. In addition to ' " and \ also 
escapes % and _

=cut
######################################################################

sub prep_like_value
{
	my( $value ) = @_; 
	
	return "" unless( defined $value );
	$value =~ s/["\\'%_]/\\$&/g;
	return $value;
}


######################################################################
=pod

=item $success = $db->update( $dataset, $data )

Updates a record in the database with the given $data. Obviously the
value of the primary key must be set.

This also updates the text indexes and the ordering keys.

=cut
######################################################################

sub update
{
	my( $self, $dataset, $data ) = @_;

	my $rv = 1;
	my $sql;
	my @fields = $dataset->get_fields( 1 );

	my $keyfield = $dataset->get_key_field();

	my $keyvalue = prep_value( $data->{$keyfield->get_sql_name()} );

	# The same WHERE clause will be used a few times, so lets define
	# it now:
	my $where = $keyfield->get_sql_name()." = \"$keyvalue\"";

	my @aux;
	my %values = ();
	my $field;
	foreach $field ( @fields ) 
	{
		if( $field->is_type( "secret" ) &&
			!EPrints::Utils::is_set( $data->{$field->get_name()} ) )
		{
			# No way to blank a secret field, as a null value
			# is totally skipped when updating.
			next;
		}
		if( $field->get_property( "multiple" ) || $field->get_property( "multilang" ) ) 
		{ 
			push @aux,$field;
		}
		else 
		{
			my $value = $field->which_bit( $data->{$field->get_name()} );
			my $colname = $field->get_sql_name();
			if( $field->get_property( "idpart" ) )
			{
				$value = $value->{id};
			}
			if( $field->get_property( "mainpart" ) )
			{
				$value = $value->{main};
			}
			# clearout the freetext search index table for this field.

			
			if( $field->is_type( "name" ) )
			{
				$values{$colname."_honourific"} = $value->{honourific};
				$values{$colname."_given"} = $value->{given};
				$values{$colname."_family"} = $value->{family};
				$values{$colname."_lineage"} = $value->{lineage};
			}
			elsif( $field->is_type( "date" ) )
			{
				$values{$colname} = pad_date($value);
				$values{$colname."_resolution"} = $field->get_resolution( $value );
			}
			elsif( $field->is_type( "time" ) )
			{
				# pad time?
				$values{$colname} = $value;
				$values{$colname."_resolution"} = $field->get_resolution( $value );
			}
			else
			{
				$values{$colname} = $value;
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
		$sql.= "$_ = ";
		if( defined $values{$_} ) 
		{
			$sql.= "\"".prep_value( $values{$_} )."\"";
		}
		else
		{
			$sql .= "NULL";
		}
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
		if( !EPrints::Utils::is_set( $data->{$multifield->get_name()} ) )
		{
			next;
		}
		my @values;
		my $fieldvalue = $data->{$multifield->get_name()};

		if( $multifield->get_property( "multiple" ) )
		{
			my $position=0;
			my $pos;
			foreach $pos (0..(scalar @{$fieldvalue}-1) )
			{
				my $value = $multifield->which_bit( $fieldvalue->[$pos] );
				my $incp = 0;
				if( $multifield->get_property( "multilang" ) )
				{
					my $langid;
					foreach $langid ( keys %{$value} )
					{
						my $val = $value->{$langid};
						if( defined $val )
						{
							push @values, {
								v => $val,
								p => $position,
								l => $langid
							};
							$incp=1;
						}
					}
				}
				else
				{
					if( defined $value )
					{
						push @values, {
							v => $value,
							p => $position
						};
						$incp=1;
					}
				}
				$position++ if $incp;
			}
		}
		else
		{
			my $value = $multifield->which_bit( $fieldvalue );
			if( $multifield->get_property( "multilang" ) )
			{
				my $langid;
				foreach $langid ( keys %{$value} )
				{
					my $val = $value->{$langid};
					if( defined $val )
					{
						push @values, { 
							v => $val,
							l => $langid
						};
					}
				}
			}
			else
			{
				die "This can't happen in update!"; #cjg!
			}
		}
					
		my $v;
		foreach $v ( @values )
		{
			my $fname = $multifield->get_sql_name();
			$sql = "INSERT INTO $auxtable (".$keyfield->get_sql_name().", ";
			$sql.= "pos, " if( $multifield->get_property( "multiple" ) );
			$sql.= "lang, " if( $multifield->get_property( "multilang" ) );
			if( $multifield->is_type( "name" ) )
			{
				$sql .= $fname."_honourific, ";
				$sql .= $fname."_given, ";
				$sql .= $fname."_family, ";
				$sql .= $fname."_lineage ";
			}
			elsif( $multifield->is_type( "date", "time" ) )
			{
				$sql .= $fname;
				$sql .= $fname."_resolution";
			}
			else
			{
				$sql .= $fname;
			}
			$sql .= ") VALUES (\"$keyvalue\", ";
			$sql .=	"\"".$v->{p}."\", " if( $multifield->get_property( "multiple" ) );
			$sql .=	"\"".prep_value( $v->{l} )."\", " if( $multifield->get_property( "multilang" ) );
			if( $multifield->is_type( "name" ) )
			{
				$sql .= "\"".prep_value( $v->{v}->{honourific} )."\", ";
				$sql .= "\"".prep_value( $v->{v}->{given} )."\", ";
				$sql .= "\"".prep_value( $v->{v}->{family} )."\", ";
				$sql .= "\"".prep_value( $v->{v}->{lineage} )."\"";
			}
			elsif( $multifield->is_type( "date" ) )
			{
				$sql .= "\"".prep_value( pad_date($v->{v}) )."\"";
				$sql .= "\"".prep_value( $multifield->get_resolution( $v->{v} ) )."\"";
			}
			elsif( $multifield->is_type( "time" ) )
			{
				# maybe need a pad_time method?
				$sql .= "\"".prep_value( $v->{v} )."\"";
				$sql .= "\"".prep_value( $multifield->get_resolution( $v->{v} ) )."\"";
			}
			else
			{
				$sql .= "\"".prep_value( $v->{v} )."\"";
			}
			$sql.=")";
	                $rv = $rv && $self->do( $sql );
		}
	}

	EPrints::Index::update_ordervalues( $self->{session}, $dataset, $data );

	# Return with an error if unsuccessful
	return( defined $rv );
}



######################################################################
=pod

=item $success = $db->remove( $dataset, $id )

Attempts to remove the record with the primary key $id from the 
specified dataset.

=cut
######################################################################

sub remove
{
	my( $self, $dataset, $id ) = @_;

	my $rv=1;

	my $keyfield = $dataset->get_key_field();

	my $keyvalue = prep_value( $id );

	my $where = $keyfield->get_sql_name()." = \"$keyvalue\"";


	# Delete from index (no longer used)
	#$self->_deindex( $dataset, $id );

	# Delete Subtables
	my @fields = $dataset->get_fields( 1 );
	my $field;
	foreach $field ( @fields ) 
	{
		next unless( $field->get_property( "multiple" ) || $field->get_property( "multilang" ) );
		my $auxtable = $dataset->get_sql_sub_table_name( $field );
		my $sql = "DELETE FROM $auxtable WHERE $where";
		$rv = $rv && $self->do( $sql );
	}

	# Delete main table
	my $sql = "DELETE FROM ".$dataset->get_sql_table_name()." WHERE ".$where;
	$rv = $rv && $self->do( $sql );

	if( !$rv )
	{
		$self->{session}->get_archive()->log( "Error removing item id: $id" );
	}

	EPrints::Index::delete_ordervalues( $self->{session}, $dataset, $id );

	# Return with an error if unsuccessful
	return( defined $rv )
}


######################################################################
# 
# $success = $db->_create_counter_table
#
# create the table used to store the highest current id of eprints,
# users etc.
#
######################################################################

sub _create_counter_table
{
	my( $self ) = @_;

	my $counter_ds = $self->{session}->get_archive()->get_dataset( "counter" );
	
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
		$sql = "INSERT INTO ".$counter_ds->get_sql_table_name()." ".
			"VALUES (\"$counter\", 0);";

		$sth = $self->do( $sql );
		
		# Return with an error if unsuccessful
		return( 0 ) unless defined( $sth );
	}
	
	# Everything OK
	return( 1 );
}

######################################################################
# 
# $success = $db->_create_indexqueue_table
#
# create the table used to keep track of what needs to be indexed in
# this archive.
#
######################################################################

sub _create_indexqueue_table
{
	my( $self ) = @_;

	# The table creation SQL
	my $sql = "CREATE TABLE indexqueue ( field VARCHAR(128), added DATETIME , index(field), index(added) )";

	# Send to the database
	my $sth = $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( 0 ) unless defined( $sth );
	
	# Everything OK
	return( 1 );
}

######################################################################
# 
# $success = $db->_create_cachemap_table
#
# create the table which remembers what each cache file represents.
#
######################################################################

sub _create_cachemap_table
{
	my( $self ) = @_;
	
	# The table creation SQL
	my $ds = $self->{session}->get_archive()->get_dataset( "cachemap" );
	my $table_name = $ds->get_sql_table_name();
	my $sql = <<END;
CREATE TABLE $table_name ( 
	tableid INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
	created DATETIME NOT NULL, 
	lastused DATETIME NOT NULL, 
	searchexp TEXT,
	oneshot SET('TRUE','FALSE')
)
END
	
	# Send to the database
	my $sth = $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( 0 ) unless defined( $sth );

	# Everything OK
	return( 1 );
}

######################################################################
# 
# $success = $db->_create_permission_table
#
# create the tables needed to store the permissions. 
#
######################################################################

sub _create_permission_table
{
	my( $self ) = @_;
	my( $sql, $rc );

	$sql = "CREATE TABLE permission (role char(64) not null, privilege char(64) not null, net_from long, net_to long, PRIMARY KEY(role,privilege), UNIQUE(privilege,role))";

	$self->do( $sql ) or return 0;

	$sql = "CREATE TABLE permission_group (user char(64) not null, role char(64) not null, PRIMARY KEY(user,role))";

	$self->do( $sql ) or return 0;

	return 1;
}

#

######################################################################
=pod

=item $n = $db->counter_next( $counter )

Return the next unused value for the named counter. Returns undef if 
the counter doesn't exist.

=cut
######################################################################

sub counter_next
{
	my( $self, $counter ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "counter" );

	# Update the counter	
	my $sql = "UPDATE ".$ds->get_sql_table_name()." SET counter=".
		"LAST_INSERT_ID(counter+1) WHERE countername = \"$counter\";";
	
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
=pod

=item $searchexp = $db->cache_exp( $cacheid )

Return the serialised SearchExpression of a the cached search with
id $cacheid. Return undef if the id is invalid or expired.

=cut
######################################################################

sub cache_exp
{
	my( $self , $id ) = @_;

	my $a = $self->{session}->get_archive();
	my $ds = $a->get_dataset( "cachemap" );

	#cjg NOT escaped!!!
	my $sql = "SELECT searchexp FROM ".$ds->get_sql_table_name() . " WHERE tableid = '$id' ";

	# Never include items past maxlife
	$sql.= " AND created > now()-interval ".$a->get_conf("cache_maxlife")." hour"; 

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my( $searchexp ) = $sth->fetchrow_array;
	$sth->finish;

	return $searchexp;
}





######################################################################
=pod

=item $cacheid = $db->cache( $searchexp, $dataset, $srctable, 
[$order] )

Create a cache of the specified search expression from the SQL table
$srctable.

If $order is set then the cache is ordered by the specified fields. For
example "-year/title" orders by year (descending). Records with the same
year are ordered by title.

=cut
######################################################################

sub cache
{
	my( $self , $code , $dataset , $srctable , $order ) = @_;

	my $sql;
	my $sth;

	# nb. all caches are now oneshot.

	my $ds = $self->{session}->get_archive()->get_dataset( "cachemap" );
	$sql = "INSERT INTO ".$ds->get_sql_table_name()." VALUES ( NULL , NOW(), NOW() , '".prep_value($code)."' , 'TRUE' )";
	
	$self->do( $sql );

	$sql = "SELECT LAST_INSERT_ID()";

	$sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my( $id ) = $sth->fetchrow_array;
	$sth->finish;

	my $keyfield = $dataset->get_key_field();

	my $cache_table  = $self->cache_table( $id );

        $sql = "CREATE TABLE $cache_table ".
		"( pos INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT, ".
		$keyfield->get_sql_type( 1 )." )";
	$self->do( $sql );

	return $id if( $srctable eq "NONE" ); 

	my $keyname = $keyfield->get_name();
	$sql = "INSERT INTO $cache_table SELECT NULL , B.$keyname from ".$srctable." as B";
	if( defined $order )
	{
		$sql .= " LEFT JOIN ".$dataset->get_ordervalues_table_name($self->{session}->get_langid())." AS O";
		$sql .= " ON B.$keyname = O.$keyname ORDER BY ";
		my $first = 1;
		foreach( split( "/", $order ) )
		{
			$sql .= ", " if( !$first );
			my $desc = 0;
			if( s/^-// ) { $desc = 1; }
			my $field = EPrints::Utils::field_from_config_string(
					$dataset,
					$_ );
			$sql .= "O.".$field->get_sql_name();
			$sql .= " DESC" if $desc;
			$first = 0;
		}
	}
	$sth = $self->do( $sql );

	return $id;
}


######################################################################
=pod

=item $tablename = $db->cache_table( $id )

Return the SQL table used to store the cache with id $id.

=cut
######################################################################

sub cache_table
{
	my( $self, $id ) = @_;

	return "cache".$id;
}


######################################################################
=pod

=item $tablename = $db->create_buffer( $keyname )

Create a temporary table with the given keyname. This table will not
be available to other processes and should be disposed of when you've
finished with them - MySQL only allows so many temporary tables.

=cut
######################################################################

sub create_buffer
{
	my ( $self , $keyname ) = @_;

	my $tmptable = "searchbuffer".($NEXTBUFFER++);
	$TEMPTABLES{$tmptable} = 1;
	#print STDERR "Pushed $tmptable onto temporary table list\n";
#cjg VARCHAR!! Should this not be whatever type is bestest?
        my $sql = "CREATE TEMPORARY TABLE $tmptable ".
	          "( $keyname VARCHAR(255) NOT NULL, INDEX($keyname))";

	$self->do( $sql );
		
	return $tmptable;
}


######################################################################
=pod

=item $id = $db->make_buffer( $keyname, $data )

Create a temporary table and dump the values from the array reference
$data into it. 

Even in debugging mode it does not mention this SQL as it's very
dull.

=cut
######################################################################

sub make_buffer
{
	my( $self, $keyname, $data ) = @_;

	my $id = $self->create_buffer( $keyname );

	my $sth = $self->prepare( "INSERT INTO $id VALUES (?)" );
	foreach( @{$data} )
	{
		$sth->execute( $_ );
	}

	return $id;
}


######################################################################
=pod

=item $foo = $db->garbage_collect

Loop through known temporary tables, and remove them.

=cut
######################################################################

sub garbage_collect
{
	my( $self ) = @_;

	foreach( keys %TEMPTABLES )
	{
		$self->dispose_buffer( $_ );
	}
}


######################################################################
=pod

=item $db->dispose_buffer( $id )

Remove temporary table with given id. Won't just remove any
old table.

=cut
######################################################################

sub dispose_buffer
{
	my( $self, $id ) = @_;
	
	unless( defined $TEMPTABLES{$id} )
	{
		$self->{session}->get_archive->log( <<END );
Called dispose_buffer on non-buffer table "$id"
END
		return;
	}
	my $sql = "DROP TABLE $id";
	$self->do( $sql );
	delete $TEMPTABLES{$id};

}
	



######################################################################
=pod

=item $ids = $db->get_index_ids( $table, $condition )

Return a reference to an array of the distinct primary keys from the
given SQL table which match the specified condition.

=cut
######################################################################

sub get_index_ids
{
	my( $self, $table, $condition ) = @_;

	my $sql = "SELECT M.ids FROM $table as M where $condition";

	my $r = {};
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	while( my @info = $sth->fetchrow_array ) {
		my @list = split(":",$info[0]);
		foreach( @list ) { $r->{$_}=1; }
	}
	$sth->finish;
	my $results = [ keys %{$r} ];
	return( $results );
}



######################################################################
=pod

=item $ids = $db->search( $keyfield, $tables, $conditions )

Return a reference to an array of ids - the results of the search
specified by $conditions accross the tables specified in the $tables
hash where keys are tables aliases and values are table names. One
of the keys MUST be "M".

=cut
######################################################################

sub search
{
	my( $self, $keyfield, $tables, $conditions) = @_;
	
	my $sql = "SELECT DISTINCT M.".$keyfield->get_sql_name()." FROM ";
	my $first = 1;
	foreach( keys %{$tables} )
	{
		$sql.= ", " unless($first);
		$first = 0;
		$sql.= $tables->{$_}." AS $_";
	}
	if( defined $conditions )
	{
		$sql .= " WHERE $conditions";
	}

	my $results = [];
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	while( my @info = $sth->fetchrow_array ) {
		push @{$results}, $info[0];
	}
	$sth->finish;
	return( $results );
}




######################################################################
=pod

=item $db->drop_cache( $id )

Remove the cached search with the given id.

=cut
######################################################################

sub drop_cache
{
	my ( $self , $id ) = @_;

	# $id MUST be an integer.
	$id += 0;

	my $tmptable = $self->cache_table( $id );

	my $sql;
	my $ds = $self->{session}->get_archive()->get_dataset( "cachemap" );
	# We drop the table before removing the entry from the cachemap

       	$sql = "DROP TABLE $tmptable";
	$self->do( $sql );
		
	$sql = "DELETE FROM ".$ds->get_sql_table_name()." WHERE tableid = $id";
	$self->do( $sql );
}


######################################################################
=pod

=item $n = $db->count_table( $tablename )

Return the number of rows in the specified SQL table.

=cut
######################################################################

sub count_table
{
	my ( $self , $tablename ) = @_;

	my $sql = "SELECT COUNT(*) FROM $tablename";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my ( $count ) = $sth->fetchrow_array;
	$sth->finish;

	return $count;
}

######################################################################
=pod

=item $items = $db->from_buffer( $dataset, $buffer, [$offset], [$count], [$justids] )

Return a reference to an array containing all the items from the
given dataset that have id's in the specified buffer.

=cut
######################################################################

sub from_buffer 
{
	my ( $self , $dataset , $buffer , $offset, $count, $justids ) = @_;
	return $self->_get( $dataset, 1 , $buffer, $offset, $count );
}



######################################################################
=pod

=item $foo = $db->from_cache( $dataset, $cacheid, [$offset], [$count], [$justids] )

Return a reference to an array containing all the items from the
given dataset that have id's in the specified cache. The cache may be 
specified either by id or serialised search expression. 

$offset is an offset from the start of the cache and $count is the number
of records to return.

If $justids is true then it returns just an ref to an array of the record
ids, not the objects.

=cut
######################################################################

sub from_cache
{
	my( $self , $dataset , $cacheid , $offset , $count , $justids) = @_;

	# Force offset and count to be ints
	$offset+=0;
	$count+=0;

	my @results;
	if( $justids )
	{
		my $keyfield = $dataset->get_key_field();
		my $sql = "SELECT ".$keyfield->get_sql_name()." FROM cache".$cacheid." AS C ";
		$sql.= "WHERE C.pos>$offset ";
		if( $count > 0 )
		{
			$sql.="AND C.pos<=".($offset+$count)." ";
		}
		$sql .= "ORDER BY C.pos";
		my $sth = $self->prepare( $sql );
		$self->execute( $sth, $sql );
		while( my @values = $sth->fetchrow_array ) 
		{
			push @results, $values[0];
		}
		$sth->finish;
	}
	else
	{
		@results = $self->_get( $dataset, 3, "cache".$cacheid, $offset , $count );
	}

	my $ds = $self->{session}->get_archive()->get_dataset( "cachemap" );
	my $sql = "UPDATE ".$ds->get_sql_table_name()." SET lastused = NOW() WHERE tableid = $cacheid";
	$self->do( $sql );

	$self->drop_old_caches();

	return \@results;
}


######################################################################
=pod

=item $db->drop_old_caches

Drop all the expired caches.

=cut
######################################################################

sub drop_old_caches
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "cachemap" );
	my $a = $self->{session}->get_archive();
	my $sql = "SELECT tableid FROM ".$ds->get_sql_table_name()." WHERE";
	$sql.= " (lastused < now()-interval ".($a->get_conf("cache_timeout") + 5)." minute AND oneshot = 'FALSE' )";
	$sql.= " OR created < now()-interval ".$a->get_conf("cache_maxlife")." hour"; 
	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my $id;
	while( $id  = $sth->fetchrow_array() )
	{
		$self->drop_cache( $id );
	}
	$sth->finish;
}



######################################################################
=pod

=item $obj = $db->get_single( $dataset, $id )

Return a single item from the given dataset. The one with the specified
id.

=cut
######################################################################

sub get_single
{
	my ( $self , $dataset , $value ) = @_;
	return ($self->_get( $dataset, 0 , $value ))[0];
}


######################################################################
=pod

=item $items = $db->get_all( $dataset )

Returns a reference to an array with all the items from the given dataset.

=cut
######################################################################

sub get_all
{
	my ( $self , $dataset ) = @_;
	return $self->_get( $dataset, 2 );
}

######################################################################
# 
# $foo = $db->_get ( $dataset, $mode, $param, $offset, $ntoreturn )
#
# Scary generic function to get records from the database and put
# them together.
#
######################################################################

sub _get 
{
	my ( $self , $dataset , $mode , $param, $offset, $ntoreturn ) = @_;

	# debug code.
	if( !defined $dataset || ref($dataset) eq "") { confess(); }

	# mode 0 = one or none entries from a given primary key
	# mode 1 = many entries from a buffer table
	# mode 2 = return the whole table (careful now)
	# mode 3 = some entries from a cache table

	my $table = $dataset->get_sql_table_name();

	my @fields = $dataset->get_fields( 1 );

	my $field = undef;
	my $keyfield = $fields[0];
	my $kn = $keyfield->get_sql_name();

	my $cols = "";
	my @aux = ();
	my $first = 1;
	foreach $field ( @fields ) {
		if( $field->is_type( "secret" ) )
		{
			# We don't return the values of secret fields - 
			# much more secure that way. The password field is
			# accessed direct via SQL.
			next;
		}
		if( $field->get_property( "multiple" ) || $field->get_property( "multilang" ) )
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
			my $fname = $field->get_sql_name();
			if ( $field->is_type( "name" ) )
			{
				$cols .= "M.".$fname."_honourific, ".
				         "M.".$fname."_given, ".
				         "M.".$fname."_family, ".
				         "M.".$fname."_lineage";
			}
			elsif( $field->is_type( "date", "time" ) )
			{
				$cols .= "M.".$fname.", ".
				         "M.".$fname."_resolution";
			}
			else 
			{
				$cols .= "M.".$fname;
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
	elsif ( $mode == 3 )	
	{
		$sql = "SELECT $cols, C.pos FROM $param AS C, $table AS M ";
		$sql.= "WHERE M.$kn = C.$kn AND C.pos>$offset ";
		if( $ntoreturn > 0 )
		{
			$sql.="AND C.pos<=".($offset+$ntoreturn)." ";
		}
		$sql .= "ORDER BY C.pos";
		#print STDERR "$sql\n";
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
			if( $field->is_type( "secret" ) )
			{
				next;
			}
			if( $field->get_property( "multiple" ) )
			{
				#cjg Maybe should do nothing.
				$record->{$field->get_name()} = [];
			}
			elsif( $field->get_property( "multilang" ) )
			{
				# Do Nothing
			}
			else 
			{
				my $value;
				if( $field->is_type( "name" ) )
				{
					$value = {};
					$value->{honourific} = shift @row;
					$value->{given} = shift @row;
					$value->{family} = shift @row;
					$value->{lineage} = shift @row;
				} 
				elsif( $field->is_type( "date", "time" ) )
				{
					my $v = shift @row;
					my $res = shift @row;
					$value = $field->trim_date( $v, $res );
				}
				else
				{
					$value = shift @row;
				}

				if( $field->get_property( "mainpart" ) )
				{
					$record->{$field->get_name()}->{main} = $value;
				}
				elsif( $field->get_property( "idpart" ) )
				{
					$record->{$field->get_name()}->{id} = $value;
				}
				else
				{
					$record->{$field->get_name()} = $value;
				}
			}
		}
		$data[$count] = $record;
		$count++;
	}
	$sth->finish;

	my $multifield;
	foreach $multifield ( @aux )
	{
		my $mn = $multifield->get_sql_name();
		my $fn = $multifield->get_name();
		my $col = "M.$mn";
		if( $multifield->is_type( "name" ) )
		{
			$col = "M.$mn\_honourific,M.$mn\_given,M.$mn\_family,M.$mn\_lineage";
		}
		elsif( $multifield->is_type( "date", "time" ) )
		{
			$col = "M.$mn,M.$mn\_resolution";
		}
		my $fields_sql = "M.$kn, ";
		$fields_sql .= "M.pos, " if( $multifield->get_property( "multiple" ) );
		$fields_sql .= "M.lang, " if( $multifield->get_property( "multilang" ) );
		$fields_sql .= $col;		
		if( $mode == 0 )	
		{
			$sql = "SELECT $fields_sql FROM ";
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
			$sql.= "WHERE M.$kn=\"".prep_value( $param )."\"";
		}
		elsif( $mode == 1)
		{
			$sql = "SELECT $fields_sql FROM ";
			$sql.= "$param AS C, ";
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
			$sql.= "WHERE M.$kn=C.$kn";
		}	
		elsif( $mode == 2)
		{
			$sql = "SELECT $fields_sql FROM ";
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
		}
		elsif ( $mode == 3 )	
		{
			$sql = "SELECT $fields_sql, C.pos FROM $param AS C, "; 
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
			$sql.= "WHERE M.$kn = C.$kn AND C.pos>$offset ";
			if( $ntoreturn > 0 )
			{
				$sql.="AND C.pos<=".($offset+$ntoreturn)." ";
			}
			$sql .= "ORDER BY C.pos";
		}
		$sth = $self->prepare( $sql );
		$self->execute( $sth, $sql );
		while( my @values = $sth->fetchrow_array ) 
		{
			my $id = shift( @values );
			my( $pos, $lang );
			$pos = shift( @values ) if( $multifield->get_property( "multiple" ) );
			$lang = shift( @values ) if( $multifield->get_property( "multilang" ) );
			my $n = $lookup{ $id };
			my $value;
			if( $multifield->is_type( "name" ) )
			{
				$value = {};
				$value->{honourific} = shift @values;
				$value->{given} = shift @values;
				$value->{family} = shift @values;
				$value->{lineage} = shift @values;
			} 
			elsif( $multifield->is_type( "date", "time" ) )
			{
				my $v = shift @values;
				my $res = shift @values;
				$value = $multifield->trim_date( $v, $res );
			}
			else
			{
				$value = shift @values;
			}

			my $subbit;
			$subbit = "id" if( $multifield->get_property( "idpart" ) );
			$subbit = "main" if( $multifield->get_property( "mainpart" ) );

			if( $multifield->get_property( "multiple" ) )
			{
				if( $multifield->get_property( "multilang" ) )
				{
					if( defined $subbit )
					{
						$data[$n]->{$fn}->[$pos]->{$subbit}->{$lang} = $value;
					}
					else
					{
						$data[$n]->{$fn}->[$pos]->{$lang} = $value;
					}
				}
				else
				{
					if( defined $subbit )
					{
						$data[$n]->{$fn}->[$pos]->{$subbit} = $value;
					}
					else
					{
						$data[$n]->{$fn}->[$pos] = $value;
					}
				}
			}
			else
			{
				if( $multifield->get_property( "multilang" ) )
				{
					if( defined $subbit )
					{
						$data[$n]->{$fn}->{$subbit}->{$lang} = $value;
					}
					else
					{

						$data[$n]->{$fn}->{$lang} = $value;
					}
				}
				else
				{
					print STDERR "This cannot happen!\n";#cjg!
				}
			}
		}
		$sth->finish;
	}	

	foreach( @data )
	{
		$_ = $dataset->make_object( $self->{session} ,  $_);
	}

	return @data;
}


######################################################################
=pod

=item $foo = $db->get_values( $field, $dataset )

Return a reference to an array of all the distinct values of the 
EPrints::MetaField specified.

=cut
######################################################################

sub get_values
{
	my( $self, $field, $dataset ) = @_;

	my $table;
	if ( $field->get_property( "multiple" ) || $field->get_property( "multilang" ) )
	{
		$table = $dataset->get_sql_sub_table_name( $field );
	} 
	else 
	{
		$table = $dataset->get_sql_table_name();
	}
	my $fn = $field->get_sql_name();
	if( $field->is_type( "name" ) )
	{
		$fn = "$fn\_honourific,$fn\_given,$fn\_family,$fn\_lineage";
	}
	elsif( $field->is_type( "date", "time" ) )
	{
		$fn = "$fn,$fn\_resolution";
	}
	my $sql = "SELECT DISTINCT $fn FROM $table";
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my @values = ();
	my @row = ();
	while( @row = $sth->fetchrow_array ) 
	{
		if( $field->is_type( "name" ) )
		{
			my $value = {};
			$value->{honourific} = shift @row;
			$value->{given} = shift @row;
			$value->{family} = shift @row;
			$value->{lineage} = shift @row;
			push @values, $value;
		}
		elsif( $field->is_type( "date", "time" ) )
		{
			my $v = shift @row;
			my $res = shift @row;
			push @values, $field->trim_date( $v, $res );
		}
		else
		{
			push @values, $row[0];
		}
	}
	$sth->finish;
	return \@values;
}



######################################################################
=pod

=item $success = $db->do( $sql )

Execute the given SQL.

=cut
######################################################################

sub do 
{
	my( $self , $sql ) = @_;

	my $adjust_fn = $self->{session}->get_archive->get_conf( 'sql_adjust' );
	if( defined $adjust_fn )
	{
		$sql = &{$adjust_fn}( $sql );
	}
	if( $self->{debug} )
	{
		$self->{session}->get_archive()->log( "Database execute debug: $sql" );
	}
	my $result = $self->{dbh}->do( $sql );
	if( !$result )
	{
		$self->{session}->get_archive()->log( "SQL ERROR (do): $sql" );
		$self->{session}->get_archive()->log( "SQL ERROR (do): ".$self->{dbh}->errstr.' (#'.$self->{dbh}->err.')' );

		return undef unless( $self->{dbh}->err == 2006 );

		my $ccount = 0;
		while( $ccount < 10 )
		{
			++$ccount;
			sleep 3;
			$self->{session}->get_archive()->log( "Attempting DB reconnect: $ccount" );
			$self->connect;
			if( defined $self->{dbh} )
			{
				$result = $self->{dbh}->do( $sql );
				return $result if( defined $result );
				$self->{session}->get_archive()->log( "SQL ERROR (do): ".$self->{dbh}->errstr );
			}
		}
		$self->{session}->get_archive()->log( "Giving up after 10 tries" );
		return undef;
	}

	return $result;
}


######################################################################
=pod

=item $sth = $db->prepare( $sql )

Prepare the given $sql and return a handle on it.

=cut
######################################################################

sub prepare 
{
	my ( $self , $sql ) = @_;

	my $adjust_fn = $self->{session}->get_archive->get_conf( 'sql_adjust' );
	if( defined $adjust_fn )
	{
		$sql = &{$adjust_fn}( $sql );
	}
#	if( $self->{debug} )
#	{
#		$self->{session}->get_archive()->log( "Database prepare debug: $sql" );
#	}

	my $result = $self->{dbh}->prepare( $sql );
	my $ccount = 0;
	if( !$result )
	{
		$self->{session}->get_archive()->log( "SQL ERROR (prepare): $sql" );
		$self->{session}->get_archive()->log( "SQL ERROR (prepare): ".$self->{dbh}->errstr.' (#'.$self->{dbh}->err.')' );

		return undef unless( $self->{dbh}->err == 2006 );

		my $ccount = 0;
		while( $ccount < 10 )
		{
			++$ccount;
			sleep 3;
			$self->{session}->get_archive()->log( "Attempting DB reconnect: $ccount" );
			$self->connect;
			if( defined $self->{dbh} )
			{
				$result = $self->{dbh}->prepare( $sql );
				return $result if( defined $result );
				$self->{session}->get_archive()->log( "SQL ERROR (prepare): ".$self->{dbh}->errstr );
			}
		}
		$self->{session}->get_archive()->log( "Giving up after 10 tries" );
		return undef;
	}

	return $result;
}


######################################################################
=pod

=item $success = $db->execute( $sth, $sql )

Execute the SQL prepared earlier. $sql is only passed in for debugging
purposes.

=cut
######################################################################

sub execute 
{
	my( $self , $sth , $sql ) = @_;

	if( $self->{debug} )
	{
		$self->{session}->get_archive()->log( "Database execute debug: $sql" );
	}

	my $result = $sth->execute;
	while( !$result )
	{
		$self->{session}->get_archive()->log( "SQL ERROR (execute): $sql" );
		$self->{session}->get_archive()->log( "SQL ERROR (execute): ".$self->{dbh}->errstr );
		return undef;
	}

	return $result;
}



######################################################################
=pod

=item $boolean = $db->exists( $dataset, $id )

Return true if a record with the given primary key exists in the
dataset, otherwise false.

=cut
######################################################################

sub exists
{
	my( $self, $dataset, $id ) = @_;

	if( !defined $id )
	{
		return undef;
	}
	
	my $keyfield = $dataset->get_key_field();

	my $sql = "SELECT ".$keyfield->get_sql_name().
		" FROM ".$dataset->get_sql_table_name()." WHERE ".
		$keyfield->get_sql_name()." = \"".prep_value( $id )."\";";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my $result = $sth->fetchrow_array;
	$sth->finish;
	return 1 if( $result );
	return 0;
}



######################################################################
=pod

=item $db->set_debug( $boolean )

Set the SQL debug mode to true or false.

=cut
######################################################################

sub set_debug
{
	my( $self, $debug ) = @_;

	$self->{debug} = $debug;
}

######################################################################
=pod

=item $db->create_version_table

Make the version table (and set the only value to be the current
version of eprints).

=cut
######################################################################

sub create_version_table
{
	my( $self ) = @_;

	my $sql;

	$sql = "CREATE TABLE version ( version VARCHAR(255) )";
	$self->do( $sql );

	$sql = "INSERT INTO version ( version ) VALUES ( NULL )";
	$self->do( $sql );

}

######################################################################
=pod

=item $db->set_version( $versionid );

Set the version id table in the SQL database to the given value
(used by the upgrade script).

=cut
######################################################################

sub set_version
{
	my( $self, $versionid ) = @_;

	my $sql;

	$sql = "UPDATE version SET version = '".
		prep_value( $versionid )."'";
	$self->do( $sql );

	if( $self->{session}->get_noise >= 1 )
	{
		print "Set DB compatibility flag to '$versionid'.\n";
	}
}

######################################################################
=pod

=item $boolean = $db->has_table( $tablename )

Return true if the a table of the given name exists in the database.

=cut
######################################################################

sub has_table
{
	my( $self, $tablename ) = @_;

	my $sql = "SHOW TABLES";
	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my @row;
	my $result = 0;
	while( @row = $sth->fetchrow_array )
	{
		if( $row[0] eq $tablename )
		{
			$result = 1;
			last;
		}
	}
	$sth->finish;
	return $result;
}

######################################################################
=pod

=item $db->install_table( $tablename, $newtablename )

Move table $tablename to $newtablename. Erase $newtablename if it
exists.

=cut
######################################################################

sub install_table
{
	my( $self, $current_pos, $target_pos ) = @_;

	if( $self->has_table( $target_pos ) )
	{
		$self->swap_tables( 
			$current_pos,
			$target_pos );
		$self->drop_table( $current_pos );
		return;
	}

	$self->rename_table( 
		$current_pos,
		$target_pos );
}
		
######################################################################
=pod

=item $db->drop_table( $tablename )

Delete the named table. Use with caution!

=cut
######################################################################
	
sub drop_table
{
	my( $self, $tablename ) = @_;

	my $sql = "DROP TABLE ".$tablename;
	$self->do( $sql );
}

######################################################################
=pod

=item $db->rename_table( $tablename, $newtablename )

Renames the table from the old name to the new one.

=cut
######################################################################

sub rename_table
{
	my( $self, $table_from, $table_to ) = @_;

	my $sql = "RENAME TABLE $table_from TO $table_to";
	$self->do( $sql );
}

######################################################################
=pod

=item $db->has_table( $table_a, $table_b )

Swap table a and table b. 

=cut
######################################################################

sub swap_tables
{
	my( $self, $table_a, $table_b ) = @_;

	my $tmp = $table_a.'_swap';
	my $sql = "RENAME TABLE $table_a TO $tmp, $table_b TO $table_a, $tmp TO $table_b";
	$self->do( $sql );
}

######################################################################
=pod

=item @tables = $db->get_tables

Return a list of all the tables in the database.

=cut
######################################################################

sub get_tables
{
	my( $self ) = @_;

	my $sql = "SHOW TABLES";
	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my @row;
	my @list = ();
	while( @row = $sth->fetchrow_array )
	{
		push @list, $row[0];
	}
	$sth->finish;

	return @list;
}


######################################################################
=pod

=item $version = $db->get_version

Return the version of eprints which the database is compatable with
or undef if unknown (before v2.1).

=cut
######################################################################

sub get_version
{
	my( $self ) = @_;

	return undef unless $self->has_table( "version" );

	my $sql = "SELECT version FROM version;";
	my @row = $self->{dbh}->selectrow_array( $sql );

	return( $row[0] );
}

######################################################################
=pod

=item $boolean = $db->is_latest_version

Return true if the SQL tables are in the correct configuration for
this edition of eprints. Otherwise false.

=cut
######################################################################

sub is_latest_version
{
	my( $self ) = @_;

	my $version = $self->get_version;
	return 0 unless( defined $version );

	return $version eq $EPrints::Database::DBVersion;
}


######################################################################
=pod

=item $mysql_date = EPrints::Database::pad_date( $date, [$inc] )

Inverse of trim date. Pads a date string with 00's if it only
has a year, or a year and month.

If $inc is true then increment the date by the resolution of the date
so 2000 becomes 2001-00-00 and 2002-04-00 becomes 2002-05-00 etc.

(does not increment day-res fields)

=cut
######################################################################

sub pad_date
{
	my( $date, $inc ) = @_;

	if( !EPrints::Utils::is_set( $date ) )
	{
		return undef;
	}

	my( $y, $m, $d ) = split( /-/, $date );

	if( $inc )
	{
		if( !defined $d )
		{
			if( !defined $m )
			{
				$y++;
			}
			else
			{
				$m++;	
				if( $m == 13 )
				{
					$m = 1;
					$y ++;
				}
			}
		}
	}
	$m = 0 if( !defined $m );
	$d = 0 if( !defined $d );
	

	return sprintf("%04d-%02d-%02d",$y,$m,$d);
}

######################################################################
=pod

=item $version = $db->mysql_version;

Return the mysql version in the format 
major * 10000 + minor * 100 + sub_version

=cut
######################################################################

sub mysql_version
{
	my( $self ) = @_;

	return mysql_version_from_dbh( $self->{dbh} );
}

sub mysql_version_from_dbh
{
	my( $dbh ) = @_;
	my $sql = "SELECT VERSION();";
	my( $version ) = $dbh->selectrow_array( $sql );
	$version =~ m/^(\d+).(\d+).(\d+)/;
	return $1*10000+$2*100+$3;
}

######################################################################
=pod

=item $db->index_queue( $datasetid, $objectid, $fieldname );

Queues the field of the specified object to be reindexed.

=cut
######################################################################

sub index_queue
{
	my( $self, $datasetid, $objectid, $fieldname ) = @_; 

	my $sql = "INSERT INTO indexqueue VALUES ( \"$datasetid.$objectid.$fieldname\", NOW() )";
	$self->do( $sql );
}

######################################################################
=pod

=back

=head2 Permissions

=over 4

=item $db->add_roles( $privilege, $ip_from, $ip_to, @roles )

Add $privilege to @roles, optionally in net space $ip_from to $ip_to.

If $privilege begins with '@' adds @roles to that group.

=cut
######################################################################

sub add_roles
{
	my( $self, $priv, $ip_f, $ip_t, @roles ) = @_;
	my $sql;

	# Adding users to groups
	if( $priv =~ /^\@/ ) {
		foreach my $role (@roles)
		{
			$self->do(
				"REPLACE permission_group (user,role) VALUES ('" .
					prep_value( $role ) . "','" .
					prep_value( $priv ) . "')"
			);
		}
	}
	# Adding privileges to roles
	else
	{
		# Convert quad-dotted to long to allow easy lookup
		$ip_f = $ip_f ? EPrints::Utils::ip2long( $ip_f ) : "null";
		$ip_t = $ip_t ? EPrints::Utils::ip2long( $ip_t ) : "null";

		foreach my $role (@roles)
		{
			$self->do(
				"REPLACE permission (role,privilege,net_from,net_to) VALUES ('" .
					prep_value( $role ) . "','" .
					prep_value( $priv ) . "'," .
					$ip_f . "," .
					$ip_t . ")"
			);
		}
	}

	return scalar(@roles);
}

######################################################################
=pod

=item $db->remove_roles( $privilege, $ip_from, $ip_to, @roles )

Remove $privilege from @roles, $ip_from and $ip_to are currently ignored, but this behaviour may change in future.

If $privilege beings with '@' removes @roles from that group instead.

=cut
######################################################################

sub remove_roles
{
	my( $self, $priv, $ip_f, $ip_t, @roles ) = @_;
	my $sql;

	if( $priv =~ /^\@/ )
	{
		foreach my $role (@roles)
		{
			$self->do(
				"DELETE FROM permission_group WHERE " .
					"user='" . prep_value( $role ) . "' AND ".
					"role='" . prep_value( $priv ) . "'"
			);
		}
	}
	else
	{
		foreach my $role (@roles)
		{
			$self->do(
				"DELETE FROM permission WHERE " .
					"role='" . prep_value( $role ) . "' AND ".
					"privilege='" . prep_value( $priv ) . "'"
			);
		}
	}

	return scalar( @roles );
}

######################################################################
=pod

=item %privs = $db->get_privileges( [$role] )

Return the privileges granted for $role. If $role is undefined returns all set privileges.

Returns a hash:

	role => {
		priv1 => [ ip_from, ip_to ],
		priv2 => [ ip_from, ip_to ],
	}

=cut
######################################################################

sub get_privileges
{
	my( $self, $role ) = @_;
	my( %privs, $sth, $sql );

	$sql = "SELECT role,privilege,net_from,net_to FROM permission";
	if( defined( $role ) ) {
		$sql .= " WHERE role='" . prep_value( $role ) . "'";
	}
	$sth = $self->prepare( $sql );
	$self->execute( $sth, $sql ) or return;
	while( my ($r,$priv,$ip_from,$ip_to) = $sth->fetchrow_array )
	{
		$ip_from = EPrints::Utils::long2ip( $ip_from ) if defined($ip_from);
		$ip_to = EPrints::Utils::long2ip( $ip_to ) if defined($ip_to);
		$privs{$r}->{$priv} = [$ip_from, $ip_to];
	}

	return %privs;
}

######################################################################
=pod

=item %groups = $db->get_groups( [$role] )

Returns a list of groups that $role belongs to, or all groups if $role is undefined.

Returns a hash:

	role => [ group1, group2, group3 ]

=cut
######################################################################

sub get_groups
{
	my( $self, $role ) = @_;
	my( %groups, $sth, $sql );

	$sql = "SELECT user,role FROM permission_group";
	if( defined( $role ) ) {
		$sql .= " WHERE user='" . prep_value( $role ) . "'";
	}
	$sth = $self->prepare( $sql );
	$self->execute( $sth, $sql ) or return;
	while( my ($user,$r) = $sth->fetchrow_array )
	{
		push @{$groups{$user}}, $r;
	}

	return %groups;
}

######################################################################
=pod

=item @roles = $db->get_roles( $privilege, $remote_ip, @roles )

Get the matching roles for @roles that have $privilege, optionally restricted to $remote_ip.

=cut
######################################################################

sub get_roles
{
	my ( $self, $priv, $ip, @roles ) = @_;
	my ( @permitted_roles, $sth, $sql, @clauses );

	# Standard WHERE clauses
	if( $priv =~ s/\.\*$// ) {
		push @clauses, "privilege like '" . prep_value( $priv ) . "\%'";
	} else {
		push @clauses, "privilege = '" . prep_value( $priv ) . "'";
	}
	if( defined( $ip ) )
	{
		my $longip = EPrints::Util::ip2long( $ip );
		push @clauses, "(net_from is Null OR ($longip >= net_from AND $longip <= net_to))";
	}

	# Get roles from the permissions table
	$sql = "SELECT role FROM permission WHERE ";
	$sql .= join(
		" AND ",
		@clauses,
		"(" . join(' OR ', map { "role = '" . prep_value( $_ ) . "'" } @roles) . ")"
	);
	
	# Provide a generic privilege query
	$sth = $self->prepare( $sql );
	$self->execute( $sth, $sql ) or return;
	while( my ($role) = $sth->fetchrow_array )
	{
		push @permitted_roles, $role;
	}

	# Get roles inherited from group membership
	$sql = "SELECT G.role FROM permission_group AS G, permission AS P WHERE ";
	$sql .= join(
		 " AND ",
		 "G.role=P.role",
		@clauses,
		"(" . join(' OR ', map { "G.role = '" . prep_value( $_ ) . "'" } @roles) . ")"
	);
	
	$sth = $self->prepare( $sql );
	$self->execute( $sth, $sql ) or return;
	while( my ($role) = $sth->fetchrow_array )
	{
		push @permitted_roles, $role;
	}

	return @permitted_roles;
}

1; # For use/require success

######################################################################
=pod

=back

=cut

