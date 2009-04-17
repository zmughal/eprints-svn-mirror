package IRStats::DatabaseInterface;

use strict;

use DBI;

=head1 NAME

IRStats::DatabaseInterface - Interface to the IRstats database

=head1 DESCRIPTION

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

	my $self = bless \%self, $class;

	my $dsn          = $self->dsn;
	my $user         = $conf->get_value('database_user');
	my $password     = $conf->get_value('database_password');
	my $database     = DBI->connect( $dsn, $user, $password ) or Carp::confess "Could not connect to database $dsn!\n";

	my $main_table = $database->quote_identifier( $conf->get_value('database_main_stats_table') );
	my $id_column    = { map { $_ => 1 } $conf->database_id_columns };

	@$self{qw(
		database
		main_table
		id_column
	)} = (
		$database,
		$main_table,
		$id_column,
	);

	@{$self->{sets}} = ('eprint',$conf->set_ids);

	return $self;
}

=item $d->quote( ARGS )

See L<DBI>'s quote.

=item $d->quote_identifier( ARGS )

See L<DBI>'s quote_identifier.

=item $d->quote_date( COLUMN )

Format COLUMN as YYYYMMDD.

=cut

sub quote { shift->{database}->quote( @_ ) }
sub quote_identifier { shift->{database}->quote_identifier( @_ ) }

=item $d->get_conf

Return the configuration object.

=cut

sub get_conf { $_[0]->{conf} }

=item $d->dsn

The database connection string.

=cut

=item $d->get_max_accessid

Returns the highest accessid currently set, or undef if there are no records.

=cut

sub get_max_accessid
{
	my( $self ) = @_;

	my $sql = "SELECT MAX(".$self->quote_identifier("accessid").") FROM ".$self->{main_table};
	my $sth = $self->do_sql( $sql );

	my( $max ) = $sth->fetchrow_array;

	return $max;
}

=item $d->get_id( CODE, SET )

Returns the id of a code for a given set.

=cut

sub get_id
{
	my( $self, $code, $set_id ) = @_;

	my $code_table = $self->get_conf->database_set_table_prefix . $set_id . $self->get_conf->database_set_table_code_suffix;

	my $sql = "SELECT ".$self->quote_identifier("set_member_id")." FROM ".$self->quote_identifier($code_table)." WHERE ".$self->quote_identifier("set_member_code")." = ?";
	my $sth = $self->do_sql($sql, $code);

	my $row = $sth->fetch or return "ERR";
	return $row->[0];
}

=item $d->get_code( ID, SET )

Returns the code for an ID in a given set.

=cut

sub get_code
{
	my( $self, $id, $set_id ) = @_;

	my $code_table = $self->get_conf->database_set_table_prefix . $set_id . $self->get_conf->database_set_table_code_suffix;

	my $sql = "SELECT ".$self->quote_identifier("set_member_code")." FROM ".$self->quote_identifier($code_table)." WHERE ".$self->quote_identifier("set_member_id")." = ?";
	my $sth = $self->do_sql($sql, $id);

	my $row = $sth->fetch or return "ERR";
	return $row->[0];
}

=item $d->get_all_sets_ids_in_class( SET_CLASS )

=cut

sub get_all_sets_ids_in_class
{
	my( $self, $set_class ) = @_;

	my $table = $self->get_conf->database_set_table_prefix . $set_class;

	my $sql = "SELECT ".$self->quote_identifier("set_member_id")." FROM ".$self->quote_identifier($table)." GROUP BY ".$self->quote_identifier("set_member_id");
	my $sth = $self->do_sql($sql);

	my @results;
	while(my $row = $sth->fetch)
	{
		push @results, $row->[0];
	}

	return \@results;
}

=item $d->get_membership( ID, SET )

=cut

sub get_membership
{
	my( $self, $id, $set_id ) = @_;

	my $table = $self->get_conf->database_set_table_prefix . $set_id;

	my $sql = "SELECT ".$self->quote_identifier("set_member_id")." FROM ".$self->quote_identifier($table)." WHERE ".$self->quote_identifier("eprint_id")." = ?";
	my $sth = $self->do_sql($sql, $id);

	my @results;
	while(my $row = $sth->fetch)
	{
		push @results, $row->[0];
	}

	return \@results;
}

=item $d->get_citation( ID, SET [, LENGTH] )

=cut

