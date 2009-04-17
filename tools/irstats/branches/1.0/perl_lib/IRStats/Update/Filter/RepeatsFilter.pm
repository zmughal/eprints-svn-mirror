package IRStats::Update::Filter::RepeatsFilter;

# This filter requires at least repeats_filter_timeout time between every abstract or fulltext request

use strict;

our @ISA = qw( Logfile::EPrints::Filter );

use vars qw($AUTOLOAD);

use DB_File;

sub new
{ # copied for the most part from RobotTXTFilter.pm
	my ($class,%self) = @_;
	my $self = bless \%self, ref($class) || $class;

	$self->{cache_timeout} = $self->{session}->get_conf->repeats_filter_timeout;
	$self->{cache_file} = $self->{session}->get_conf->repeats_filter_file;

	my $filename = $self->{file} || $self->{cache_file};

	tie %{$self->{cache}}, 'DB_File', $filename
		or Carp::confess "Unable to open cache database file $filename: $!";

	return $self;
}

sub DESTROY
{
	my( $self ) = @_;

#remove all but period of $cache_timeout from latest time stored.
	my $latestTime = 0;

	foreach my $key (keys %{$self->{cache}})
	{
		$latestTime = $self->{cache}->{$key}
			if $self->{cache}->{$key} > $latestTime;
	}

	my @KEYS;
#key=<ipaddress>X<file>X<fulltext> value=utime
	while( my ($key, $value) = each %{$self->{cache}} ) {
		push @KEYS, $key if( $value < $latestTime - $self->{cache_timeout} );
	}
	delete $self->{cache}->{$_} for @KEYS;

	untie %{$self->{cache}};
}

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /[A-Z]$/;
	$AUTOLOAD =~ s/^.*:://;
	my ($self,$hit) = @_;

	my $key = $hit->address . "X" . $hit->eprint . "X" . $AUTOLOAD;

	if( exists($self->{cache}->{$key}) and
		($hit->utime - $self->{cache}->{$key}) <= $self->{cache_timeout} )
	{
		$self->{cache}->{$key} = $hit->utime;
		return undef;
	}
	else
	{
		$self->{cache}->{$key} = $hit->utime;
		return $self->{handler}->$AUTOLOAD($hit);
	}
}

1;
