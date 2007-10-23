package IRStats::DatabaseInterface;

use strict;

use DBI;
use Data::Dumper;

=head1 NAME

IRStats::DatabaseInterface - Interface to the IRstats database

=head1 METHODS

=over 4

=cut

=item IRstats::DatabaseInterface->new( session => SESSION )

Connect to the database using SESSION.

=cut

sub new
{
	my ($class, %self) = @_;
	Carp::croak "Requires session argument" unless $self{session};
	my $conf = $self{conf} = $self{session}->get_conf;

	my $driver   = $conf->database_driver;
	my $server   = $conf->get_value('database_server');
	my $database = $conf->get_value('database_name');
	my $url      = "DBI:$driver:$database:$server";
	my $user     = $conf->get_value('database_user');
	my $password = $conf->get_value('database_password');
	my $source_table = $conf->get_value('database_main_stats_table');
	my $dbh = DBI->connect( $url, $user, $password ) or Carp::confess "Could not connect to database $url!\n";
	my $id_columns =  $conf->get_value('database_id_columns');

	@self{qw(
		database
		source_table
		id_columns
	)} = (
		$dbh,
		$source_table,
		$id_columns,
	);

	my $self = bless \%self, $class;
	@{$self->{sets}} = $conf->set_ids;
	unshift @{$self->{sets}}, 'eprint'; # fake set?

	return $self;
}

=item $d->get_max_accessid

Returns the highest accessid currently set, or undef if there are no records.

=cut

sub get_max_accessid
{
	my( $self ) = @_;
	my $table = $self->{conf}->database_main_stats_table;

	my $sql = "SELECT MAX(`accessid`) FROM `$table`";
	my $query = $self->do_sql($sql);
	my( $max ) = $query->fetchrow_array;
	return $max;
}

=item $d->get_id( CODE, SET )

Returns the id of a code for a given set.

=cut

sub get_id
{
	my ($self, $code, $set_id) = @_;
	my $code_table = $self->{conf}->get_value('database_set_table_prefix') . $set_id .  $self->{conf}->get_value('database_set_table_code_suffix');

	my $query = $self->do_sql("SELECT set_member_id FROM $code_table WHERE set_member_code = '$code'");
	if (not $query->rows()) { return "ERR"; }

	my $row = $query->fetchrow_arrayref();
	return $row->[0];
}

=item $d->get_code( ID, SET )

Returns the code for an ID in a given set.

=cut

sub get_code
{
	my ($self, $id, $set_id) = @_;
	my $code_table = $self->{conf}->get_value('database_set_table_prefix') . $set_id .  $self->{conf}->get_value('database_set_table_code_suffix');

	my $query = $self->do_sql("SELECT set_member_code FROM $code_table WHERE set_member_id = $id");
	if (not $query->rows()) { return "ERR"; }

	my $row = $query->fetchrow_arrayref();
	return $row->[0];
}

=item $d->get_all_sets_ids_in_class( SET_CLASS )

=cut

sub get_all_sets_ids_in_class
{
	my ($self, $set_class) = @_;
	my $table = $self->{conf}->get_value('database_set_table_prefix') . $set_class;
	my $query = $self->do_sql("SELECT DISTINCT set_member_id FROM $table");
	my $results = [];
	while (my @row = $query->fetchrow_array() )
	{
		push @{$results}, $row[0];
	}
	return $results;
}

=item $d->get_membership( ID, SET )

=cut

sub get_membership
{
	my ($self, $id, $set) = @_;
	my $table = $self->{conf}->get_value('database_set_table_prefix') . $set;
	my $query = $self->do_sql("SELECT set_member_id FROM $table WHERE eprint_id = $id");
	my $results = [];
	while (my @row = $query->fetchrow_array() )
	{
		push @{$results}, $row[0];
	}
	return $results;
}

=item $d->get_citation( ID, SET [, LENGTH] )

=cut

sub get_citation
{
	my ($self, $id, $set, $length) = @_;

        my $table =  $self->{conf}->get_value('database_set_table_prefix') . $set . $self->{conf}->get_value('database_set_table_citation_suffix');
	my $citation = 'full_citation';
	if ( (defined $length) and ($length eq 'short') )
	{
		$citation = 'short_citation';
	}

       	my $query = $self->do_sql("SELECT `$citation` FROM `$table` WHERE set_member_id = $id");
        
	my @row = $query->fetchrow_array();
	my $citation_text = $row[0];
	if ($citation_text !~ /[a-zA-Z0-9]/)
	{
		$citation_text = "OOPS: $set $id missing citation!";
	}
	return $citation_text;
}

=item $d->get_url( ID, SET )

=cut

