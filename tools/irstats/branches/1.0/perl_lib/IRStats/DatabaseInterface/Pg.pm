package IRStats::DatabaseInterface::Pg;

=head1 NAME

IRStats::DatabaseInterface::Pg - postgres database driver

=head1 METHODS

=over 4

=cut

use strict;

require DBD::Pg;

our @ISA = qw( IRStats::DatabaseInterface );

sub new
{
	my( $class, %self ) = @_;

	my $self = $class->SUPER::new( %self );
	$self->{database}->{pg_enable_utf8} = 1;
	$self->{database}->{ChopBlanks} = 1;

	$self;
}

=item $d->dsn

The database connection string.

=cut

sub dsn
{
	my( $self ) = @_;

	my $conf = $self->{session}->get_conf;

	my $driver   = $conf->database_driver;
	my $server   = $conf->database_server;
	my $port     = $conf->is_set( "database_port" )
		? $conf->database_port : 5432;
	my $database = $conf->database_name;
	my $dsn      = "dbi:$driver:dbname=$database;host=$server;port=$port";

	return $dsn;
}

=item $d->quote_date( COLUMN )

Get a YYYYMMDD value for date column COLUMN.

=cut

sub quote_date
{
	my( $self, $column ) = @_;

	return "to_char($column,'YYYYMMDD')";
}

sub _create_index
{
	my( $self, $unique, $table, @columns ) = @_;

	$unique = $unique ? " UNIQUE " : "";

	my $name = "${table}_".join('_',@columns)."_idx";

	$self->do("CREATE $unique INDEX ".$self->quote_identifier($name)." ON ".$self->quote_identifier($table)." (".join(',',map{$self->quote_identifier($_)}@columns).")");
}

=item $d->check_tables

Checks the main IRStats tables exist and creates them if they don't.

=cut

sub check_tables
{
#checks all irstats tables exists (not set tables)
#creates them if they don't
	my ($self) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;

	my $main_table = $conf->database_main_stats_table;
	my $column_table_prefix = $conf->database_column_table_prefix;
	my @column_table_ids = $conf->database_id_columns;
	my $phrase_table = $conf->database_table_prefix . "phrases";
	my $locks_table = $conf->database_table_prefix . "locks";

	$session->log( "Checking following tables exist: $main_table, ".join(", ",map{"$column_table_prefix$_"}@column_table_ids), 3 );

	my $sql = "CREATE TABLE \"$main_table\" (
				\"accessid\" INT NOT NULL PRIMARY KEY,
				\"datestamp\" DATE NOT NULL,
				\"eprint\" INT NOT NULL,
				\"fulltext\" CHAR(1) NOT NULL,
				\"requester_organisation\" INT default NULL,
				\"requester_host\" INT default NULL,
				\"requester_country\" CHAR(3) default NULL,
				\"referrer_scope\" INT default NULL,
				\"search_engine\" INT default NULL,
				\"search_terms\" INT default NULL,
				\"referring_entity_id\" INT default NULL
					 )";
	unless( $self->has_table($main_table) )
	{
		$self->do($sql);
		$self->_create_index(0,$main_table,"datestamp");
		$self->_create_index(0,$main_table,"requester_host");
		$self->_create_index(0,$main_table,"eprint","datestamp");
		for(qw(search_terms requester_organisation requester_host requester_country referrer_scope search_engine referring_entity_id))
		{
			$self->_create_index(0,$main_table,"datestamp",$_);
		}
	}

	foreach my $column_table_id (@column_table_ids)
	{
		my $column_table_name = $column_table_prefix . $column_table_id;
		my $sql = "CREATE TABLE \"$column_table_name\" (
				\"id\" SERIAL PRIMARY KEY,
				\"value\" CHAR(255)
					)";
		unless( $self->has_table($column_table_name) )
		{
			$self->do($sql);
			$self->_create_index(1,$column_table_name,"value","id");
		}
	}

	unless( $self->has_table($phrase_table) )
	{
		$self->do("CREATE TABLE \"$phrase_table\" (
			\"phrase_id\" CHAR(64) NOT NULL PRIMARY KEY,
			\"phrase\" TEXT
		)");
	}

	unless( $self->has_table($locks_table) )
	{
		$self->do("CREATE TABLE \"$locks_table\" (
			\"lock_id\" CHAR(64) NOT NULL PRIMARY KEY
		)");
	}
}

