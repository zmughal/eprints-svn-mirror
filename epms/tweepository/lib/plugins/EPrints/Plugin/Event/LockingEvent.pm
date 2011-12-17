package EPrints::Plugin::Event::LockingEvent;

use EPrints::Plugin::Event;
use Data::Dumper;
@ISA = qw( EPrints::Plugin::Event );

#superclass to provide repository level lock files for events
use strict;

sub new
{
        my( $class, %params ) = @_;

        my $self = $class->SUPER::new(%params);

        $self->{log_data} = {};

        return $self;
}

#should be overridden, but in case it isn't
sub generate_log_string
{
	my ($self) = @_;

	return Dumper $self->{log_data};
}

sub write_log
{
	my ($self) = @_;

	my $filename = $self->logfile;
	open FILE, ">>$filename";

	print FILE $self->generate_log_string, "\n\n";

	close FILE;
}

#same filename and path used for locking and logging.  Just a different extension
sub _file_without_extension
{
	my ($self) = @_;

	my $classname = ref $self;
	$classname =~ m/Event::(.*)/;

	my $filename = EPrints::Utils::escape_filename( $1 );

	my $path = $self->repository->config('archiveroot') . '/var/' . $filename;
}

sub logfile
{
	my ($self) = @_;

	return $self->_file_without_extension . '.log';
}

sub lockfile
{
	my ($self) = @_;

	return $self->_file_without_extension . '.lock';
}


sub is_locked
{
	my ($self) = @_;

	return 1 if -e $self->lockfile;
	return 0;
}

sub create_lock
{
	my ($self) = @_;

	my $path = $self->lockfile;

	open FILE, ">", $path || $self->repository->log("Could not open $path for " . ref $self . "\n");

	print FILE scalar localtime time;

	close FILE;
}

sub remove_lock
{
	my ($self) = @_;

	my $path = $self->lockfile;
	unlink $path || $self->repository->log("Could unlink $path for " . ref $self . "\n");
}

1;
