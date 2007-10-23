package IRStats::CLI::import_metadata;

# Iterate over fields in a dataset

our @ISA = qw( IRStats::CLI );

use strict;
use warnings;

sub execute
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;

	my %files = (
		set_member_full_citations_file => 'f_cite',
		set_member_short_citations_file => 's_cite',
		set_membership_file => 'eprints',
		set_member_codes_file => 'code',
		set_member_urls_file => 'url',
	);

	my $data = $self->read_from_files( %files );
	$self->write_to_database($data);

	my $phrases = $self->read_phrases( 'set_phrases_file' );
	$self->write_phrases( $phrases );
}

sub read_phrases
{
	my( $self, $file ) = @_;

	my $filename = $self->{session}->get_conf->get_path( $file );

	my %phrases;

	open my $fh, "<", $filename or die "Error reading $filename: $!";
	while(<$fh>)
	{
		chomp($_);
		my( $id, $phrase ) = split /\t/, $_;
		$phrases{$id} = $phrase;
	}
	close $fh;

	return \%phrases;
}

sub read_from_files
{
	my( $self, %files ) = @_;

	my $conf = $self->{session}->get_conf;
	
	my $data = {};
	
	my @sets = $conf->set_ids;
	$data->{$_} = {} for (@sets, 'eprint');
	
	foreach my $file (keys %files)
	{
		my $filename = $conf->get_path($file);
		$self->{session}->log("Reading $file from $filename");
		my $code = $files{ $file };
		open my $fh, "<", $filename or die "Error reading $filename: $!";
		my $lineno = 0;
		while(<$fh>)
		{
			$self->process_file_line( $data, $file, $code, $_, ++$lineno );
		}
		close($fh);
	}

	return $data;
}

sub write_phrases
{
	my( $self, $phrases ) = @_;
##Now write to the database

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;

	$session->log("IMPORTING PHRASES");

	my $table_name = $conf->database_table_prefix . "phrases";

	$database->do("CREATE TABLE IF NOT EXISTS `$table_name` (
		`phrase_id` CHAR(64) NOT NULL,
		`phrase` LONGTEXT,
		PRIMARY KEY(`phrase_id`)
	)");

	while(my($id,$phrase) = each %$phrases)
	{
		$database->replace_row( $table_name, {
			phrase_id => $id,
			phrase => $phrase,
		});
	}
}

sub process_file_line
{
	my ($self, $data, $filename, $field_name, $line, $lineno) = @_;
	chomp $line;
	return if $line =~ /^\s*$/; #Empty line
	if(my( $set_id, $set_member_id, $value ) = split /\t/, $line, 3)
	{
		if( not defined $set_member_id or not defined $value )
		{
			$self->{session}->log( "WARNING: Expected three tab-separated columns at line $lineno in $filename but only got: $line", 0 );
			return;
		}
		if (defined $data->{$set_id}->{$set_member_id}->{$field_name})
		{
			$self->{session}->log( "WARNING: $set_id\t$set_member_id\t$field_name not unique", 0);
			return;
		}
		if( not exists $data->{$set_id} )
		{
			$self->{session}->log( "WARNING: '$set_id' is not a defined set in the configuration file on line: $line", 0 );
			return;
		}
		if ($field_name eq 'eprints')
		{
			my @eprints = split(/,/,$value);
			$data->{$set_id}->{$set_member_id}->{$field_name} = \@eprints;
		}
		else
		{
			$data->{$set_id}->{$set_member_id}->{$field_name} = $value;
		}
	}
}


sub write_to_database
{
	my( $self, $data ) = @_;
##Now write to the database

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;

	$session->log("IMPORTING GROUPS: " . join(', ',keys %{$data}));

	while(my( $set_id, $dataset ) = each %$data)
	{
		$session->log("--$set_id--");

		my $table = $conf->database_set_table_prefix . $set_id;
		my $citation_table = $conf->database_set_table_prefix . $set_id . $conf->database_set_table_citation_suffix;
		my $code_table = $conf->database_set_table_prefix . $set_id .  $conf->database_set_table_code_suffix;

		my $new_table = $table . "_new";
		my $new_citation_table = $citation_table . "_new";
		my $new_code_table = $code_table . "_new";

		$database->do("DROP TABLE IF EXISTS $new_table, $new_citation_table, $new_code_table");

		$database->do("CREATE TABLE $new_table (set_member_id INT, eprint_id INT, PRIMARY KEY (set_member_id,eprint_id))");
		$database->do("CREATE TABLE $new_citation_table (set_member_id INT, short_citation TINYTEXT, full_citation TEXT, url TEXT, PRIMARY KEY (set_member_id))");
		$database->do("CREATE TABLE $new_code_table (set_member_code TINYTEXT, set_member_id INT, PRIMARY KEY (set_member_code(30)))");

		while(my( $set_member_id, $datamember ) = each %$dataset)
		{
			my $code = "ERROR";
			my $short_citation = "Missing Short Citation";
			my $full_citation = "Missing Full Citation";
			my $url = "";

			if( defined $datamember->{'code'} )
			{
				$code = $datamember->{'code'};
			}
			if( defined $datamember->{'s_cite'} )
			{
				$short_citation = $datamember->{'s_cite'};
			}
			if( defined $datamember->{'f_cite'} )
			{
				$full_citation = $datamember->{'f_cite'};
			}
			if( defined $datamember->{'url'} )
			{
				$url = $datamember->{'url'};
			}

			#Make sure we remove duplicate ID numbers
			my %seen = ();
			foreach my $item (@{$datamember->{'eprints'}}) {
				    $seen{$item}++;
			}
			foreach (keys %seen)
			{
				$database->insert_row($new_table, {
					set_member_id => $set_member_id,
					eprint_id => $_
				});
			}
			$database->insert_row($new_citation_table, {
				set_member_id => $set_member_id,
				short_citation => $short_citation,
				full_citation => $full_citation,
				url => $url
			});
			$database->insert_row($new_code_table, {
				set_member_id => $set_member_id,
				set_member_code => $code
			});
		}

		my $tables = $database->get_tables;
		for($table, $citation_table, $code_table)
		{
			if( $tables->{$_} )
			{
				$database->do( "RENAME TABLE $_ TO ${_}_old, ${_}_new TO $_" );
			}
			else
			{
				$database->do( "RENAME TABLE ${_}_new TO $_" );
			}
		}
		$database->do("DROP TABLE IF EXISTS ${table}_old, ${citation_table}_old, ${code_table}_old");
	}
}

1;
