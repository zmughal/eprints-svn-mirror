######################################################################
#
# EPrints::Database::Oracle
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

B<EPrints::Database::Oracle> - custom database methods for Oracle DB

=head1 DESCRIPTION

Oracle database wrapper.

=head2 Oracle-specific Annoyances

Oracle will uppercase any identifiers that aren't quoted and is case sensitive, hence mixing quoted and unquoted identifiers will lead to problems.

Oracle does not support LIMIT().

Oracle does not support AUTO_INCREMENT (MySQL) nor SERIAL (Postgres).

Oracle won't ORDER BY LOBS.

=head1 METHODS

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

package EPrints::Database::Oracle;

use EPrints;
use EPrints::Profiler ;

use EPrints::Database qw( :sql_types );
@ISA = qw( EPrints::Database );

# DBD::Oracle seems to not be very good on type_info
our %ORACLE_TYPES = (
	SQL_VARCHAR() => {
		CREATE_PARAMS => "max length",
		TYPE_NAME => "VARCHAR2",
	},
	SQL_LONGVARCHAR() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "CLOB",
	},
	SQL_VARBINARY() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BLOB",
	},
	SQL_LONGVARBINARY() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BLOB",
	},
	SQL_TINYINT() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(3,0)",
	},
	SQL_SMALLINT() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(6,0)",
	},
	SQL_INTEGER() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(*,0)",
	},
	SQL_REAL() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BINARY_FLOAT",
	},
	SQL_DOUBLE() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BINARY_DOUBLE",
	},
	SQL_DATE() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "DATE",
	},
	SQL_TIME() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "DATE",
	},
);

use strict;

sub connect
{
	my( $self ) = @_;

	return unless $self->SUPER::connect();

	$self->{dbh}->{LongReadLen} = 512*1024;
}

sub prepare_select
{
	my( $self, $sql, %options ) = @_;

	if( defined $options{limit} && length($options{limit}) )
	{
		if( defined $options{offset} && length($options{offset}) )
		{
			my $upper = $options{offset} + $options{limit};
			$sql = "SELECT *\n"
				.  "FROM (\n"
				.  "  SELECT /*+ FIRST_ROWS($upper) */ query__.*, ROWNUM rnum__\n"
				.  "  FROM (\n"
				.     $sql ."\n"
				.  "  ) query__\n"
				.  "  WHERE ROWNUM <= $upper)\n"
				.  "WHERE rnum__  > $options{offset}";
		}
		else
		{
			my $upper = $options{limit} + 0;
			$sql = "SELECT /*+ FIRST_ROWS($upper) */ query__.*\n"
				.  "FROM (\n"
				.   $sql ."\n"
				.  ") query__\n"
				.  "WHERE ROWNUM <= $upper";
		}
	}

	return $self->prepare( $sql );
}

sub create_archive_tables
{
	my( $self ) = @_;

	# dual is a 'dummy' table to allow SELECT <function> FROM dual
	if( !$self->has_table( "dual" ) )
	{
		$self->_create_table( "dual", [], ["DUMMY VARCHAR2(1)"] );
		$self->do("INSERT INTO \"dual\" VALUES ('X')");
	}

	return $self->SUPER::create_archive_tables();
}

######################################################################
=pod

=item $version = $db->get_server_version

Return the database server version.

=cut
######################################################################

sub get_server_version
{
	my( $self ) = @_;

	my $sql = "SELECT * from V\$VERSION WHERE BANNER LIKE 'Oracle%'";
	my( $version ) = $self->{dbh}->selectrow_array( $sql );
	return $version;
}

######################################################################
=pod

=item $real_type = $db->get_column_type( NAME, TYPE, NOT_NULL, [, LENGTH ] )

Returns a column definition for NAME of type TYPE. If NOT_NULL is true the column will be created NOT NULL. For column types that require a length use LENGTH.

TYPE is the SQL type. The types are constants defined by this module, to import them use:

  use EPrints::Database qw( :sql_types );

Supported types (n = requires LENGTH argument):

Character data: SQL_VARCHAR(n), SQL_LONGVARCHAR.

Binary data: SQL_VARBINARY(n), SQL_LONGVARBINARY.

Integer data: SQL_TINYINT, SQL_SMALLINT, SQL_INTEGER.

Floating-point data: SQL_REAL, SQL_DOUBLE.

Time data: SQL_DATE, SQL_TIME.

=cut
######################################################################

