package EPrints::Plugin::Output::ContextObject::Journal;

use Unicode::String qw( utf8 );

use EPrints::Plugin::Output;

@ISA = ( "EPrints::Plugin::Output" );

use strict;

# The utf8() method is called to ensure that
# any broken characters are removed. There should
# not be any broken characters, but better to be
# sure.

our %MAPPING = qw(
	title	atitle
	volume	volume
	number	number
	series	series
	publication	title
	pagerange	pages
	date_effective	date
);
our %TYPE_MAPPING = qw(
	article	article
	conference_item	conference
	misc	unknown
);

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "Journal ContextObject";
	$self->{accept} = [ 'dataobj/eprint', 'dataobj/accesslog' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";

	return $self;
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

	my $session = $plugin->{ "session" };
	my $repository = $session->get_repository;

	my $jnl = $session->make_element(
		"jnl:journal",
		"xmlns:jnl" => "info:ofi/fmt:xml:xsd:journal",
		"xsi:schemaLocation" => "info:ofi/fmt:xml:xsd:journal http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:journal",
	);

	if( $dataobj->is_set( "type" ) )
	{
		my $type = $dataobj->get_value( "type" );
		if( defined($type = $TYPE_MAPPING{$type}) )
		{
			$jnl->appendChild(
				$session->make_element( "jnl:genre" )
			)->appendChild(
				$session->make_text( $type )
			);
		}
	}
	
	if( $dataobj->is_set( "creators" ) )
	{
		my $auths = $session->make_element( "jnl:authors" );
		$jnl->appendChild( $auths );

		foreach my $author ( map { $_->{ "main" } } @{$dataobj->get_value( "creators" )} )
		{
			my $auth = $auths->appendChild( $session->make_element( "jnl:author" ) );
			
			$auth->appendChild(
				$session->make_element( "jnl:aulast" )
			)->appendChild(
				$session->make_text( $author->{ "family" } )
			);
			$auth->appendChild(
				$session->make_element( "jnl:aufirst" )
			)->appendChild(
				$session->make_text( $author->{ "given" } )
			);
		}
	}
	
	while( my( $from, $to ) = each %MAPPING )
	{
		next unless $dataobj->is_set( $from );
		my $node = $session->make_element( "jnl:$to" );
		$jnl->appendChild( $node );
		$node->appendChild( $session->make_text( $dataobj->get_value( $from )));
	}

	return $jnl;
}

1;
