package IRStats::Update::Filter::SearchParser;

##Stores search query information in the hit object

use strict;
use warnings;

use CGI;
use vars qw($AUTOLOAD);

unless( do "search_engines.pm" )
{
	Carp::confess "Error loading awstats database (search_engines.pm): $!. Please ensure awstats is installed and that its library path is included in the Perl path.\n";
}

our @EnginesSearchIDOrder_ = ();
our %NotSearchEnginesKeys_ = ();
our %SearchEnginesHashID_ = ();
our %SearchEnginesKnownUrl_ = ();
our @WordsToExtractSearchUrl_ = ();
our %SearchEnginesHashLib_ = ();
{
	no strict "refs";
	for(qw( list1 list2 listgen ))
	{
		push @EnginesSearchIDOrder_, @{"SearchEnginesSearchIDOrder_$_"};
	}
	%NotSearchEnginesKeys_ = %{"NotSearchEnginesKeys"};
	%SearchEnginesHashID_ = %{"SearchEnginesHashID"};
	%SearchEnginesKnownUrl_ = %{"SearchEnginesKnownUrl"};
	@WordsToExtractSearchUrl_ = @{"WordsToExtractSearchUrl"};
	%SearchEnginesHashLib_ = %{"SearchEnginesHashLib"};
}

# Exclude webmail-like servers
push @EnginesSearchIDOrder_, 'mail\.';
$SearchEnginesHashID_{'mail\.'} = 'webmail';
$SearchEnginesHashLib_{'webmail'} = 'Generic Web Mail';

$_ = qr/$_/i for @EnginesSearchIDOrder_;

# Getting referrers from where people are viewing an image inline
$SearchEnginesKnownUrl_{'google_image'} = "(p|q|as_p|as_q|prev)=";

$_ =~ s/=// for @WordsToExtractSearchUrl_;

sub new {
	my ($class,%self) = @_;
	$self{repository_url} = $self{session}->get_conf->repository_url;
	$self{repository_url} .= '/' if substr($self{repository_url},-1) ne '/';
	bless \%self, ref($class) || $class;
}

sub uncompile_regex
{
	my( $re ) = @_;
	$re =~ /\(\?[-\w]*:(.*)\)/;
	return $1;
}

sub get_search_engine_id 
{
	my ($host) = (@_);

	my $searchEngineId = undef;
	my $match = undef;

	foreach (@EnginesSearchIDOrder_) #search list of engines
	{
		if ($host =~ /$_/)
		{
			$match = uncompile_regex( $_ );
			$searchEngineId = $SearchEnginesHashID_{$match};
			last;
		}
	}

	if (defined $searchEngineId and 
		exists $NotSearchEnginesKeys_{$match} ) #search list of exceptions
	{  
		if( $host =~ /$NotSearchEnginesKeys_{$match}/i )
		{
			undef $searchEngineId;
		}
	}

	return $searchEngineId;
}

sub get_parameters
{
	my ($search_engine_ID, $cgi) = (@_);
	my @additionalSearchParams = ('as_q');

	my $parameters = undef;
	my $q = CGI->new($cgi);

	my $paramExp = $SearchEnginesKnownUrl_{$search_engine_ID};
	
	if( defined $paramExp )
	{
		$paramExp =~ s/=//; #strip out =
		$paramExp = qr/^$paramExp/i;

# check values for this search engine
		foreach my $param ($q->param)
		{
			if ($param =~ /$paramExp/){
				$parameters = $q->param($param);
# google_image has the query in prev=
				if( $param eq 'prev' )
				{
					my( $path, $cgi ) = split /\?/, $parameters, 2;
					if( defined $cgi )
					{
						return get_parameters( $search_engine_ID, $cgi );
					}
				}
				last;
			}
		}
	}
	
	#check common values and our additional values
	if (not defined $parameters)
	{
		foreach (@WordsToExtractSearchUrl_, @additionalSearchParams)
		{
			if ($q->param($_)) {$parameters = $q->param($_); last;}
		}
	}

	if( defined $parameters and !utf8::is_utf8( $parameters ) )
	{
		$parameters = Encode::decode("latin1", $parameters);
	}

	return $parameters;
}

sub get_search_engine_name
{
	my ($search_engine_ID) = @_;

	my $searchEngine = undef;

	if ($SearchEnginesHashLib_{$search_engine_ID}) {
		$searchEngine = $SearchEnginesHashLib_{$search_engine_ID};
	}

	return $searchEngine;
}

sub AUTOLOAD {
	return if $AUTOLOAD =~ /[A-Z]$/;
	$AUTOLOAD =~ s/^.*:://;
	my ($self,$hit) = @_;

	if (not $hit->referrer) {return $self->{handler}->$AUTOLOAD($hit);}

	# Use the referrer from the abstract if the user followed an abstract
	# link to here
	#my $abstractURL = $self->{repository_url} . $hit->eprint . '/';
	if( defined($hit->{abstract_referrer}) )
	{
		my $referrer = $hit->{abstract_referrer}->referrer;
		if( $referrer )
		{
			$hit->{referrer} = $referrer;
		}
		else
		{
			$hit->{referrer} = 'Abstract Page (No prior referrer given)';
		}
	}
	elsif( $hit->referrer eq $hit->identifier )
	{
		$hit->{referrer} = 'Abstract Page (Claimed by browser)';
	}
	
	# scholar seems to accept %3F (?) as well?
	my ( $host, $cgi ) = split( /\?|\%3F/i, $hit->referrer, 2 );
	if (not defined $cgi) {return $self->{handler}->$AUTOLOAD($hit);}
	# We just want the major hostname part
	$host =~ s/\/.*$// if $host =~ s/^https?:\/\/(?:www\.)?//;

	my $searchEngineID = get_search_engine_id($host);

	if (not defined $searchEngineID)
	{
		return $self->{handler}->$AUTOLOAD($hit);
	}

	my $parameters = get_parameters($searchEngineID, $cgi);
	
	my $searchEngine = get_search_engine_name($searchEngineID);

	#Differenciate between google and google scholar.
	if ($host =~ /scholar\.google/i)
	{
		$searchEngine = 'Google Scholar';
	}
	
	if (defined $searchEngine)
	{
		$hit->{searchengine} = $searchEngine;
		if (defined $parameters) { $hit->{searchterms} = $parameters; }
	}

	return $self->{handler}->$AUTOLOAD($hit);
}





1;