sub get_column_type
{
	my( $self, $name, $data_type, $not_null, $length, $scale ) = @_;

	my( $db_type, $params ) = (undef, "");

	$db_type = $ORACLE_TYPES{$data_type}->{TYPE_NAME};
	$params = $ORACLE_TYPES{$data_type}->{CREATE_PARAMS};

	my $type = $self->quote_identifier($name) . " " . $db_type;

	$params ||= "";
	if( $params eq "max length" )
	{
		EPrints::abort( "get_sql_type expected LENGTH argument for $data_type [$type]" )
			unless defined $length;
		$type .= "($length)";
	}
	elsif( $params eq "precision,scale" )
	{
		EPrints::abort( "get_sql_type expected PRECISION and SCALE arguments for $data_type [$type]" )
			unless defined $scale;
		$type .= "($length,$scale)";
	}

	if( $not_null )
	{
		$type .= " NOT NULL";
	}

	return $type;
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

	my @tables;

	my $dbuser = $self->{session}->get_repository->get_conf( "dbuser" );
	my $sth = $self->{dbh}->table_info( '%', uc($dbuser), '%', 'TABLE' );

	while(my $row = $sth->fetch)
	{
		my $name = $row->[$sth->{NAME_lc_hash}{table_name}];
		next if $name =~ /\$/;
		push @tables, $name;
	}
	$sth->finish;

	return @tables;
}

######################################################################
=pod

=item $boolean = $db->has_sequence( $name )

Return true if a sequence of the given name exists in the database.

=cut
######################################################################

sub has_sequence
{
	my( $self, $name ) = @_;

	my $sql = "SELECT 1 FROM ALL_SEQUENCES WHERE SEQUENCE_NAME=?";
	my $sth = $self->prepare($sql);
	$sth->execute( uc($name) );

	return $sth->fetch ? 1 : 0;
}

######################################################################
=pod

=item $boolean = $db->has_column( $tablename, $columnname )

Return true if the a table of the given name has a column named $columnname in the database.

=cut
######################################################################

# Default method is really, really slow
sub has_column
{
	my( $self, $table, $column ) = @_;

	my $rc = 0;

	local $self->{dbh}->{RaiseError} = 0;
	local $self->{dbh}->{PrintError} = 0;

	my $sql = "SELECT 1 FROM ".$self->quote_identifier($table)." WHERE ".$self->quote_identifier($column)." is Null";
	my $sth = eval { $self->prepare( $sql ) };
	if( defined $sth )
	{
		$rc = 1;
		$sth->finish;
	}

	return $rc;
}

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
					repository=> $self->{session}->get_repository,
					name => $fname,
					type => "text",
					maxlength => 4000 );
	}
	foreach my $langid ( @{$self->{session}->get_repository->get_conf( "languages" )} )
	{
		my $order_table = $dataset->get_ordervalues_table_name( $langid );

		if( !$self->has_table( $order_table ) )
		{
			$rv &&= $self->create_table( 
				$order_table,
				$dataset, 
				1, 
				@orderfields );
		}
	}

	return $rv;
}

sub _add_field_ordervalues_lang
{
	my( $self, $dataset, $field, $langid ) = @_;

	my $order_table = $dataset->get_ordervalues_table_name( $langid );

	my $sql_field = EPrints::MetaField->new(
		repository => $self->{ session }->get_repository,
		name => $field->get_sql_name(),
		type => "text",
		maxlength => 4000 );

	my $col = $sql_field->get_sql_type( $self->{session}, 0 ); # only first field can not be null

	return $self->do( "ALTER TABLE ".$self->quote_identifier($order_table)." ADD $col" );
}

# Oracle doesn't support getting the "current" value of a sequence
sub counter_current
{
	my( $self, $counter ) = @_;

	return undef;
}

sub drop_table
{
	my( $self, $name ) = @_;

	local $self->{dbh}->{PrintError} = 0;
	local $self->{dbh}->{RaiseError} = 0;

	my $sql = "DROP TABLE ".$self->quote_identifier($name);
	$self->{dbh}->do( $sql );
	$sql = "PURGE TABLE ".$self->quote_identifier($name);
	$self->{dbh}->do( $sql );
}

# Oracle uppercases all non-quoted identifiers so if we want users to be able
# to use unquoted queries we'll have to make all our identifiers uppercase
sub quote_identifier
{
	return shift->SUPER::quote_identifier(map(uc,@_));
}

1; # For use/require success

######################################################################
=pod

=back

=cut

