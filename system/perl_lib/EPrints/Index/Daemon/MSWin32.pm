package EPrints::Index::Daemon::MSWin32;

use Win32::Daemon;

use EPrints::Index::Daemon;
@ISA = qw( EPrints::Index::Daemon );
our $MASTER_SERVICE = 'EPrintsIndexer';
our $WORKER_SERVICE = 'EPrintsIndexerWorker';

use strict;

sub win32_error
{
	my( $self, $msg ) = @_;

	EPrints->abort( "$msg: $^E" );
}

sub create_service
{
	my( $self ) = @_;

	my $path = $EPrints::SystemSettings::conf->{base_path} . "/bin/indexer";
	my $params = '';

	$params .= " --loglevel=".$self->{loglevel};

	my $rc = Win32::Daemon::CreateService({
		machine => '',
		name => $MASTER_SERVICE,
		display => 'EPrints Indexer',
		path => $^X,
		user => '',
		pwd => '',
		description => 'EPrints Indexer master service',
		parameters => "$path $params --master start",
	});
       
	$rc &&= Win32::Daemon::CreateService({
		machine => '',
		name => $WORKER_SERVICE,
		display => 'EPrints Indexer Worker',
		path => $^X,
		user => '',
		pwd => '',
		description => 'EPrints Indexer worker service',
		parameters => "$path $params --worker start",
		start_type => SERVICE_DEMAND_START,
#		dependencies => [$MASTER_SERVICE], # we'll just end up fighting with windows
	});
       
	if( !$rc )
	{
		$self->win32_error( 'Create EPrints Indexer service' );
	}

	return $rc;
}

sub delete_service
{
	my( $self ) = @_;

	my $rc = Win32::Daemon::DeleteService('', $MASTER_SERVICE);
	$rc &= Win32::Daemon::DeleteService('', $WORKER_SERVICE);

	if( !$rc )
	{
		$self->win32_error( 'Delete EPrints Indexer service' );
	}

	return $rc;
}

sub is_running
{
	my( $self ) = @_;

	my $status = {};
	if( !Win32::Service::GetStatus('',$MASTER_SERVICE,$status) )
	{
		$self->win32_error( "EPrints Indexer master state" );
	}

	return $status->{'CurrentState'} != SERVICE_STOPPED;
}

sub is_worker_running
{
	my( $self ) = @_;

	my $status = {};
	if( !Win32::Service::GetStatus('',$WORKER_SERVICE,$status) )
	{
		$self->win32_error( "EPrints Indexer worker state" );
	}

	return $status->{'CurrentState'} != SERVICE_STOPPED;
}

sub start_daemon
{
	my( $self ) = @_;

	if( !Win32::Service::StartService('',$MASTER_SERVICE) )
	{
		$self->win32_error( "Starting EPrints Indexer service" );
	}

	return 1;
}

sub stop_daemon
{
	my( $self ) = @_;

	if( !Win32::Service::StopService('',$MASTER_SERVICE) )
	{
		$self->win32_error( "Stopping EPrints Indexer service" );
	}

	return 1;
}

