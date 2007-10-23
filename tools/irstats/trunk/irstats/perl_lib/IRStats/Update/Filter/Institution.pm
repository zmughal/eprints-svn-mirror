package IRStats::Update::Filter::Institution;

use strict;

use Geo::IP;

use vars qw( $AUTOLOAD @ISA $GEO );

our @ISA = qw( Logfile::EPrints::Filter );

sub new
{
	my( $class, %self ) = @_;
	$self{geo_ip_org_file} = $self{session}->get_conf->get_path( 'geo_ip_org_file' ),
	$GEO ||= Geo::IP->open($self{geo_ip_org_file},GEOIP_STANDARD);
	bless \%self, $class;
}

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /[A-Z]$/;
	$AUTOLOAD =~ s/^.*:://;
	my( $self, $hit ) = @_;
	$hit->{institution} = $GEO->org_by_addr( $hit->address );
	return $self->{handler}->$AUTOLOAD( $hit );
}

1;