sub get_url
{
	my ($self, $id, $set) = @_;
	my $table =  $self->{conf}->get_value('database_set_table_prefix') . $set . $self->{conf}->get_value('database_set_table_citation_suffix');

	my $query = $self->do_sql("SELECT `url` FROM `$table` WHERE set_member_id = $id");

	my @row = $query->fetchrow_array();
	my $citation_text = $row[0];
	if ($citation_text !~ /[a-zA-Z0-9]/)
	{
		$citation_text = "OOPS: $set $id missing citation!";
	}
	return $citation_text;
}

=item $d->get_stats( PARAMS, QUERY_PARAMS [, DEBUG] )

=cut

sub get_stats 
{
#takes in a set of params and an arrayref of column names.
#returns a reference to a database object 
#options is a hashref containing
#
# query params contains
#	columns - an array of column names (perhaps with COUNT as a column name) 
#	where - an array of where hashes
#		where hash - a hash containing a column, an operator and a value
#	order - hash with column name and direction (DESC or ASC)
#	limit - an integer
#	group - a column name to agregate on.


	my ($self, $params, $query_params, $debug) = @_;

	my $conf = $self->{session}->get_conf;

	my $sql_query_parts = {
		columns => [],
		tables => [],
		logic => [],
		etc => []
	};

	#Columns
	foreach my $column (@{$query_params->{columns}})
	{
		if (uc($column) eq 'COUNT')
		{
			push @{$sql_query_parts->{columns}}, 'COUNT(*) AS c';
		}
		else
		{
			push @{$sql_query_parts->{columns}}, $self->_generate_column_id($column);
		}

	}
	#Inner Joins
	foreach my $set_name (@{$self->{sets}})
	{
		if ($params->{'eprints'} =~ /^$set_name/)
		{
			my $set_member_code = substr($params->{'eprints'},length($set_name)+1);
			my $set_table = $conf->database_set_table_prefix . $set_name;
			my $set_code_table = $conf->database_set_table_prefix . $set_name . $conf->database_set_table_code_suffix;
			push @{$sql_query_parts->{tables}}, ' INNER JOIN `' . $set_table .  
			'` ON `' . $self->{source_table} . '`.`eprint` = `' . $set_table  . '`.`eprint_id`' .
			" INNER JOIN  `".$set_code_table."` ON `".$set_table."`.`set_member_id` = `$set_code_table`.`set_member_id`";

			push @{$sql_query_parts->{where}}, " `$set_code_table`.`set_member_code` = '$set_member_code'"
		}
	}
	foreach my $column (@{$query_params->{columns}})
	{
		my $flag;
		foreach (@{$self->{id_columns}})
		{
			if ($_ eq $column)
			{
				$flag = 1;
				last;
			}
		}
		if ($flag)
		{
			if (not (uc($column) eq 'COUNT') )
			{
				push @{$sql_query_parts->{tables}}, ' LEFT JOIN `' . $self->{conf}->get_value('database_column_table_prefix') . $column . 
					'` ON `' . $self->{source_table} . '`.`' . $column . '`=`' .
					$self->{conf}->get_value('database_column_table_prefix') . $column . '`.`id`'  ;
			}
		}
	}
	#Wheres
	if ($params->get("eprints") =~ /^[0-9]*$/)
	{
		push @{$sql_query_parts->{where}},'`'.$self->{source_table} . '`.`eprint` = ' . $params->get("eprints");
	}
	if ($params->get("start_date")->equal_to($params->get("end_date")))
	{
		push @{$sql_query_parts->{where}}, '`' . $self->{source_table} . '`.`datestamp` = ' . $params->get("start_date")->render('numerical');
	}
	else
	{
		push  @{$sql_query_parts->{where}}, '`' . $self->{source_table} . '`.`datestamp` BETWEEN ' . $params->get("start_date")->render('numerical') . ' AND ' . $params->get("end_date")->render('numerical');
	}

	foreach my $where (@{$query_params->{where}})
	{
		if ( uc($where->{column}) eq 'COUNT')
		{
			push @{$sql_query_parts->{where}}, 'c' . $where->{operator} . "'" . $where->{value} . "'";
		}
		else
		{
			push @{$sql_query_parts->{where}}, $self->_generate_column_id($where->{column}) . $where->{operator} . "'" . $where->{value} . "'";
		}
	}
	#group by, order and limit
	if ( (defined $query_params->{group}) )
	{
		if ( uc($query_params->{group}) eq 'COUNT')
		{
			push  @{$sql_query_parts->{etc}}, ' GROUP BY c ';
		}
		else
		{
			push  @{$sql_query_parts->{etc}}, ' GROUP BY `' . $self->{source_table} . '`.`' . $query_params->{group} . '`';
		}
	}
	if ( (defined $query_params->{order}) )
	{
		my $r;
		if ( uc($query_params->{order}->{column}) eq 'COUNT' )
		{
			$r = ' ORDER BY c ';
		}
		else
		{
			$r = ' ORDER BY ' . $self->_generate_column_id( $query_params->{order}->{column} );
		}
		if (defined $query_params->{order}->{direction})
		{
			$r .= ' ' . $query_params->{order}->{direction};
		}
		push @{$sql_query_parts->{etc}}, $r;
	}
	if ( (defined $query_params->{limit}) )
	{
		push  @{$sql_query_parts->{etc}}, ' LIMIT ' . $query_params->{limit};
	}

	my $sql = 'SELECT ';
	$sql .= join(', ',@{$sql_query_parts->{columns}});
	$sql .= ' FROM `' . $self->{source_table}. '`';
	$sql .= join(' ',@{$sql_query_parts->{tables}});
	$sql .= ' WHERE ';
	$sql .= join(' AND ',@{$sql_query_parts->{where}});
	$sql .= join(' ',@{$sql_query_parts->{etc}});
	
	return $self->do_sql($sql, $debug);
}

