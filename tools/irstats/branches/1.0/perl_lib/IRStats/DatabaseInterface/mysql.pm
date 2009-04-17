package IRStats::DatabaseInterface::mysql;

use strict;

our @ISA = qw( IRStats::DatabaseInterface );

=head1 NAME

IRStats::DatabaseInterface::mysql - mysql abstraction layer

=head1 METHODS

=over 4

=item $d->dsn

The database connection string.

=cut

sub dsn
{
	my( $self ) = @_;

	my $conf = $self->{session}->get_conf;

	my $driver   = $conf->database_driver;
	my $server   = $conf->database_server;
	my $port     = $conf->is_set( 'database_port' )
		? $conf->database_port : 3306;
	my $database = $conf->database_name;
	my $dsn      = "dbi:$driver:database=$database;host=$server;port=$port";

	return $dsn;
}

=item $d->quote_date( COLUMN )

Get a YYYYMMDD value for date column COLUMN.

=cut

sub quote_date
{
	my( $self, $column ) = @_;

	return "DATE_FORMAT($column,'%Y%m%d')";
}

=item $d->has_table( TABLE )

Returns true if TABLE exists.

=cut

sub has_table
{
	my( $self, $table ) = @_;

	my $sth = $self->do_sql("SHOW TABLES LIKE ".$self->quote($table));

	return defined $sth->fetch;
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
	my $phrases_table = $conf->database_table_prefix . "phrases";

	$session->log( "Checking following tables exist: $main_table, ".join(', ',map{"$column_table_prefix$_"}@column_table_ids), 3 );

	my $sql = "CREATE TABLE IF NOT EXISTS `$main_table` (
				`accessid` int UNSIGNED NOT NULL,
				`datestamp` date NOT NULL,
				`eprint` int UNSIGNED NOT NULL,
				`fulltext` char(1) NOT NULL,
				`requester_organisation` INT UNSIGNED default NULL,
				`requester_host` INT UNSIGNED default NULL,
				`requester_country` CHAR(3) default NULL,
				`referrer_scope` INT UNSIGNED default NULL,
				`search_engine` INT UNSIGNED default NULL,
				`search_terms` INT UNSIGNED default NULL,
				`referring_entity_id` INT UNSIGNED default NULL,
				 PRIMARY KEY (accessid),
				 KEY (datestamp),
				 KEY (eprint,datestamp),
				 KEY (datestamp,search_terms),
				 KEY (datestamp,requester_organisation),
				 KEY (datestamp,requester_host),
				 KEY (requester_host),
				 KEY (datestamp,requester_country),
				 KEY (datestamp,referrer_scope),
				 KEY (datestamp,search_engine),
				 KEY (datestamp,referring_entity_id)
					 )";
	$self->do($sql);

	foreach my $column_table_id (@column_table_ids)
	{
		my $column_table_name = $column_table_prefix . $column_table_id;
		my $sql = "CREATE TABLE IF NOT EXISTS `$column_table_name` (
				`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
				`value` CHAR(255),
				PRIMARY KEY (`id`),
				UNIQUE KEY (`value`,`id`)
					)";
		$self->do($sql);
	}

	unless( $self->has_table( $phrases_table ) )
	{
		my $sql = "CREATE TABLE `$phrases_table` (
			`phrase_id` CHAR(64) NOT NULL PRIMARY KEY,
			`phrase` TEXT
			)";
		$self->do($sql);
	}
}

=item $d->check_set_table( SET_ID [, SUFFIX ] )

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

	$self->do("CREATE TABLE IF NOT EXISTS `$table` (`set_member_id` INT, `eprint_id` INT, PRIMARY KEY (`set_member_id`,`eprint_id`))");
	$self->do("CREATE TABLE IF NOT EXISTS `$citation_table` (`set_member_id` INT, `short_citation` TINYTEXT, `full_citation` TEXT, `url` TEXT, PRIMARY KEY (`set_member_id`))");
	$self->do("CREATE TABLE IF NOT EXISTS `$code_table` (`set_member_code` VARCHAR(128), `set_member_id` INT, PRIMARY KEY (`set_member_code`(128)))");
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
		$self->do( "ALTER TABLE `$table` ADD `ip` CHAR(255), ADD KEY(`ip`,`id`)" );
	}
}

=item $d->rename_tables( OLD_NAME => NEW_NAME [, OLD_NAME => NEW_NAME ] )

Rename tables.

=cut

sub rename_tables
{
	my( $self, @names ) = @_;

	my @pairs;
	for(my $i = 0; $i < @names; $i += 2)
	{
		push @pairs, $self->quote_identifier($names[$i])." TO ".$self->quote_identifier($names[$i+1]);
	}

	my $sql = "RENAME TABLE " . join(",",@pairs);
	$self->do($sql);
}

=item $d->lock_variable( VARNAME )

Get an exclusive lock on VARNAME, return 0 if VARNAME is already locked by someone else.

=cut

sub lock_variable
{
	my( $self, $var ) = @_;

	my $sth = $self->prepare("SELECT GET_LOCK(?,0)");
	$self->execute( $sth, $var );

	my( $r ) = $sth->fetchrow_array;

	return $r;
}

=item $d->unlock_variable( VARNAME )

Release the lock on VARNAME, if we have it.

=cut

sub unlock_variable
{
	my( $self, $var ) = @_;

	$self->do("SELECT RELEASE_LOCK(?)", $var );
}

1;

__END__

=back
