package EPrints::Plugin::Export::Atom;

use EPrints::Plugin::Export::Feed;

@ISA = ( "EPrints::Plugin::Export::Feed" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Atom";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "application/atom+xml";

	$self->{number_to_show} = 10;
	$self->{arguments} = {
		indexOffset => 1,
	};

	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $list = $opts{list}->reorder( "-datestamp" );

	my $session = $plugin->{session};

	my $response = $session->make_element( "feed",
		"xmlns"=>"http://www.w3.org/2005/Atom",
		"xmlns:opensearch" => "http://a9.com/-/spec/opensearch/1.1"
	);

	my $title = $session->phrase( "archive_name" );

	$title.= ": ".EPrints::Utils::tree_to_utf8( $list->render_description );

	my $host = $session->config( 'host' );

	$response->appendChild( $session->render_data_element(
		4,
		"title",
		$title ) );

	$response->appendChild( $session->render_data_element(
		4,
		"link",
		"",
		href => $session->get_repository->get_conf( "frontpage" ) ) );
	
	$response->appendChild( $session->render_data_element(
		4,
		"link",
		"",
		rel => "self",
		href => $session->get_full_url ) );

	$response->appendChild( $session->render_data_element(
		4,
		"updated", 
		EPrints::Time::get_iso_timestamp() ) );

	my( $sec,$min,$hour,$mday,$mon,$year ) = localtime;

	$response->appendChild( $session->render_data_element(
		4,
		"id", 
		"tag:".$host.",".($year+1900).":feed:feed-title" ) );

	my $totalResults = $list->count;
	my $startIndex = ($opts{indexOffset} || 1) - 1;
	$startIndex = 0 if $startIndex < 0;
	my $itemsPerPage = 0;
	if( $startIndex + $plugin->{number_to_show} < $totalResults )
	{
		$itemsPerPage = $plugin->{number_to_show};
	}
	elsif( $startIndex > $totalResults )
	{
		$itemsPerPage = 0;
	}
	else
	{
		$itemsPerPage = $totalResults - $startIndex;
	}

	$response->appendChild( $session->render_data_element(
		4,
		"opensearch:totalResults", 
		$totalResults ) );

	$response->appendChild( $session->render_data_element(
		4,
		"opensearch:itemsPerPage", 
		$itemsPerPage ) );

	$response->appendChild( $session->render_data_element(
		4,
		"opensearch:startIndex", 
		$startIndex + 1 ) );

	my %offsets = (
		first => 1,
		previous => $startIndex-9,
		next => $startIndex+11,
		last => $totalResults-($totalResults % $plugin->{number_to_show})
	);
	delete $offsets{'previous'}
		if $startIndex == 0;
	delete $offsets{'next'}
		if ($startIndex+$plugin->{number_to_show}) > $totalResults;

	foreach my $key (sort keys %offsets)
	{
		my $uri = URI->new( $session->current_url( host => 1, query => 1 ) );
		my %q = $uri->query_form;
		delete $q{indexOffset};
		$uri->query_form( %q, indexOffset => $offsets{$key} );
		$response->appendChild( $session->render_data_element(
			4,
			"link", 
			'',
			rel => $key,
			href => "$uri",
			type => $plugin->param( "mimetype" ) ) );
	}

	foreach my $eprint ( $list->get_records( $startIndex, $plugin->{number_to_show} ) )
	{
		my $item = $session->make_element( "entry" );
		
		$item->appendChild( $session->render_data_element(
			2,
			"title",
			EPrints::Utils::tree_to_utf8( $eprint->render_description ) ) );
		$item->appendChild( $session->render_data_element(
			2,
			"link",
			"",
			href => $eprint->get_url ) );
		$item->appendChild( $session->render_data_element(
			2,
			"summary",
			EPrints::Utils::tree_to_utf8( $eprint->render_citation ) ) );

		my $updated;
		my $datestamp = $eprint->get_value( "datestamp" );
		if( $datestamp =~ /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})$/ )
		{
			$updated = "$1T$2Z";
		}
		else
		{
			print STDERR "Invalid date\n";
			$updated =  EPrints::Time::get_iso_timestamp();
		}
		
		$item->appendChild( $session->render_data_element(
			2,
			"updated",
			$updated ) );	

		$item->appendChild( $session->render_data_element(
			4,
			"id", 
			$eprint->uri ) );

		if( $eprint->exists_and_set( "creators" ) )
		{
			my $names = $eprint->get_value( "creators" );
			foreach my $name ( @$names )
			{
				my $author = $session->make_element( "author" );
				
				my $name_str = EPrints::Utils::make_name_string( $name->{name}, 1 );
				$author->appendChild( $session->render_data_element(
					4,
					"name",
					$name_str ) );
				$item->appendChild( $author );
			}
		}

		$response->appendChild( $item );		
	}	

	my $atomfeed = <<END;
<?xml version="1.0" encoding="utf-8" ?>
END
	$atomfeed.= EPrints::XML::to_string( $response );
	EPrints::XML::dispose( $response );

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $atomfeed;
		return undef;
	} 

	return $atomfeed;
}

1;