sub start_master
{
	my( $self ) = @_;

	if( $self->{logfile} )
	{
		open(STDOUT, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
		open(STDERR, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
	}

	$self->log( 1, "** Indexer process started" ); 
	$self->log( 3, "** Indexer control process started with process ID: $$" ); 

	$self->write_pid;

	# inlined all the functionality because this is a very thin control process
	Win32::Daemon::RegisterCallbacks( my $callbacks = {
		start => sub {
			my( $e, $context ) = @_;

			$context->{last_state} = SERVICE_RUNNING;
			Win32::Daemon::State( SERVICE_RUNNING );
		},
		running => sub {
			my( $e, $context ) = @_;

			my $self = $context->{self};

			return if SERVICE_RUNNING != Win32::Daemon::State();

			if( $self->suicidal )
			{
				Win32::Service::StopService('', $WORKER_SERVICE);
				Win32::Daemon::StopService();
			}
			elsif( $self->should_respawn )
			{
				Win32::Service::StopService('', $WORKER_SERVICE);
				$context->{roll_logs} = 1;
			}
			elsif( !$self->is_worker_running )
			{
				if( $context->{roll_logs} )
				{
					$self->roll_logs;
					$context->{roll_logs} = 0;
				}
				$self->log( 2, "*** Starting indexer sub-process" );
				Win32::Service::StartService('', $WORKER_SERVICE); 
			}
			Win32::Daemon::State($context->{last_state});
		},
		stop => sub {
			my( $e, $context ) = @_;

			$context->{self}->log( 1, "** Indexer process stopping" );

			Win32::Service::StopService('', $WORKER_SERVICE); 

			$context->{last_state} = SERVICE_STOPPED;
			Win32::Daemon::State( SERVICE_STOPPED );

			Win32::Daemon::StopService();
		},
		pause => sub {
			my( $e, $context ) = @_;

			$context->{last_state} = SERVICE_PAUSED;
			Win32::Daemon::State( SERVICE_PAUSED );
		},
		continue => sub {
			my( $e, $context ) = @_;

			$context->{last_state} = SERVICE_RUNNING;
			Win32::Daemon::State( SERVICE_RUNNING );
		},
	} );

	my %context = (
		last_state => SERVICE_STOPPED,
		start_time => time(),
		roll_logs => 0,
		self => $self,
	);

	Win32::Daemon::StartService( \%context, 2000 );

	unlink($self->{suicidefile});
	$self->remove_pid;
}

sub start_worker
{
	my( $self ) = @_;

	if( $self->{logfile} )
	{
		open(STDOUT, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
		open(STDERR, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
	}

	$self->log( 3, "** Worker process started: $$" );

	Win32::Daemon::RegisterCallbacks( {
		start => \&callback_start,
		running => \&callback_running,
		stop => \&callback_stop,
		pause => \&callback_pause,
		continue => \&callback_continue,
	} );

	my %context = (
		last_state => SERVICE_STOPPED,
		start_time => time(),
		self => $self,
	);

	Win32::Daemon::StartService( \%context, 5000 );

	# this reached on StopService
	unlink($self->{tickfile});
}

# called every 5 seconds
sub callback_running
{
	my( $event, $context ) = @_;

	my $self = $context->{self};

	while( SERVICE_RUNNING == Win32::Daemon::State() )
	{
		$self->log( 3, "* tick: $$" );
		$self->tick;

		my $seen_action = 0;

		foreach my $repo (@{$self->{repositories}})
		{
			$repo->check_last_changed;

			eval {
				local $SIG{ALRM} = sub { die "alarm\n" };
				alarm($self->get_timeout);
				$seen_action |= $self->_run_index( $repo, {
					loglevel => $self->{loglevel},
				} );
				alarm(0);
			};
			if( $@ )
			{
				die unless $@ eq "alarm\n";
				$self->log( 1, "**  Timed out processing index entry: some indexing failed" );
			}
		}

		last if !$seen_action;
	}

	Win32::Daemon::State($context->{last_state});
}

sub callback_start
{
	my( $event, $context ) = @_;

	my $self = $context->{self};

	$self->{repositories} = [$self->get_all_sessions];

	$context->{last_state} = SERVICE_RUNNING;
	Win32::Daemon::State( SERVICE_RUNNING );
}

sub callback_pause
{
	my( $event, $context ) = @_;

	$context->{last_state} = SERVICE_PAUSED;
	Win32::Daemon::State( SERVICE_PAUSED );
}

sub callback_continue
{
	my( $event, $context ) = @_;

	$context->{last_state} = SERVICE_RUNNING;
	Win32::Daemon::State( SERVICE_RUNNING );
}

sub callback_stop
{
	my( $event, $context ) = @_;

	$context->{last_state} = SERVICE_STOPPED;
	Win32::Daemon::State( SERVICE_STOPPED );

	Win32::Daemon::StopService();
}

1;
