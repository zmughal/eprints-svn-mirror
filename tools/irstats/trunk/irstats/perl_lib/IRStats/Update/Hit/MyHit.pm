package IRStats::Update::Hit::MyHit;

use strict;
use warnings;

use Logfile::EPrints::Hit;
use Geo::IP;

use vars qw(@ISA $AUTOLOAD);

@ISA = qw(Logfile::EPrints::Hit::Combined); 

sub new
{
	my %self = ('raw'=>$_[1]);

	$self{accessid} = $self{raw}->{accessid};
	$self{date} = $self{raw}->{datestamp};
	$self{agent} = $self{raw}->{requester_user_agent};
	$self{identifier} = $self{eprint} = $self{raw}->{referent_id};

#set fulltext flag
	if ($self{raw}->{service_type_id} eq '?fulltext=yes'){
		$self{fulltext} = 1;
	} else {
		$self{fulltext} = 0;
	}

	$self{referrer} = $self{raw}->{referring_entity_id};
#store only the ip address
	$self{raw}->{requester_id} =~ /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$/;
	$self{address} = $1;

	return bless \%self, $_[0];
}

1;
