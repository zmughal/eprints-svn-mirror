package SOAP::ISIWoK::Sword;

=head1 NAME

SOAP::ISIWoK::Sword - Push records from ISI WoK to a SWORD endpoint

=head1 SYNOPSIS

	use SOAP::ISIWoK::Sword;

	$isi = SOAP::ISIWoK->new();

	# search ISI
	$xml = $isi->search( $query, max => 10 );

	# sword client
	$ua = SOAP::ISIWoK::Sword->new();

	# set the sword endpoint
	$ua->sword( "http://foo/sword-app" );
	$ua->sword_auth( $username, $password );

	# populate the available collections
	$r = $ua->request_collections();

	# add a stylesheet to our pool
	$uri = $ua->parse_stylesheet( $filename );

	# pick a collection to submit to
	$collections = $ua->collections();
	$collection = $collections->[0];

	# transform ISI XML to SWORD records
	$recs = $collection->transform( $xml );

	# post a record to the SWORD collection
	$r = $collection->submit( $recs->[0] );

=head1 METHODS

=over 4

=cut

use strict;

use constant {
	NS_SWORD    => 'http://purl.org/net/sword/',
	NS_APP      => 'http://www.w3.org/2007/app',
	NS_DCTERMS  => 'http://purl.org/dc/terms/',
	NS_ATOM     => 'http://www.w3.org/2005/Atom',
};

use Carp;
use Scalar::Util;
use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::LibXSLT;
use SOAP::ISIWoK;
use LWP::UserAgent;

our $VERSION = $SOAP::ISIWoK::VERSION;
our @ISA = qw( LWP::UserAgent );

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	if( !$opts{agent} )
	{
		$self->agent( "ISI-to-Sword/$VERSION" );
	}

	return $self;
}

sub sword { shift->_elem( "sword", @_ ) }
sub stylesheets { shift->_elem( "stylesheets", @_ ) }
sub collections { shift->_elem( "collections", @_ ) }
sub sword_auth
{
	my( $self, $username, $password ) = @_;

	$self->_elem( "sword_username", $username );
	$self->_elem( "sword_password", $password );
}

sub request_collections
{
	my( $self ) = @_;

	my $req = HTTP::Request->new( GET => $self->sword . "/servicedocument" );

	$req->authorization_basic(
			$self->_elem( "sword_username" ),
			$self->_elem( "sword_password" )
		);
	my $res = $self->request( $req );
	return $res if !$res->is_success;

	my $servicedoc = XML::LibXML->new->parse_string( $res->content );
	my $xpc = XML::LibXML::XPathContext->new( $servicedoc->documentElement );

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

	my @collections;

	foreach my $collection ($xpc->findnodes( "app:workspace/app:collection" ))
	{
		next if !$collection->hasAttribute( "href" );
		my $c = {
				ua => $self,
				href => $collection->getAttribute( "href" ),
				accepts => []
			};
		push @collections, $c;
		foreach my $prop ($collection->childNodes)
		{
			next if !$prop->isa( "XML::LibXML::Element" );
			my $name = $prop->localName;
			my $value = _trim( $prop->textContent );
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
					Carp::carp( "Unrecognised element in collection: ".$prop->namespaceURI.":$name\n" );
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
					Carp::carp( "Unrecognised element in collection: ".$prop->namespaceURI.":$name\n" );
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
				Carp::carp( "Unrecognised element in collection: ".$prop->namespaceURI.":$name\n" );
			}
		}
		@{$c->{accepts}} = map { $_->{namespaceURI} } sort { $b->{prefer} <=> $a->{prefer} } @{$c->{accepts}};
	}

	@collections = map { SOAP::ISIWoK::Sword::Collection->new( %$_ ) } @collections;

	$self->collections( \@collections );

	return $res;
}

sub parse_stylesheet
{
	my( $self, $path ) = @_;

	my %xsls = %{ $self->stylesheets || {} };

	my $parser = XML::LibXML->new;

	my $xsl;
	if( ref($path) && $path->isa( "XML::LibXML::Document" ) )
	{
		$xsl = $path;
	}
	else
	{
		$xsl = $parser->parse_file( $path );
	}
	my $ns = $xsl->documentElement->getAttribute( 'xmlns' );
	return if !defined $ns;
	$xsls{$ns} = XML::LibXSLT->new()->parse_stylesheet( $xsl );

	$self->stylesheets( \%xsls );

	return $ns;
}

sub _trim
{
	my( $str ) = @_;

	return $str if !defined $str;

	$str =~ s/^\s+//;
	$str =~ s/\s+$//;

	return $str;
}

package SOAP::ISIWoK::Sword::Collection;

use LWP::MemberMixin;
our @ISA = qw(LWP::MemberMixin);

sub new
{
	my( $class, %opts ) = @_;

	Scalar::Util::weaken( $opts{ua} ) if defined &Scalar::Util::weaken;

	return bless \%opts, $class;
}

sub ua { shift->_elem( "ua", @_ ) }
sub href { shift->_elem( "href", @_ ) }
sub accepts { shift->_elem( "accepts", @_ ) }
sub stylesheet { shift->_elem( "stylesheet", @_ ) }
sub namespaceURI { shift->_elem( "namespaceURI", @_ ) }

sub transform
{
	my( $self, $xml ) = @_;

	my $stylesheets = $self->ua->stylesheets;
	foreach my $ns (@{$self->accepts})
	{
		if( exists $stylesheets->{$ns} )
		{
			$self->namespaceURI( $ns );
			$self->stylesheet( $stylesheets->{$ns} );
			last;
		}
	}

	if( !defined $self->stylesheet )
	{
		Carp::croak "Missing stylesheet for: ".join(', ', @{$self->accepts});
	}

	my @records;

	foreach my $rec ($xml->getElementsByTagName( "REC" ))
	{
		my $source = XML::LibXML::Document->new;
		$source->setDocumentElement( my $records = $source->createElement( "RECORDS" ) );
		my $rec_copy = $rec->cloneNode( 1 );
		$rec_copy->setOwnerDocument( $source );
		$records->appendChild( $rec_copy );
		push @records, $self->stylesheet->transform( $source );
	}

	return \@records;
}

sub submit
{
	my( $self, $xml ) = @_;

	my $req = HTTP::Request->new( POST => $self->href );
	$req->authorization_basic(
			$self->ua->_elem( "sword_username" ),
			$self->ua->_elem( "sword_password" )
		);

	$req->header( 'X-Packaging' => $self->namespaceURI );
	$req->header( 'X-Format-Namespace' => $self->namespaceURI );
	$req->content_type( 'text/xml' );

	$req->content( $xml->toString );

	return $self->ua->request( $req );
}

1;
