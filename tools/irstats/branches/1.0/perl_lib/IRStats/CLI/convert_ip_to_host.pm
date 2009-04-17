package IRStats::CLI::convert_ip_to_host;

our @ISA = qw( IRStats::CLI );

use vars qw( $TIMEOUT $MAX_KIDS );

$TIMEOUT = 30; # dns timeout in seconds
$MAX_KIDS = 5; # maximum simultaneous dns lookups

use strict;
use warnings;

use Socket;
use IO::Select;
use DB_File;
use Symbol;

sub execute
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;


	my $dns_cache_file = $conf->get_path('dns_cache_file');
	my $main_table = $conf->database_main_stats_table;
	my $hosts_table = $conf->database_column_table_prefix . 'requester_host';

	$database->check_requester_host_table;

	tie my %dns_cache, 'DB_File', $dns_cache_file
		or die "Error opening DNS cache file $dns_cache_file: $!";

	$self->{dns_cache} = \%dns_cache;

	my %children;
	my %child_fhs;
	my $child_select = IO::Select->new;

	$session->log("Spawning child processes", 2);

	# spawn the worker processes
	for(1..$MAX_KIDS)
	{
		my( $child_fh, $parent_fh ) = (Symbol::gensym, Symbol::gensym);
		socketpair($child_fh, $parent_fh, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
			or die "socketpair failed: $!";
		select $child_fh; $| = 1;
		select $parent_fh; $| = 1;
		select STDOUT;

		if( my $pid = fork() )
		{
			# parent
			close $parent_fh;
			$session->log( "Spawned child [$pid] on ".fileno($child_fh), 3 );
			my $child = {
				pid => $pid,
				fh => $child_fh,
				ip => undef,
			};
			$children{$pid} = $child_fhs{$child_fh} = $child;
			$child_select->add( $child_fh );
		}
		else
		{
			# child
			die "fork failed: $!" unless defined $pid;
			close $child_fh; close STDIN; close STDOUT;
			$self->worker_loop( $parent_fh, $TIMEOUT );
			exit 0;
		}
	}
	
	my $pending = 0;

	$session->log("Finding all values to lookup");

	my $query = $database->do_sql("SELECT id,value FROM $hosts_table WHERE ip IS NULL");
	my $i = 0;
	while(1)
	{
		# Writing to the workers
		my( $id, $ip ) = $self->next_ip( $query );
		if( defined $ip )
		{
			if( defined( my $host = $dns_cache{$ip} ) )
			{
				$self->replace_ip( $hosts_table, $id, $ip, $host );
				next;
			}
			$i++;
			$pending++;
			# find an unused child and send it the ip
			# (if we don't find an unavailable child then that's a bug)
			my @ready = $child_select->can_write;
			my( $fh ) = grep { not defined $child_fhs{$_}->{ip} } @ready;
			$child_fhs{$fh}->{ip} = $ip;
			print $fh "$ip\n";
			$session->log( "[" . $child_fhs{$fh}->{pid} . "] Queued $ip for resolution", 3 );
		}

		# Reading from the workers
		my @ready;
		# nothing left to do
		if( $pending == 0 )
		{
			last;
		}
		# if all workers are busy wait for one to finish before continuing
		# or if there's nothing left to do, may as well wait
		elsif( $pending == $MAX_KIDS or not $query->{Active} )
		{
			@ready = $child_select->can_read;
		}
		# check for any finished workers
		else
		{
			@ready = $child_select->can_read(0);
		}
		
		foreach my $fh (@ready)
		{
			my( $ip, $host ) = split / /, <$fh>;
			chomp($host);
			$pending--;
			undef $child_fhs{$fh}->{ip};
			$dns_cache{$ip} = $host;
			$self->replace_ip( $hosts_table, $id, $ip, $host );
		}
	}

	$session->log("Finished lookup of $i ips");

	foreach my $fh ($child_select->handles)
	{
		$child_select->remove($fh);
		close($fh);
	}

	untie %dns_cache;

#	unlink($dns_cache_file); # Keep the cache for now
}

sub lookup_host
{
	return gethostbyaddr(inet_aton($_[0]), AF_INET);
}

sub worker_loop
{
	my( $self, $fh, $timeout ) = @_;

	$SIG{'ALRM'} = sub { die 'alarmed' };

	while(defined(my $ip = <$fh>))
	{
		chomp($ip);
		Carp::confess "No ip to resolve in child" unless $ip;
		my $host = undef;
		eval {
			alarm( $timeout );
			$host = lookup_host( $ip );
			alarm(0);
		};
		if( $@ =~ /alarm/ )
		{
			$host = "TIMEOUT";
		}
		$host ||= $ip;
		print $fh "$ip $host\n";
	}
}

=item (ID, HOST) = $cli->get_existing_match( TABLE_NAME, IP )

Find an existing match for IP in the requester_host table.

=cut

sub get_existing_match
{
	my( $self, $table, $ip ) = @_;

	my $sth = $self->{session}->get_database->do_sql( "SELECT id,value FROM $table WHERE ip=?", $ip );
	my $row = $sth->fetch or return ();
	return @$row;
}

sub replace_ip
{
	my( $self, $table, $id, $ip, $host ) = @_;

	my $session = $self->{session};
	my $database = $session->get_database;

	if( $host eq 'TIMEOUT' )
	{
		$session->log( "Time out while resolving $ip", 2 );
	}
	else
	{
		if( $host eq $ip )
		{
			$session->log( "No host for $ip", 3 );
			# We must change the existing IP, otherwise we'll never check this IP again (because column lookups will just match the existing entries)
			$host = "?$ip";
		}
		else
		{
			$session->log( "Replacing $ip with $host", 3 );
		}
		my( $oldid, $oldhost ) = $self->get_existing_match( $table, $host );
		# Use the existing entry
		if( defined $oldid and $host eq $oldhost )
		{
			my $main_table = $session->get_conf->irstats_main_stats_table;
			$database->do("UPDATE $main_table SET requester_host=$oldid WHERE requester_host=$id");
			$database->do("DELETE FROM $table WHERE id=$id");
		}
		# Got a different hostname or this is a new entry
		else
		{
			$database->do("UPDATE $table SET value=?,ip=? WHERE value=? AND ip IS NULL",$host,$ip,$ip);
		}
	}
}

sub next_ip
{
	my( $self, $query ) = @_;

	return () unless $query->{Active};

	my($id, $ip);

	# find an unresolved ip
	do
	{
		unless( ($id, $ip) = $query->fetchrow_array )
		{
			$query->finish;
			$self->{session}->log( "Finished reading from database" );
			return ();
		}
		$ip =~ s/\s+$//g;
	}
	while(
			$ip !~ /^(?:[0-9]+\.){3}[0-9]+$/ # not an ip address
#			or defined $self->{dns_cache}->{$ip}	# already resolved
		 );

	return( $id, $ip );
}

1;
