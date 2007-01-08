package EPrints::Plugin::Import::ApacheLog;

use EPrints::Apache::LogHandler;
use Date::Parse;
use URI;

use strict;

our @ISA = qw( EPrints::Plugin::Import );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "ApacheLog";
	$self->{visible} = "yes";
	$self->{produce} = [ 'list/access' ];

	return $self;
}

sub input_fh
{
	my( $plugin, %opts ) = @_;

	my $fh = $opts{fh};

	my @ids = ();
	my $input_data;
	while( defined($input_data = <$fh>) )
	{
		my $epdata = $plugin->convert_input( $input_data );

		next unless( defined $epdata );

		my $dataobj = $plugin->epdata_to_dataobj( $opts{dataset}, $epdata );
		if( defined $dataobj )
		{
			push @ids, $dataobj->get_id;
		}
	}

	return EPrints::List->new(
		dataset => $opts{dataset},
		session => $plugin->{session},
		ids => \@ids );
}

sub convert_input
{
	my( $plugin, $input_data ) = @_;
	my $session = $plugin->{session};

	unless( $input_data =~ /^((?:\d{1,3}\.){3}\d{1,3}) - \S+ \[([^\]]+)\] "([A-Z]+) (\S+) HTTP\/1\.[01]" (\d+) (\d+|-) "([^"]*)" "(.*)"$/ )
	{
		EPrints::abort("Unknown or unrecognised ApacheLog input: '$input_data'");
	}

	my( $ip, $date, $method, $page, $status, $size, $referrer, $agent ) =
		($1, $2, $3, $4, $5, $6, $7 );
	
	$status += 0;
		
	# Ignore anything that isn't 200 and GET
	if( $status != 200 )
	{
		return undef;
	}
	if( $method ne 'GET' )
	{
		return undef;
	}

	my $access;

	$access->{datestamp} =
		EPrints::Time::get_iso_timestamp(Date::Parse::str2time($date));
	$access->{requester_id} = "urn:ip:$ip";
	$access->{referent_id} = $page = URI->new($page,'http');
	$access->{referent_docid} = undef;
	$access->{referring_entity_id} = $referrer;
	$access->{service_type_id} = '';
	$access->{requester_user_agent} = $agent;

	my $eprintid = EPrints::Apache::LogHandler::uri_to_eprintid( $session, $page );
	return undef unless( defined $eprintid );
	$access->{referent_id} = $eprintid;

	my $docid = EPrints::Apache::LogHandler::uri_to_docid( $session, $eprintid, $page );
	if( defined $docid )
	{
		$access->{referent_docid} = $docid;
		$access->{service_type_id} = "?fulltext=yes";
	}
	else
	{
		$access->{service_type_id} = "?abstract=yes";
	}

	if( !$access->{referring_entity_id} or $access->{referring_entity_id} !~ /^https?:/ )
	{
		$access->{referring_entity_id} = '';
	}

	my $ref_uri = URI->new($access->{referring_entity_id},'http');
	$eprintid = EPrints::Apache::LogHandler::uri_to_eprintid( $session, $ref_uri );

	if( defined $eprintid )
	{
		$access->{referring_entity_id} = $eprintid;

		my $docid = EPrints::Apache::LogHandler::uri_to_docid ( $session, $eprintid, $ref_uri );
		if( $access->{referring_entity_id} eq $access->{referent_id} and
				defined( $docid ) )
		{
			return undef;
		}
	}

	return $access;
}

1;