sub get_citation
{
	my( $self, $id, $set_id, $length ) = @_;

	my $table = $self->get_conf->database_set_table_prefix . $set_id . $self->get_conf->database_set_table_citation_suffix;

	my $column = (4 == @_ and $_[3] eq 'short') ?
		'short_citation' :
		'full_citation';

	my $sql = "SELECT ".$self->quote_identifier($column)." FROM ".$self->quote_identifier($table)." WHERE ".$self->quote_identifier("set_member_id")." = ?";
	my $sth = $self->do_sql($sql,$id);
	my ($citation) = $sth->fetchrow_array;

	unless( defined($citation) and $citation =~ /\w/ )
	{
		$citation = "OOPS: $set_id $id missing $column!";
	}

	return $citation;
}

=item $d->get_url( ID, SET )

=cut

sub get_url
{
	my( $self, $id, $set_id ) = @_;

	my $table = $self->get_conf->database_set_table_prefix . $set_id . $self->get_conf->database_set_table_citation_suffix;

	my $sql = "SELECT ".$self->quote_identifier("url")." FROM ".$self->quote_identifier($table)." WHERE ".$self->quote_identifier("set_member_id")." = ?";
	my $sth = $self->do_sql($sql,$id);
	my ($url) = $sth->fetchrow_array;

	unless( defined($url) and $url =~ /\w/ )
	{
		$url = "OOPS: $set_id $id missing url!";
	}

	return $url;
}

=item $d->get_stats( PARAMS, QUERY_PARAMS )

takes in a set of params and an arrayref of column names.
returns a reference to a database object 
options is a hashref containing

 query params contains
	columns - an array of column names (perhaps with COUNT as a column name) 
	where - an array of where hashes
		where hash - a hash containing a column, an operator and a value
	order - hash with column name and direction (DESC or ASC)
	limit - an integer
	group - a column name to agregate on.

=cut

#if it's a column containing an ID, make sure we get the value from the correct table
sub _generate_column_id
{
    my ($self, $column_name) = @_;

    if( $self->{id_column}->{$column_name} )
    {
		my $table = $self->get_conf->database_column_table_prefix . $column_name;
		return $self->quote_identifier( $table ) . "." . $self->quote_identifier( "value" );
    }
	else
	{
		return $self->{main_table} . "." . $self->quote_identifier( $column_name );
	}
}

