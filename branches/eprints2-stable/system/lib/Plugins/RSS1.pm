
package EPrints::Plugins::RSS1;
use EPrints::Session;
use EPrints::Exporter;
use strict;


EPrints::Plugins::register( 'convert/obj.eprint/rss1.struct/default',	\&eprint_to_rss_item_struct );
EPrints::Plugins::register( 'export/objs.eprint/rss1/default',	\&eprints_to_rss_xml );

sub eprint_to_rss_item_struct
{
	my( $eprint ) = @_;

	my $data = {
		resource => $eprint->get_url,
		title => EPrints::Utils::tree_to_utf8( $eprint->render_description ),
		description => EPrints::Utils::tree_to_utf8( $eprint->render_citation )
	};
	
	return $data;
}


# additional parameter: mode_obj_to_struct
# additional parameter: about_url (string)
# additional parameter: title     (xml)
# additional parameter: description     (xml)
# additional parameter: link  (url)
sub eprints_to_rss_xml
{
	my( %opts ) = @_;

	if( !defined $opts{mode_obj_to_struct} ) 
	{ 
		$opts{mode_obj_to_struct} = 'default'; 
	};

	if( !defined $opts{about_url} ) 
	{
		if( &SESSION->is_online )
		{
			$opts{about_url} = &SESSION->get_url; 
		}
		else
		{
			# no preset and not online.
			$opts{about_url} = '';
		}
	};
	if( !defined $opts{title} ) 
	{ 
		$opts{title} = 'RSS From '.EPrints::Session::best_language( 
			&SESSION->get_langid(),
			%{&ARCHIVE->get_conf( "archivename" )} );
	}
	else
	{
		$opts{title} = EPrints::Utils::tree_to_utf8( $opts{title} );
	}
	if( !defined $opts{description} ) { $opts{description} = 'An RSS feed generated by GNU EPrints (no more information available)'; };
	if( !defined $opts{link} ) { $opts{link} = &ARCHIVE->get_conf( 'frontpage' ); };

	my $exp = new EPrints::Exporter( %opts, mimetype=>'text/xml' );

	my $rss = &SESSION->make_element( 
		'rdf:RDF',
  		'xmlns:rdf'=>"http://www.w3.org/1999/02/22-rdf-syntax-ns#",
  		'xmlns'=>"http://purl.org/rss/1.0/" );

	my $channel = &SESSION->make_element( 
		'channel',
		'rdf:about'=>$opts{about_url} );
	$rss->appendChild( $channel );

	$channel->appendChild( &SESSION->render_data_element(
		4,
		"title",
		$opts{title} ));
	$channel->appendChild( &SESSION->render_data_element(
		4,
		"link",
		$opts{about_url} ));
	$channel->appendChild( &SESSION->render_data_element(
		4,
		"description",
		$opts{description} ));
	my $items = &SESSION->make_element( 'items' );
	$channel->appendChild( $items );	
	my $seq = &SESSION->make_element( 'rdf:Seq' );
	$items->appendChild( $seq );

	$opts{objs}->map( sub { 
		my( $dataset, $obj, $info ) = @_;
		my $struct = &ARCHIVE->plugin(
			'convert/obj.eprint/rss1.struct/'.$opts{mode_obj_to_struct},
			$obj );

		my $li = &SESSION->make_element( "rdf:li",
			"rdf:resource"=>$struct->{resource} );
		$seq->appendChild( $li );

		my $item = &SESSION->make_element( "item",
			"rdf:about"=>$struct->{resource} );

		$item->appendChild( &SESSION->render_data_element(
			2,
			"title",
			$struct->{title} ) );
		$item->appendChild( &SESSION->render_data_element(
			2,
			"link",
			$struct->{resource} ) );
		$item->appendChild( &SESSION->render_data_element(
			2,
			"description",
			$struct->{description} ) );
		$rss->appendChild( $item );		
	}, {}, $opts{offset}, $opts{count} );

	$exp->data( <<END );
<?xml version="1.0" encoding="utf-8" ?>

END
	$exp->data( EPrints::XML::to_string( $rss ) );
	EPrints::XML::dispose( $rss );

	return $exp->finish;
}



1;