=item $d->check_set_table( SET_ID [, SUFFIX] )

Check the tables exist for SET_ID and create them if they don't.

=cut

sub check_set_table
{
	my( $self, $set_id, $suffix ) = @_;
	
	my $conf = $self->{session}->get_conf;
	
	$suffix ||= '';

	my $table = $conf->database_set_table_prefix . $set_id . $suffix;
	my $citation_table = $conf->database_set_table_prefix . $set_id . $conf->database_set_table_citation_suffix . $suffix;
	my $code_table = $conf->database_set_table_prefix . $set_id .  $conf->database_set_table_code_suffix . $suffix;

	$self->{session}->log("Checking following tables exist: $table, $citation_table, $code_table", 2);

	$self->do("CREATE TABLE \"$table\" (\"set_member_id\" INT, \"eprint_id\" INT, PRIMARY KEY (\"set_member_id\",\"eprint_id\"))") unless $self->has_table($table);
	$self->do("CREATE TABLE \"$citation_table\" (\"set_member_id\" INT, \"short_citation\" CHAR(255), \"full_citation\" TEXT, \"url\" TEXT, PRIMARY KEY (\"set_member_id\"))") unless $self->has_table($citation_table);
	$self->do("CREATE TABLE \"$code_table\" (\"set_member_code\" VARCHAR(128), \"set_member_id\" INT, PRIMARY KEY (\"set_member_code\"))") unless $self->has_table($code_table);
}

=item $d->check_requester_host_table

Utility method to check the requester_host table has the additional IP column (used by convert_ip_to_host).

=cut

sub check_requester_host_table
{
	my( $self ) = @_;

	my $table = $self->get_conf->database_column_table_prefix . 'requester_host';

	unless( $self->has_table_column( $table, 'ip' ) )
	{
		$self->do( "ALTER TABLE \"$table\" ADD \"ip\" CHAR(255)" );
		$self->do( "CREATE INDEX \"${table}_ip_idx\" ON \"$table\" (\"ip\",\"id\")" );
	}
}

=item $d->rename_tables( OLD_NAME => NEW_NAME [, OLD_NAME => NEW_NAME ] )

Rename tables.

=cut

sub rename_tables
{
	my( $self, @names ) = @_;

	for(my $i = 0; $i < @names; $i += 2)
	{
		$self->do("ALTER TABLE ".$self->quote_identifier($names[$i])." RENAME TO ".$self->quote_identifier($names[$i+1]));
	}
}

=item $d->lock_variable( VARNAME )

Get an exclusive lock on VARNAME, return 0 if VARNAME is already locked by someone else.

=cut

sub lock_variable
{
	my( $self, $var ) = @_;

	my $locks_table = $self->{session}->get_conf->database_table_prefix . "locks";

	$self->{database}->begin_work;

	my $sth = $self->prepare("SELECT 1 FROM $locks_table WHERE lock_id=?");
	$self->execute( $sth, $var );

	if( $sth->fetch )
	{
		return 0;
	}

	$self->do("INSERT INTO $locks_table (lock_id) VALUES (?)",$var);

	$self->{database}->commit;

	return 1;
}

=item $d->unlock_variable( VARNAME )

Release the lock on VARNAME, if one exists.

=cut

sub unlock_variable
{
	my( $self, $var ) = @_;

	my $locks_table = $self->{session}->get_conf->database_table_prefix . "locks";

	$self->do("DELETE FROM $locks_table WHERE lock_id=?", $var);
}

1;

__END__

=back
