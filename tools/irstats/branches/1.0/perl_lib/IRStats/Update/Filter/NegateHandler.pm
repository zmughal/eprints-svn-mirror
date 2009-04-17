package IRStats::Update::Filter::NegateHandler;

=head1 NAME

IRStats::Update::Filter::NegateHandler - Remove existing hits

=cut

use strict;

use POSIX qw/strftime/;

use vars qw( @ISA $AUTOLOAD );

@ISA = qw( Logfile::EPrints::Filter );

sub new
{
	my( $class, %self ) = @_;
	bless \%self, $class;
}

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /[A-Z]$/;
	$AUTOLOAD =~ s/^.*:://;
	my( $self, $hit ) = @_;
	my $r = $self->{handler}->$AUTOLOAD( $hit );
	if( $r and ref($r) and $r->isa( "Logfile::EPrints::Hit::Negate" ) )
	{
		my $database = $self->{session}->get_database;
		my $conf = $self->{session}->get_conf;
		my $address = $r->address;
		my $from = utime_to_date($r->start_utime);
		my $to = utime_to_date($r->end_utime + 86400);
		$self->{session}->log("Removing session for $address ($from-$to)",2);

# We need the requester_host and not the address
		my $requester_host = $database->column_table_id(
			$conf->get_value('database_column_table_prefix') . 'requester_host',
			$address
		);
		$database->remove_session( $requester_host, $from, $to );
	}
	return $r;
}

sub utime_to_date
{
	POSIX::strftime("%Y%m%d",gmtime($_[0]));
}

sub utime_to_datetime
{
	POSIX::strftime("%Y%m%d%H%M%S",gmtime($_[0]));
}

1;
