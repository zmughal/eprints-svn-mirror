package IRStats::Update::Parser::ApacheDSpace;

use strict;

use vars qw( $AUTOLOAD $MAX_PER_SECOND );

$MAX_PER_SECOND = 1000;

our @ISA = qw( Logfile::EPrints::Filter );

use Logfile::EPrints::Parser;
use Logfile::EPrints::Mapping::DSpace;

sub new
{
	my( $class, %self ) = @_;
	$self{accessid} = $self{session}->get_database->get_max_accessid;
	my $self = bless \%self, $class;
	$self;
}

sub parse
{
	my( $self ) = @_;

	my $fh = \*STDIN;
	
	my $p = Logfile::EPrints::Parser->new(
		handler => Logfile::EPrints::Mapping::DSpace->new(
			identifier => '',
		handler => $self,
	));
	$p->parse_fh( $fh );
}

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /[A-Z]$/;
	$AUTOLOAD =~ s/^.*:://;
	my( $self, $hit ) = @_;

	my $identifier = $hit->identifier;
	$identifier =~ s/^\d+\///; # remove the community bit
	$hit->{eprint} = $hit->{identifier} = $identifier;
	$hit->{accessid} = ++$self->{accessid};

	return $self->{handler}->$AUTOLOAD( $hit );
}

1;
