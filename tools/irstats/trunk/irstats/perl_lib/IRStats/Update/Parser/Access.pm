package IRStats::Update::Parser::Access;

=head1 NAME

IRStats::Update::Parser::Access - Parse hits from an Eprints 3 access table

=cut

use strict;

sub new
{
	my( $class, %self ) = @_;
	bless \%self, $class;
}

*parse = \&update; # synonym
sub update
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $database = $session->get_database;
	my $conf = $session->get_conf;

	my $source_table = $conf->get_value('database_eprints_access_log_table');
	my $destination_table = $conf->get_value('database_main_stats_table');

	my $sql;
	my $query;

	my $stime = time(); # used for debugging
	my $i = 0;

#find last entries in both tables, and process over that range
	my $highest_source_access_id = 0;
	my $highest_destination_access_id = 0;

	$sql = "SELECT `accessid` FROM $source_table ORDER BY `accessid` DESC LIMIT 1"; #get highest accessid
	$query = $database->do_sql($sql);
	unless( ($highest_source_access_id) = $query->fetchrow_array )
	{
		Carp::confess "Nothing in $source_table to process\n";
	}
	$query->finish();

	$sql = "SELECT `accessid` FROM $destination_table ORDER BY `accessid` DESC LIMIT 1"; #get highest accessid
	$query = $database->do_sql($sql);
	unless( ($highest_destination_access_id) = $query->fetchrow_array )
	{
		$highest_destination_access_id = 0;
	}
	$query->finish();

	# Do chunks of 100,000 records because we can potentially be dealing with
	# millions of records
	for(my $accessid = $highest_destination_access_id; $accessid < $highest_source_access_id;)
	{
		$session->log("Processing from $accessid to $highest_source_access_id");

##because it's the first update, do twice
		$sql = "SELECT * FROM `$source_table`  WHERE `accessid` > $accessid ORDER BY `accessid` ASC LIMIT 100000";
		$query = $database->do_sql($sql);

		while (my $row = $query->fetchrow_hashref()){
			my %hit = %$row;
			$accessid = $hit{accessid};
			$hit{date} = $hit{datestamp} = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
				@hit{qw(
					datestamp_year
					datestamp_month
					datestamp_day
					datestamp_hour
					datestamp_minute
					datestamp_second
				)});
			$hit{agent} = $hit{requester_user_agent};
			# e.g. info:oai:generic.eprints.org:48
			$hit{referent_id} =~ s/^.*://;
			$hit{referring_entity_id} =~ s/^info:.*://
				if defined $hit{referring_entity_id};

			$hit{identifier} = $hit{eprint} = $hit{referent_id};

			$hit{referrer} = $hit{referring_entity_id};
#store only the ip address
			$hit{requester_id} =~ /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$/;
			$hit{address} = $1;

			my $hit = bless \%hit, "Logfile::EPrints::Hit::Combined";
			if ($hit{service_type_id} eq '?fulltext=yes')
			{
				$self->{handler}->fulltext($hit);
			}
			else
			{
				$self->{handler}->abstract($hit);
			}
			$i++;
			print STDERR scalar(keys(%Logfile::EPrints::Filter::Session::SESSIONS)) . " sessions [" . $i . '/' . ($highest_source_access_id-$highest_destination_access_id) . "]\r" if $session->verbose > 1;
		}

		$session->log(sprintf("%.2f",$i/(time-$stime))." records per second") if (time-$stime);
	}

	$query->finish();
}

1;