sub _generate_column_id
{
#if it's a column containing an ID, make sure we get the value from the correct table
	my ($self, $column_name) = @_;
	my $flag = 0;
	foreach (@{$self->{id_columns}})
	{
		if ($_ eq $column_name)
		{
			$flag = 1;
			last;
		}
	}
	if ($flag)
	{
		return '`' . $self->{conf}->get_value("database_column_table_prefix") . $column_name . '`.`value`';
	}
	else
	{
		return '`' . $self->{source_table} . '`.`' . $column_name . '`';
	}

}

=item $d->has_table( TABLE )

Returns true if TABLE exists.

=cut

sub has_table
{
	my( $self, $table ) = @_;
	$table =~ s/[\%]//g;
	my $sql = "SHOW TABLES LIKE ?";
	my $query = $self->prepare( $sql );
	$self->execute( $query, $table );
	return defined $query->fetch;
}

=item $d->get_tables

Returns all tables matching the irstats prefix.

=cut

sub get_tables
{
	my( $self ) = @_;
	my $sql =  "SHOW TABLES LIKE '".$self->{session}->get_conf->database_table_prefix."\%'";
	my $query = $self->do_sql($sql);
	my %tables;
	while(my( $name ) = $query->fetchrow_array)
	{
		$tables{$name} = 1;
	}
	return \%tables;
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

	my $main_table = $session->get_conf->database_main_stats_table;
	my $column_table_prefix = $session->get_conf->database_column_table_prefix;
	my @column_table_ids = $session->get_conf->database_id_columns;

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
}

=item $d->check_set_tables

Check that the auxillary tables exist for the sets (members, citations and urls).

=cut

sub check_set_tables
{
	my( $self ) = @_;

	my $conf = $self->{session}->get_conf;
	
	my @set_ids = $conf->set_ids;

	foreach my $set_id ('eprint', @set_ids)
	{
		$self->check_set_table( $set_id );
	}
}

=item $d->check_set_table( SET_ID )

Check the tables exist for SET_ID and create them if they don't.

=cut

sub check_set_table
{
	my( $self, $set_id ) = @_;
	
	my $conf = $self->{session}->get_conf;
	
	my $table = $conf->database_set_table_prefix . $set_id;
	my $citation_table = $conf->database_set_table_prefix . $set_id . $conf->database_set_table_citation_suffix;
	my $code_table = $conf->database_set_table_prefix . $set_id .  $conf->database_set_table_code_suffix;

	$self->{session}->log("Checking following tables exist: $table, $citation_table, $code_table", 2);

	$self->do("CREATE TABLE IF NOT EXISTS `$table` (`set_member_id` INT, `eprint_id` INT, PRIMARY KEY (`set_member_id`,`eprint_id`))");
	$self->do("CREATE TABLE IF NOT EXISTS `$citation_table` (`set_member_id` INT, `short_citation` TINYTEXT, `full_citation` TEXT, `url` TEXT, PRIMARY KEY (`set_member_id`))");
	$self->do("CREATE TABLE IF NOT EXISTS `$code_table` (`set_member_code` VARCHAR(128), `set_member_id` INT, PRIMARY KEY (`set_member_code`(128)))");
}

=item $d->insert_main_table_row( ROW )

Inserts a row into the main table, substituting column ids where appropriate. ROW is a HASHREF.

=cut

sub insert_main_table_row
{
	my ($self, $row) = @_;
	
	# id_columns are lookup tables intended to make the database more efficient
	my %id_columns = map { $_ => 1 } $self->{conf}->database_id_columns;
	
	foreach my $column (keys %$row)
	{
		if ($id_columns{$column})
		{
			$row->{$column} = $self->column_table_id(
					$self->{conf}->get_value('database_column_table_prefix') . $column,
					$row->{$column}
				);
		}
		elsif ($column eq 'datestamp')
		{
			#remove time, we aren't interested.
			my @timestamp_parts = split (/ /,$row->{$column});
			$row->{$column} = $timestamp_parts[0];
		}
	}

	$self->insert_row(
		$self->{conf}->get_value('database_main_stats_table'),
		$row
	);
}

