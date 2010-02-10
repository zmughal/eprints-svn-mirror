#!/usr/bin/perl -w

=head1 NAME

B<isi_citations.pl> - ISI Web of Science citations tool

=head1 SYNOPSIS

B<isi_citations.pl> [B<options>] I<sword> I<query>

=head1 ARGUMENTS

=over 8

=item sword

The SWORD end-point URL.

=item query

The ISI query string.

=back

=head1 OPTIONS

=over 8

=item --version

Print our version and exit.

=item B<--verbose>

Be more verbose.

=item --quiet

Be less verbose.

=item --collection

The collection end-point.

=item --username

Username to authenticate against the SWORD endpoint.

=item --password

Password to authenticate against the SWORD endpoint.

=item --max

Maximum number of items to submit.

=item --xsl_path

Path to search for stylesheets (.xsl or .xslt) to translate ISI WoK XML to XML that can be submitted to the SWORD endpoint. Defaults to current directory.

=item --dump_wok

Dump the response from WoK and exit.

=item --dump_xml

Dump the XML that would be submitted to SWORD instead of submitting it.

=back

=cut

use strict;

use constant {
	NS_SWORD    => 'http://purl.org/net/sword/',
	NS_APP      => 'http://www.w3.org/2007/app',
	NS_DCTERMS  => 'http://purl.org/dc/terms/',
	NS_ATOM     => 'http://www.w3.org/2005/Atom',
};

use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::LibXSLT;
use SOAP::ISIWoK;
use Getopt::Long;
use Pod::Usage;
use LWP::UserAgent;

our $VERSION = $SOAP::ISIWoK::VERSION;

my $opt_version;
my $opt_help = 0;
my $opt_verbose = 0;
my $opt_quiet = 0;
my $opt_collection;
my $opt_email;
my $opt_sword;
my $opt_username;
my $opt_password;
my $opt_max = 10;
my $opt_dump_xml;
my $opt_dump_wok;
my $opt_query;
my $opt_xsl_path = ".";

GetOptions(
	"help|?" => \$opt_help,
	"version" => \$opt_version,
	"verbose+" => \$opt_verbose,
	"quiet" => \$opt_quiet,
	"email=s" => \$opt_email,
	"username=s" => \$opt_username,
	"password=s" => \$opt_password,
	"max=i" => \$opt_max,
	"dump_xml" => \$opt_dump_xml,
	"dump_wok" => \$opt_dump_wok,
	"xsl_path" => \$opt_xsl_path,
	"collection=s" => \$opt_collection,
) or pod2usage( 2 );

die "$VERSION\n" if $opt_version;
pod2usage( 1 ) if $opt_help;
pod2usage( 0 ) if @ARGV != 2;

($opt_sword, $opt_query ) = @ARGV;

my $noise = $opt_quiet ? 0 : $opt_verbose+1;

if( $noise > 2 )
{
	eval "use LWP::Debug";
	LWP::Debug::level( '+' ); # full tracing
}

my $ua = LWP::UserAgent->new;

$ua->agent( "ISI-to-Sword/$VERSION" );
$ua->from( $opt_email ) if $opt_email;

my $doc = XML::LibXML::Document->new;

# end of initialisation

# parse the available stylesheets
my %stylesheets = read_stylesheets( $opt_xsl_path );
if( !keys %stylesheets )
{
	die "No stylesheet transforms available at '$opt_xsl_path'\n";
}

# retrieve the available collections
my %collections = collections( $opt_sword );
if( !keys %collections )
{
	die "No collections found in service document\n";
}

# with the available stylesheets, work out which collections we can post to and
# which stylesheet to use with it (based on the collection preferred
# namespaces)
my %supported;
foreach my $c (values %collections)
{
	foreach my $ns (@{$c->{accepts}})
	{
		if( exists $stylesheets{$ns} )
		{
			$c->{namespaceURI} = $ns;
			$c->{stylesheet} = $stylesheets{$ns};
			$supported{$c->{href}} = $c;
			last;
		}
	}
}
if( !keys %supported )
{
	die "No collections support the available metadata formats: ".join(', ', keys %stylesheets)."\n";
}

# if not collection option was given, ask the user which to use
while( !$opt_collection )
{
	print STDERR "Which collection should I deposit in?:\n";
	foreach my $href (sort keys %supported)
	{
		print STDERR "$href\t".$supported{$href}{title}."\t[XML=".$supported{$href}{namespaceURI}."]\n";
	}
	$opt_collection = input( "Enter collection URL" );
}

my $col = $supported{$opt_collection};
if( !$col )
{
	die "'$opt_collection' is not a supported endpoint\n";
}

# get the search results from ISI
my $xml = query( $opt_query );

if( $opt_dump_wok )
{
	print $xml->toString( 1 );
	exit( 0 );
}

# translate the WoK XML to our preferred XML
my @records = parse_xml( $xml, $col->{stylesheet} );

# submit each match to the SWORD end-point
foreach my $rec (@records)
{
	if( $opt_dump_xml )
	{
		print $rec->toString( 1 );
	}
	else
	{
		submit( $opt_collection, $rec, $col->{namespaceURI} );
		print STDERR "Submitted 1 record\n" if $noise;
	}
}

sub query
{
	my( $query ) = @_;

	my $wok = SOAP::ISIWoK->new;

	return $wok->search( $query, max => $opt_max );
}

sub parse_xml
{
	my( $xml, $stylesheet ) = @_;

	my @records;

	foreach my $rec ($xml->getElementsByTagName( "REC" ))
	{
		my $source = XML::LibXML::Document->new;
		$source->setDocumentElement( my $records = $doc->createElement( "RECORDS" ) );
		$rec->parentNode->removeChild( $rec );
		$rec->setOwnerDocument( $source );
		$records->appendChild( $rec );
		push @records, $stylesheet->transform( $source );
	}

	return @records;
}