sub get_stats
{
    my ($self, $params, $query_params) = @_;

    my $conf = $self->get_conf;

	my( @columns, @tables, @logic, @etc );

    #Columns
    foreach my $column (@{$query_params->{columns}})
    {
        if (uc($column) eq 'COUNT')
        {
            push @columns, "COUNT(*) AS c";
        }
		else
		{
			if( $column eq 'datestamp' )
			{
				push @columns, $self->quote_date($self->_generate_column_id($column));
			}
			else
			{
				push @columns, $self->_generate_column_id($column);
			}
    		if( defined $query_params->{group} )
			{
				$columns[$#columns] = "MIN(".$columns[$#columns].")";
			}
		}

    }
    #Inner Joins
    foreach my $set_name (@{$self->{sets}})
    {
        if ($params->{'eprints'} =~ /^$set_name/)
        {
            my $set_member_code = substr($params->{'eprints'},length($set_name)+1);
            my $set_table = $self->quote_identifier( $conf->database_set_table_prefix . $set_name );
            push @tables, " INNER JOIN $set_table ON " . $self->{main_table} . ".".$self->quote_identifier("eprint")." = $set_table.".$self->quote_identifier("eprint_id");

            my $set_code_table = $self->quote_identifier( $conf->database_set_table_prefix . $set_name . $conf->database_set_table_code_suffix );
			push @tables, " INNER JOIN $set_code_table ON $set_table.".$self->quote_identifier("set_member_id")." = $set_code_table.".$self->quote_identifier("set_member_id");

			push @logic, " $set_code_table.".$self->quote_identifier("set_member_code")." = ".$self->quote($set_member_code);
        }
    }
    foreach my $column (@{$query_params->{columns}})
    {
        if( $self->{id_column}->{$column} and uc($column) ne 'COUNT' )
        {
			my $table = $self->quote_identifier( $conf->database_column_table_prefix . $column );
			push @tables, " LEFT JOIN $table ON " . $self->{main_table} . "." . $self->quote_identifier($column) . " = $table." . $self->quote_identifier("id");
        }
    }
    #Wheres
    if ($params->get("eprints") =~ /^[0-9]*$/)
    {
        push @logic, $self->{main_table} . ".".$self->quote_identifier("eprint")." = " . $params->get("eprints");
    }
    if ($params->get("start_date")->equal_to($params->get("end_date")))
    {
        push @logic, $self->{main_table} . "." . $self->quote_identifier("datestamp"). " = " . $self->quote($params->get("start_date")->render('numerical'));
    }
    else
    {
        push  @logic, $self->{main_table} . "." . $self->quote_identifier("datestamp") . " BETWEEN " . $self->quote($params->get("start_date")->render("numerical")) . " AND " . $self->quote($params->get("end_date")->render("numerical"));
    }

    foreach my $comp (@{$query_params->{where}})
    {
        if ( uc($comp->{column}) eq 'COUNT')
        {
            push @logic, " c " . $comp->{operator} . " " . $self->quote( $comp->{value} );
        }
        else
        {
            push @logic, $self->_generate_column_id($comp->{column}) . " " . $comp->{operator} . " " . $self->quote( $comp->{value} );
        }
    }
    #group by, order and limit
    if ( (defined $query_params->{group}) )
    {
        if ( uc($query_params->{group}) eq 'COUNT')
        {
            push  @etc, ' GROUP BY c ';
        }
        else
        {
			push  @etc, ' GROUP BY ' . $self->{main_table} . '.' . $self->quote_identifier($query_params->{group});
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
        push @etc, $r;
    }
    if ( (defined $query_params->{limit}) )
    {
        push  @etc, ' LIMIT ' . $query_params->{limit};
    }

    my $sql = 'SELECT ';
    $sql .= join(', ',@columns);
    $sql .= ' FROM ' . $self->{main_table};
    $sql .= join(' ',@tables);
    $sql .= ' WHERE ';
    $sql .= join(' AND ',@logic);
    $sql .= join(' ',@etc);

    return $self->do_sql($sql);
}

=item $d->has_table( TABLE )

Returns true if TABLE exists.

=cut

sub has_table
{
	my( $self, $table ) = @_;

	my @names = $self->{database}->tables( undef, undef, $table );

	return 1 == scalar @names;
}

=item $d->check_tables

Checks the main IRStats tables exist and creates them if they don't.

=cut

=item $d->check_set_tables( [ SUFFIX ] )

Check that the auxillary tables exist for the sets (members, citations and urls). If SUFFIX is specified adds an additional suffix onto the table name to test.

=cut

sub check_set_tables
{
	my( $self, $suffix ) = @_;

	my @set_ids = $self->get_conf->set_ids;

	for('eprint',@set_ids)
	{
		$self->check_set_table( $_, $suffix );
	}
}

=item $d->check_set_table( SET_ID )

Check the tables exist for SET_ID and create them if they don't.

=cut

=item $d->has_table_column( TABLE, COLUMN )

Returns true if TABLE has a column called COLUMN.

=cut

sub has_table_column
{
	my( $self, $table, $column ) = @_;

	my $sth = $self->{database}->column_info( undef, undef, $table, '%' );

	while(my $row = $sth->fetchrow_hashref)
	{
		if( $row->{COLUMN_NAME} eq $column )
		{
			$sth->finish;
			return 1;
		}
	}

	return 0;
}

=item $d->check_requester_host_table

Utility method to check the requester_host table has the additional IP column (used by convert_ip_to_host).

=cut

=item $d->insert_main_table_row( ROW )

Inserts a row into the main table, substituting column ids where appropriate. ROW is a HASHREF.

=cut

sub insert_main_table_row
{
    my ($self, $row) = @_;

    foreach my $column (keys %$row)
    {
        if ($self->{id_column}->{$column})
        {
            $row->{$column} = $self->column_table_id(
                    $self->get_conf->database_column_table_prefix . $column,
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
        $self->get_conf->database_main_stats_table,
        $row
    );
}

=item $d->column_table_id( TABLE, VALUE )

Returns an ID, which will be inserted into the main table.

Inserts the value into the appropriate support table if necesssary.

=cut

sub column_table_id
{
	my( $self, $table, $value ) = @_;

	return undef unless defined $value and $value =~ /\S/;

	if( length($value) > 255 )
	{
		$value = substr($value,0,255);
	}

	my $sql = "SELECT ".$self->quote_identifier("id")." FROM ".$self->quote_identifier($table)." WHERE ".$self->quote_identifier("value")." = ? LIMIT 1";
	my $sth = $self->do_sql( $sql, $value );

	my( $id ) = $sth->fetchrow_array;
	unless( defined $id )
	{
		$sql = "INSERT INTO ".$self->quote_identifier($table)." (".$self->quote_identifier("value").") VALUES (?)";
		$self->do($sql, $value);

		$id = $self->get_insertid( $table, "id" );
	}
	return $id;
}

# utility method for insert_row/replace_row
sub _insert_replace_row
{
	my( $self, $table, $row, $type ) = @_;

	my @columns = keys %$row;

	my $sql = "$type ".$self->quote_identifier($table)." (".join(',',map { $self->quote_identifier($_) } @columns).") VALUES (".join(',',map { '?' } @columns).")";

	return $self->do($sql,@{$row}{@columns});
}

=item $database->insert_row( TABLE, ROW_HASH )

Insert a ROW_HASH into TABLE where ROW_HASH is a reference to a hash that contains column => value pairs.

=cut

sub insert_row
{
	_insert_replace_row( @_, "INSERT INTO" );
}

=item $d->remove_session( REQUEST_HOST, FROM, TO )

Remove hits for REQUEST_HOST between FROM and TO.

=cut

sub remove_session
{
	my( $self, $requester_host, $from, $to ) = @_;

    my $main_table = $self->{main_table};
    $self->do("DELETE FROM $main_table WHERE ".$self->quote_identifier("requester_host")." = ? AND ".$self->quote_identifier("datestamp")." BETWEEN ? AND ?",$requester_host,$from,$to);
}

=item $d->do_sql( SQL [, VALUES ] )

Prepare and execute SQL and return the resulting statement handle.

=cut

sub do_sql
{
	my( $self, $sql, @vals ) = @_;

	my $sth = $self->prepare($sql);
	$self->execute($sth,@vals);

	return $sth;
}

=item $d->do( SQL [, VALUES ] )

=item $d->prepare( SQL )

=item $d->execute( STH [, VALUES ] )

These statements mirror the DBI equivalents.

=cut

sub do
{
	my( $self, $sql, @vals ) = @_;

	$self->{session}->log("\tEXECUTE($sql) (".join(',',map{$self->quote($_)}@vals).")",4);

	my $r = $self->{database}->do($sql,{},@vals)
		or Carp::confess "Execution of -- $sql (".join(',',map{$self->quote($_)}@vals).") -- failed: ".$self->{database}->errstr."\n";

	return $r;
}

sub prepare
{
	my( $self, $sql ) = @_;

	my $sth = $self->{database}->prepare($sql)
		or Carp::confess "Execution of -- $sql -- failed: ".$self->{database}->errstr."\n";

	return $sth;
}

sub execute
{
	my( $self, $sth, @vals ) = @_;

	$self->{session}->log("\tEXECUTE(".$sth->{Statement}.") (".join(',',map{$self->quote($_)}@vals).")",4);

	my $r = $sth->execute(@vals)
		or Carp::confess "Execution of -- ".$sth->{Statement}." (".join(',',map{$self->quote($_)}@vals).") -- failed: ".$self->{database}->errstr."\n";

	return $r;
}

=item $d->rename_tables( OLD_NAME => NEW_NAME [, OLD_NAME => NEW_NAME ] )

Rename tables.

=cut

=item $d->drop_tables( TABLES )

Drop tables TABLES, if they exist.

=cut

sub drop_tables
{
	my( $self, @names ) = @_;

	my @dropped;

	for(@names)
	{
		if( $self->has_table( $_ ) )
		{
			$self->do("DROP TABLE ".$self->quote_identifier( $_ ));
			push @dropped, $_;
		}
	}

	return @dropped;
}

=item $d->get_phrase( PHRASE_ID )

Return the phrase identified by PHRASE_ID.

Use $session->get_phrase( PHRASE_ID ) instead - this method may change in future.

=cut

sub get_phrase
{
    my( $self, $phrase_id ) = @_;

    my $table = $self->get_conf->database_table_prefix . "phrases";

    my $sth = $self->do_sql("SELECT ".$self->quote_identifier("phrase")." FROM ".$self->quote_identifier($table)." WHERE ".$self->quote_identifier("phrase_id")." = ?", $phrase_id);

    my( $phrase ) = $sth->fetchrow_array;

    return $phrase;
}

=item $d->get_insertid( TABLE, COLUMN )

Return the last auto incremented value for COLUMN in TABLE.

=cut

sub get_insertid
{
	my( $self, $table, $column ) = @_;

	# $catalog, $schema, $table, $field, \%attr
	return $self->{database}->last_insert_id( undef, undef, $table, $column );
}

=item $d->lock_variable( VARNAME )

Get an exclusive lock on VARNAME, return 0 if VARNAME is already locked by someone else.

Returns undef if locking is unsupported.

=item $d->unlock_variable( VARNAME )

Release the lock on VARNAME, if we have it.

=cut

sub lock_variable { undef }
sub unlock_variable { undef }

1;

__END__

=back