=item $d->column_table_id( TABLE, VALUE )

Returns an ID, which will be inserted into the main table.

Inserts the value into the appropriate support table if necesssary.

=cut

sub column_table_id
{
	my ($self, $table, $value) = @_;

	return undef if not defined $value or $value !~ /\S/;

	my $sql = "SELECT `id` FROM $table WHERE `value` = ? LIMIT 1";
	my $query = $self->prepare($sql);
	$self->execute( $query, $value );

	my ($id) = $query->fetchrow_array;
	if( not defined $id )
	{
		$sql = "INSERT INTO $table (`value`) VALUES (?)";
		$self->do($sql, {}, $value);

		$id = $self->get_insertid;
	}
	return $id;
}


### The following two function are the only ones that actually operate on the database
sub _insert_values
{
	my ($self, $table, $value_list) = @_;

	my $sql = "INSERT INTO `$table` VALUES (" . join(',', map { '?' } @$value_list) . ")";

	$self->{'database'}->do($sql, {}, @$value_list)
		or Carp::confess( "\nExecution of [$sql] failed: ( values: " . join(', ',@$value_list) . ' )' . $self->{'database'}->errstr . 
		"\n\n" . Dumper($value_list));
}

=item $database->insert_row( TABLE, ROW_HASH )

Insert a ROW_HASH into TABLE where ROW_HASH is a reference to a hash that contains column => value pairs.

=cut

sub insert_row
{
	my( $self, $table, $hash ) = @_;

	my @columns = keys %$hash;

	my $sql = "INSERT INTO `$table` (".join(',',map { "`$_`" } @columns).") VALUES (".join(',',map { '?' } @columns).")";

	$self->do($sql, {}, @{$hash}{@columns});
}

=item $d->replace_row( TABLE, ROW_HASH )

Same as insert_row but REPLACE.

=cut

sub replace_row
{
	my( $self, $table, $hash ) = @_;

	my @columns = keys %$hash;

	my $sql = "REPLACE `$table` (".join(',',map { "`$_`" } @columns).") VALUES (".join(',',map { '?' } @columns).")";

	$self->do($sql, {}, @{$hash}{@columns});
}

=item $d->do_sql( SQL [, DEBUG ] )

Prepare and execute SQL and return the resulting statement handle.

=cut

sub do_sql
{
	my ($self, $sql, $debug) = @_;

	if ($debug) {print " SQL => ",$sql," END SQL <br/>\n";};

	my $query = $self->{'database'}->prepare($sql);
	$query->execute()
		or Carp::confess "Execution of -- " . $sql . " -- failed: ".$self->{'database'}->errstr."\n"; 

	return $query;
}

=item $d->do( SQL [, ARGS ] )

=item $d->prepare( SQL [, ARGS ] )

=item $d->execute( STH [, VALUES ] )

These statements mirror the DBI equivalents.

=cut

sub do
{
	my( $self, $sql, @args ) = @_;

	return $self->{database}->do( $sql, @args )
		or Carp::confess "Execution of -- " . $sql . " -- failed: ".$self->{database}->errstr."\n";
}

sub prepare
{
	my( $self, $sql, @args ) = @_;

	return $self->{database}->prepare( $sql, @args )
		or Carp::confess "Execution of -- " . $sql . " -- failed: ".$self->{database}->errstr."\n";;
}

sub execute
{
	my( $self, $sth, @values ) = @_;

	return $sth->execute( @values )
		or Carp::confess "Execution of -- " . $sth->{Statement} . " (" . join(',',map { "'".$self->{database}->quote($_)."'" } @values) . ") -- failed: ".$self->{database}->errstr."\n";;
}

=item $d->lock( TABLE )

Lock TABLE for writing.

=cut

sub lock
{
	$_[0]->do( "LOCK TABLES `$_[1]` WRITE" );
}

=item $d->phrase( PHRASE_ID )

Return the phrase identified by PHRASE_ID.

Use $session->get_phrase( PHRASE_ID ) instead.

=cut

sub phrase
{
	my( $self, $phrase_id ) = @_;

	my $table_name = $self->{session}->get_conf->database_table_prefix . "phrases";
	my $query = $self->prepare("SELECT `phrase` FROM `$table_name` WHERE `phrase_id`=?");
	$self->execute( $query, $phrase_id );

	my( $phrase ) = $query->fetchrow_array;

	return $phrase;
}

=item $d->get_insertid

Return the last MySQL auto_incremented number.

=cut

sub get_insertid
{
	my( $self ) = @_;

	return $self->{dbh}->{mysql_insertid}
		or die "Hmm, expected mysql_insertid but didn't get one";
}

1;

__END__

=back
