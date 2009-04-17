package IRStats::Update::Handler::MyHandler;

use strict;

use URI;

sub new 
{
	my ($class, %self) = @_;
	my $session = $self{session};
	my $url = $session->get_conf->repository_url;
	$url = URI->new( $url );
	my $hostname = quotemeta($url->host);
	$self{scope_2_re} = $self{scope_1_re} = qr/^https?:\/\/$hostname/;
	my $min_parts = $hostname =~ /\.(aero|arpa|biz|cat|com|coop|edu|info|int|jobs|mobi|museum|name|net|org|pro|travel)$/ ?
		2 : 3;
	if( ($hostname =~ tr/\.//) > $min_parts )
	{
		$hostname =~ s/^\w+\.//;
		$self{scope_2_re} = qr/^https?:\/\/$hostname/;
	}
	return bless \%self, $class;
}

sub AUTOLOAD {}

sub abstract
{
	my( $self, $hit ) = @_;
	$hit->{fulltext} = 'A';
	$self->hit( $hit );
}

sub fulltext
{
	my( $self, $hit ) = @_;
	$hit->{fulltext} = 'F';
	$self->hit( $hit );
}

sub hit
{
	my ($self, $hit) = @_;

	my $referrer = $hit->referrer;
	my $conf = $self->{session}->get_conf;

	if( $referrer =~ $self->{scope_1_re} ) {
		$referrer = $conf->get_value('referrer_scope_1');
	} elsif( $referrer =~ $self->{scope_2_re} ) {
		$referrer = $conf->get_value('referrer_scope_2');
	} elsif( $hit->searchengine ) {
		$referrer = $conf->get_value('referrer_scope_3');
	} elsif( $referrer =~ /[a-zA-Z0-9]/ ) {#if there is anything there.
		$referrer = $conf->get_value('referrer_scope_4');
	} else {
		$referrer = $conf->get_value('referrer_scope_no_referrer');
	}
#	my $requester_inst = $hit->organisation;
#	my $requester_host = $hit->hostname ? $hit->hostname : $hit->address; #handled by convert_ip_to_host.pl for performance
	my $requester_host = $hit->address;

	my $referrer_url = $hit->referrer;

	my $datetime = $hit->datetime;
	my $date = substr($datetime, 0, 8);

	my $hit_arr = {
			'accessid' => $hit->accessid,
			'datestamp' => $date,
			'eprint' => $hit->eprint,
			'fulltext' => $hit->fulltext,
			'requester_organisation' => undef,
			'requester_host' => $requester_host,
			'requester_country' => '', #$hit->country,
			'referrer_scope' => $referrer,
			'search_engine' => $hit->searchengine,
			'search_terms' => $hit->searchterms,
			'referring_entity_id' => $referrer_url,
	};
	$self->{session}->{database}->insert_main_table_row($hit_arr);
}

1;

