package EPrints::Plugin::Output::ContextObject;

use Unicode::String qw( utf8 );

use EPrints::Plugin::Output;

@ISA = ( "EPrints::Plugin::Output" );

use strict;

# The utf8() method is called to ensure that
# any broken characters are removed. There should
# not be any broken characters, but better to be
# sure.

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "ContextObject";
	$self->{accept} = [ 'list/eprint', 'list/accesslog', 'dataobj/eprint', 'dataobj/accesslog' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";

	return $self;
}





sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	my $toplevel = "context-objects";
	
	my $r = [];

	my $part;
	$part = <<EOX;
<?xml version="1.0" encoding="utf-8" ?>

<$toplevel xmlns="info:ofi/fmt:xml:xsd:ctx" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="info:ofi/fmt:xml:xsd:ctx http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx">
EOX
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	foreach my $dataobj ( $opts{list}->get_records )
	{
		$part = $plugin->output_dataobj( $dataobj, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	}	

	$part= "</$toplevel>\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}


	if( defined $opts{fh} )
	{
		return;
	}

	return join( '', @{$r} );
}

sub output_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $itemtype = $dataobj->get_dataset->confid;

	my $xml = $plugin->xml_dataobj( $dataobj, %opts );

	return EPrints::XML::to_string( $xml );
}

sub xml_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $itemtype = $dataobj->get_dataset->confid;

	my $session = $plugin->{ "session" };
	my $repository = $session->get_repository;
	my $oai = $repository->get_conf( "oai" );

	# TODO: fix timestamp format
	my $co = $session->make_element(
		"ctx:context-object",
		"xmlns:ctx" => "info:ofi/fmt:xml:xsd:ctx",
		"xmlns:xsi" => "http://www.w3.org/2001/XML",
		"xsi:schemaLocation" => "info:ofi/fmt:xml:xsd:ctx http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx",
		"timestamp" => $dataobj->get_value( "datestamp" ),
	);

	# Referent
	my $rft = $session->make_element( "ctx:referent" );
	$co->appendChild( $rft );
	
	my $rft_id = $dataobj->isa( "EPrints::DataObj::EPrint" ) ?
		'info:' . EPrints::OpenArchives::to_oai_identifier( $oai->{v2}->{ "archive_id" }, $dataobj->get_id ) :
		$dataobj->get_value( "referent_id" );

	$rft->appendChild(
		$session->make_element( "ctx:identifier" )
	)->appendChild(
		$session->make_text( $rft_id )
	);

	if( $dataobj->isa( "EPrints::DataObj::EPrint" ) ) {
		my $jnl_plugin = $session->plugin( "Output::ContextObject::Journal" );

		my $md_val = $session->make_element( "ctx:metadata-by-val" );
		$rft->appendChild( $md_val );
	
		my $fmt = $session->make_element( "ctx:format" );
		$md_val->appendChild( $fmt );
		$fmt->appendChild( $session->make_text( "info:ofi/fmt:xml:xsd:journal" ));
	
		my $md = $session->make_element( "ctx:metadata" );
		$md_val->appendChild( $md );

		$md->appendChild( $jnl_plugin->xml_dataobj( $dataobj ) );
	}
	
	if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
	{
		return $co;
	}

	# referring-entity
	if( $dataobj->exists_and_set( "referring_entity_id" ) )
	{
		my $rfr = $session->make_element( "ctx:referring-entity" );
		$co->appendChild( $rfr );

		$rfr->appendChild(
			$session->make_element( "ctx:identifier" )
		)->appendChild(
			$session->make_text( $dataobj->get_value( "referring_entity_id" ))
		);
	}

	# requester
	my $req = $session->make_element( "ctx:requester" );
	$co->appendChild( $req );

	$req->appendChild(
		$session->make_element( "ctx:identifier" )
	)->appendChild(
		$session->make_text( $dataobj->get_value( "requester_id" ))
	);
	
	if( $dataobj->exists_and_set( "requester_user_agent" ) )
	{
		$req->appendChild(
			$session->make_element( "ctx:private-data" )
		)->appendChild(
			$session->make_text( $dataobj->get_value( "requester_user_agent" ))
		);
	}

	# service-type
	if( $dataobj->exists_and_set( "service_type_id" ) )
	{
		my $svc = $session->make_element( "ctx:service-type" );
		$co->appendChild( $svc );

		my $md_val = $session->make_element( "ctx:metadata-by-val" );
		$svc->appendChild( $md_val );
	
		my $fmt = $session->make_element( "ctx:format" );
		$md_val->appendChild( $fmt );
		$fmt->appendChild( $session->make_text( "info:ofi/fmt:xml:xsd:sch_svc" ));

		my $md = $session->make_element(
			"sv:svc-list",
			"xmlns:sv" => "info:ofi/fmt:xml:xsd:sch_svc",
			"xsi:schemaLocation" => "info:ofi/fmt:xml:xsd:sch_svc http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:sch_svc",
		);
		$md_val->appendChild( $md );

		my $uri = URI->new( $dataobj->get_value( "service_type_id" ), 'http' );
		my( $key, $value ) = $uri->query_form;
		$md->appendChild(
			$session->make_element( "sv:$key" )
		)->appendChild(
			$session->make_text( $value )
		);
	}
	
	return $co;
}

1;
