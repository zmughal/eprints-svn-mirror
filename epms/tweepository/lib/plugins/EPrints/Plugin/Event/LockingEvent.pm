package EPrints::Plugin::Event::LockingEvent;

use EPrints::Plugin::Event;
@ISA = qw( EPrints::Plugin::Event );

#superclass to provide repository level lock files for events

use strict;

sub lockfile
{
	my ($self) = @_;

	my $classname = ref $self;
	$classname =~ m/Event::(.*)/;

	my $filename = EPrints::Utils::escape_filename( $1 );

	my $path = $self->repository->config('archiveroot') . '/var/' . $filename . '.lock';
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