sub trim
{
	my( $str ) = @_;

	return $str if !defined $str;

	$str =~ s/^\s+//;
	$str =~ s/\s+$//;

	return $str;
}

sub collections
{
	my( $endpoint ) = @_;

	my $req = HTTP::Request->new( GET => $endpoint . "/servicedocument" );

	AUTH_FAILED:
	$req->authorization_basic( $opt_username, $opt_password );
	my $res = $ua->request( $req );
	if( $res->code eq 401 )
	{
		$opt_username = input( "Enter username" ) or die "Requires username\n";
		$opt_password = input( "Enter password" );
		goto AUTH_FAILED;
	}

	if( !$res->is_success )
	{
		Carp::croak "Error getting servicedocument: " . $res->status_line;
	}

	my $servicedoc = XML::LibXML->new->parse_string( $res->content );
	my $xpc = XML::LibXML::XPathContext->new( $servicedoc->documentElement );

	print STDERR $servicedoc->toString( 1 ) if $noise > 2;

	my $app_xmlns = $servicedoc->documentElement->getAttribute( "xmlns" );
	$xpc->registerNs( 'app', $app_xmlns );
	$xpc->registerNs( 'dcterms', NS_DCTERMS );
	$xpc->registerNs( 'atom', NS_ATOM );
	$xpc->registerNs( 'sword', NS_SWORD );
	
	my $node;

	my $version;
	( $node ) = $xpc->findnodes( "sword:version" );
	( $node ) = $xpc->findnodes( "sword:level" ) if !defined $node;
	if( defined $node )
	{
		$version = $node->textContent;
		Carp::croak "Only supports version 1.3, got '$version'" if $version ne "1.3" and $version ne "1";
	}
	else
	{
		Carp::croak "Expected sword:version or sword:level node in servicedocument:\n".$servicedoc->toString( 1 );
	}

	print STDERR "SWORD version=$version\n" if $noise > 0;

	my %collections;

	foreach my $collection ($xpc->findnodes( "app:workspace/app:collection" ))
	{
		next if !$collection->hasAttribute( "href" );
		my $c = { href => $collection->getAttribute( "href" ), accepts => [] };
		$collections{$c->{href}} = $c;
		foreach my $prop ($collection->childNodes)
		{
			next if !$prop->isa( "XML::LibXML::Element" );
			my $name = $prop->localName;
			my $value = trim( $prop->textContent );
			if( $prop->namespaceURI eq NS_SWORD )
			{
				if( $name eq "acceptPackaging" ) # version 1.3
				{
					push @{$c->{accepts}}, { prefer => $prop->getAttribute( "q" ), namespaceURI => $value };
				}
				elsif( $name eq "collectionPolicy" )
				{
					$c->{policy} = $value;
				}
				elsif( $name eq "treatment" )
				{
					$c->{treatment} = $value;
				}
				elsif( $name eq "formatNamespace" ) # level 1
				{
					push @{$c->{accepts}}, { prefer => $prop->getAttribute( "q" ), namespaceURI => $value };
				}
				elsif( $name eq "mediation" )
				{
					$c->{mediation} = $value;
				}
				else
				{
					print STDERR "Unrecognised element in collection: ".$prop->namespaceURI.":$name\n" if $noise > 1;
				}
			}
			elsif( $prop->namespaceURI eq NS_ATOM )
			{
				if( $name eq "title" )
				{
					$c->{title} = $value;
				}
				else
				{
					print STDERR "Unrecognised element in collection: ".$prop->namespaceURI.":$name\n" if $noise > 1;
				}
			}
			elsif( $prop->namespaceURI eq NS_DCTERMS )
			{
				# abstract
			}
			elsif( $prop->namespaceURI eq $app_xmlns )
			{
				# accept
			}
			else
			{
				print STDERR "Unrecognised element in collection: ".$prop->namespaceURI.":$name\n" if $noise > 1;
			}
		}
		@{$c->{accepts}} = map { $_->{namespaceURI} } sort { $b->{prefer} <=> $a->{prefer} } @{$c->{accepts}};
	}

	return %collections;
}

sub submit
{
	my( $endpoint, $xml, $namespace ) = @_;

	my $req = HTTP::Request->new( POST => $endpoint );
	$req->authorization_basic( $opt_username, $opt_password ) if $opt_username;

	$req->header( 'X-Packaging' => $namespace );
	$req->header( 'X-Format-Namespace' => $namespace );
	$req->content_type( 'text/xml' );

	$req->content( $xml->toString );

	my $res = $ua->request( $req );

	if( !$res->is_success )
	{
		die "Error posting: ".$res->status_line;
	}
}

sub read_stylesheets
{
	my( $path ) = @_;

	my %xsls;

	my $parser = XML::LibXML->new;

	opendir(DIR, $path) or die "Unable to open $path: $!";
	foreach my $fn (readdir(DIR))
	{
		next if $fn =~ /^\./;
		next if $fn !~ /\.xslt?$/i;
		my $xsl = eval { $parser->parse_file( "$path/$fn" ) };
		next if $@;
		my $ns = $xsl->documentElement->getAttribute( 'xmlns' );
		next if !defined $ns;
		$xsls{$ns} = XML::LibXSLT->new()->parse_stylesheet( $xsl );
	}
	closedir(DIR);

	return %xsls;
}

sub input
{
	my( $msg ) = @_;

	print STDERR "$msg: ";
	my $r = <>;
	chomp($r);

	return $r;
}

1;
