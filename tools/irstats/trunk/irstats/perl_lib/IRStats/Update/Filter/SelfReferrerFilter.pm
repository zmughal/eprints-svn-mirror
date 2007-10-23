package IRStats::Update::Filter::SelfReferrerFilter;

#if the referrer is the url of this EPrints fulltext, ignore it.

use strict;

our @ISA = qw( Logfile::EPrints::Filter );

use vars qw($AUTOLOAD);

sub new {
	my ($class,%args) = @_;
	my $self = bless \%args, ref($class) || $class;
	($self->{repository_url}) = $self->{session}->get_conf->repository_url;
	$self->{repository_url} .= '/' if substr($self->{repository_url},-1) ne '/';
	return $self;
}

sub fulltext
{
	my( $self, $hit ) = @_;

	return $self->{handler}->fulltext( $hit ) unless defined $hit->referrer;

	my $abstractURL = $self->{repository_url} . $hit->eprint . '/';
	$abstractURL = qr/$abstractURL/i;
#abstract url plus a couple of characters must be a fulltext url 
	if( $hit->referrer =~ /^$abstractURL../ )
	{
		$self->{session}->log( "Skipping self-referrer hit ".$hit->accessid." [".$hit->referrer."]", 3 );
	}
	else
	{
		return $self->{handler}->fulltext($hit);
	}
}

1;
