# MapPlot Eprints Mapping Plugin (Google Maps API)
# Part of EPrints3 
# Distributed under GPL Licience
#
# Package Written by David Tarrant (dct05r@ecs.soton.ac.uk) & Mike Jewell (moj@ecs.soton.ac.uk) & Adam Field (af05v@ecs.soton.ac.uk)
#
# IMPORTANT INFORMATION
#  Installation Instructions
#
#    Before you can use this plugin with your repository you need to register with the Google Maps service and obtain a key for the 
#    url of your repository. 
#
#    To do this put enter the base URL of your repository into the registration page at http://www.google.com/apis/maps/signup.html
#
#    Enter your key in a file within your archives config directory archives/FOO/cfg/cfg.d/ in the as the following line:
#    $c={mapplot}->{google_key}="AA...";
#


package EPrints::Plugin::Export::MapPlot;

use EPrints::Plugin::Export;
use HTML::Entities ();
use XML::Parser;
use LWP::Simple;
use Data::Dumper;


@ISA = ( "EPrints::Plugin::Export" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Google Maps";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".html";
	$self->{mimetype} = "text/html";

	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $list = $opts{list};

	my $session = $plugin->{session};

	my $google_key = $session->get_repository->get_conf("mapplot","google_key");
	my $html = $session->make_element( "html",
		"xmlns"=>"http://www.w3.org/1999/xhtml" );

	my $head = $session->make_element("head");
	$html->appendChild( $head );

	my $style = $session->make_element("style",
                "type"=>"text/css",
                "media"=>"screen");
        my $style_text = "
        body,td,th {
                font-family: Arial, sans-serif;
                font-size: 10pt;
        }
        .charttext {
                font-family: Verdana, sans-serif;
                font-size: 8pt;
        }

        body {
                background-color: #FFFFFF;
        }
        .smalltext {font-size:8pt; font-family:Arial, Helvetica, sans-serif}
        .white-text {color: #FFFFFF}
        .maroonhead {font-size: 18pt; color:#990000;}
        .boldtext {font-weight: bold}
        .style4 {font-size: 8pt}
        ";
        $style->appendChild( $session->make_text( $style_text ) );
        $head->appendChild( $style );	

	my $url = $session->get_full_url();

	my $meta = $session->make_element("meta",
		"http-equiv"=>"content-type", 
		"content"=>"text/html; charset=utf-8");
	$head->appendChild( $meta );

	$head->appendChild( $session->render_data_element(
		4,
		"title",
		"Eprints Google Maps JavaScript API Exporter") );

	my $script1 = $session->make_element("script",
		"src"=>"http://maps.google.com/maps?file=api&v=2.x&key=$google_key",
		"type"=>"text/javascript");


	$head->appendChild ($script1);

	#build script2_var

	my $script2_varAll = $session->make_element("script",
                "type"=>"text/javascript");

	my $eprint_data = {};

	my %coordinates;
	my $countryData = {};
	my $locationData = {};
	my $cityData = {};
	my $pos = {};

	foreach my $eprint ( $list->get_records ) {
		if ($eprint->is_set( "latitude" )) {
			my $latitude = $eprint->get_value( "latitude" );
			my $longitude = $eprint->get_value( "longitude" );
			my $ecite = EPrints::XML::to_string( $eprint->render_citation );
			$ecite =~ s/\"/\'/g;
			$ecite =~ s/</\"+lt()+\"/g;
			$ecite =~ s/>/\"+gt()+\"/g;
			#$ecite = chop($ecite);
			#$ecite = substr($ecite,1,length($ecite));
			#push(@{$coordinates{"$latitude:$longitude"}},$ecite);
			my $cite = EPrints::XML::to_string($eprint->render_citation( "brief" ));
			my $link = $eprint->get_url;
			my $eprint_id = $eprint->get_id;
			$cite = "lt()+\"a href='$link'\"+gt()+\"$cite\"+lt()+\"/a\"+gt()";
			$eprint_data->{$eprint_id} =
			{
				latitude=> $latitude,
				longitude=> $longitude,
				citation=>$cite, 
			}
			
			#push(@{$coordinates{"$latitude:$longitude"}},$cite);
			#push(@{$coordinates{"$latitude:$longitude"}},EPrints::XML::to_string($eprint->render_citation( "brief" )));
		}
	}

	foreach my $eprint_id (keys %{$eprint_data}) 
	{
		
		my $lat = $eprint_data->{$eprint_id}->{latitude};
		my $long = $eprint_data->{$eprint_id}->{longitude};
		my $citation = $eprint_data->{$eprint_id}->{citation};
		my $xml = get("http://ws.geonames.org/findNearbyPostalCodes?lat=$lat&lng=$long");
		my $dom = EPrints::XML::parse_xml_string( $xml );
		my @country = $dom->getElementsByTagName( "countryCode" );
                my @location = $dom->getElementsByTagName( "name" );
                my @location_higher = $dom->getElementsByTagName( "adminName2");
                my $countryString = $country[0]->getFirstChild->getNodeValue;
                my $locationString = $location[0]->getFirstChild->getNodeValue;
                my $cityString = $location_higher[0]->getFirstChild->getNodeValue;

		$pos->{"$lat,$long"} = $locationString;
		
		populate_scope_hash ($countryData, $countryString, $lat, $long, $citation, $eprint_id) ;
		populate_scope_hash ($cityData, $cityString, $lat, $long, $citation, $eprint_id) ;
		populate_scope_hash ($locationData, $locationString, $lat, $long, $citation, $eprint_id) ;	

	}

	my $script2_var = "function br() { return String.fromCharCode(60,98,114,47,62) };\n\n";
	$script2_var .= "function b() { return String.fromCharCode(60,98,62) };\n\n";
	$script2_var .= "function closeb() { return String.fromCharCode(60,47,98,62) };\n\n";
	$script2_var .= "function lt() { return String.fromCharCode(60) };\n\n";
	$script2_var .= "function gt() { return String.fromCharCode(62) };\n\n";

	$script2_var .= "\t\tvar eprintsLayer = [\n";
	
	$script2_var .= create_layer($countryData,0,3);
	$script2_var .= create_layer($cityData,4,8);	
	$script2_var .= create_layer($locationData,9,17);

	$script2_var .= "\t\t];\n";

	$script2_varAll->appendChild( $session->make_text( $script2_var ) );
        $head->appendChild($script2_varAll);	


	# build script2 as text	
	my $script2 = $session->make_element("script",
		"type"=>"text/javascript");
	

	#my $script2_text = "alert (window.location.protocol + window.location.host + window.location.pathname);";
	my $script2_text .= "\n\t//CDATA[\n\t\tvar map=null;\n\t\tvar batch = [];\n";
	$script2_text .= "\n\n";
	$script2_text .= "\t\tfunction EPrintMarker( lat, lon, info, ids ) {\n";
	$script2_text .= "\t\t\tvar currmarker = new GMarker(new GLatLng( lat,lon ) );\n";
	$script2_text .= "\t\t\tGEvent.addListener(currmarker, \"click\", function() {\n";
	$script2_text .= "\t\t\t\tcurrmarker.openInfoWindowHtml(info, {maxUrl:\"/cgi/map_results?eprint_ids=\" + ids});\n";
	$script2_text .= "\t\t\t});\n";
	$script2_text .= "\t\t\treturn currmarker;\n";
	$script2_text .= "\t\t}\n";
	$script2_text .= "\n\n";
	$script2_text .= "\t\tfunction br() { return String.fromCharCode(60,98,114,47,62) };\n";
	$script2_text .= "\n\n";
	$script2_text .= "\t\tfunction load() {\n\t\t\tif (GBrowserIsCompatible()) {\n";
	$script2_text .= "\t\t\t\tmap = new GMap2(document.getElementById(\"map\"));\n";
	$script2_text .= "\t\t\t\tmap.addControl(new GLargeMapControl());\n";
	$script2_text .= "\t\t\t\tmap.addControl(new GMapTypeControl());\n";
	$script2_text .= "\t\t\t\tmap.setCenter(new GLatLng(53.00, 6.00), 5);\n";
	$script2_text .= "\t\t\t\tmap.enableDoubleClickZoom();\n";
	$script2_text .= "\t\t\t\tmap.setMapType( G_HYBRID_MAP );\n";
	$script2_text .= "\t\t\t\twindow.setTimeout(setupMarkers,0);\n";
	$script2_text .= "\t\t\t}\n";
	$script2_text .= "\t\t}\n";
	$script2_text .= "\t\tfunction setupMarkers() {\n";
	$script2_text .= "\t\t\tmgr = new GMarkerManager(map);\n";
	$script2_text .= "\t\t\tfor (var i in eprintsLayer) {\n";
	$script2_text .= "\t\t\t\tvar layer = eprintsLayer[i];\n";
	$script2_text .= "\t\t\t\tvar markers = []\n";
	$script2_text .= "\t\t\t\tfor (var j in layer[\"places\"]) {\n";
	$script2_text .= "\t\t\t\t\tvar place = layer[\"places\"][j];\n";
	$script2_text .= "\t\t\t\t\tmarkers.push(EPrintMarker(place[\"posn\"][0], place[\"posn\"][1],place[\"info\"],place[\"eprint_ids\"]));\n";
	$script2_text .= "\t\t\t\t}\n";
	$script2_text .= "\t\t\t\tmgr.addMarkers(markers, layer[\"zoom\"][0], layer[\"zoom\"][1]);\n";
	$script2_text .= "\t\t\t}";
	$script2_text .= "\t\t\tmgr.refresh();\n";
	$script2_text .= "\t\t}\n";

	$script2_text .= "\t//]]\n";
	

	$script2->appendChild( $session->make_text( $script2_text ) );
	$head->appendChild($script2);


	my $body = $session->make_element("body",
		"onload"=>"load()", 
		"onunload"=>"GUnload()");
	
	my $div1 = $session->make_element("div",
		"id"=>"map",
		"style"=>"width: 80%; height: 600px");

	my $div = $session->make_element("div",
                "align"=>"center");	

	my $heading = $session->make_element( "h1" );
        $heading->appendChild ($session->make_text ( "EPrints3 MapPlot (Google Maps API)" ));
        my $hr = $session->make_element( "hr" );
        $heading->appendChild( $hr );
        $body->appendChild( $heading );
        $div->appendChild( $div1 );
        $body->appendChild( $div );
        $html->appendChild( $body );

	my $flightplan = <<END;
<?xml version="1.0" encoding="utf-8" ?>
END
	$flightplan .= EPrints::XML::to_string( $html );
	EPrints::XML::dispose( $html );

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $flightplan;
		return undef;
	} 

	return $flightplan;
}

sub create_layer
{
	my ($hash, $zoom_min, $zoom_max) = @_;

	my $jstring;

	$jstring = "\t\t\t{\n";
	$jstring .= "\t\t\t\t\"zoom\": [$zoom_min,$zoom_max],\n";
	$jstring .= "\t\t\t\t\"places\": [\n";
	foreach my $key (keys %$hash) {
		my $minlat = $hash->{$key}->{minlat};
		my $maxlat = $hash->{$key}->{maxlat};
		my $minlong = $hash->{$key}->{minlong};
		my $maxlong = $hash->{$key}->{maxlong};
		#The issue still exists which will land you in problems if the average lat long puts you in a different country, unlikely in most countries.
		my $avelat = $minlat + (($maxlat-$minlat)/2);
		my $avelong = $minlong + (($maxlong-$minlong)/2);
		$jstring .= "\t\t\t\t\t{\n";
		$jstring .= "\t\t\t\t\t\t\"name\": \"$key\",\n";
		$jstring .= "\t\t\t\t\t\t\"posn\": [$avelat,$avelong],\n";
		my $result = join ('+br()+', @{$hash->{$key}->{info}});
		$jstring .= "\t\t\t\t\t\t\"info\": lt()+\"div align='left'\"+gt()+b()+\"Country Code: $key \"+closeb()+br()+$result+lt()+\"div\"+gt(),\n";
		$jstring .= "\t\t\t\t\t\t\"eprint_ids\": [" . join (',',@{$hash->{$key}->{ids}}) . "],\n";
		$jstring .= "\t\t\t\t\t},\n";
	}
	$jstring .= "\t\t\t\t],\n";
	$jstring .= "\t\t\t},\n";
	return $jstring;
}

sub populate_scope_hash
{
	my ($hash, $key, $lat, $long, $citation, $eprint_id) = @_;

	if (!defined $hash->{$key}) {
		$hash->{$key} = {
			minlat => $lat,
			maxlat => $lat,
			minlong => $long,
			maxlong => $long,
			info => [$citation],
			ids => [$eprint_id],
		};
	} else {
		if (($hash->{$key}->{minlat})>$lat) {
			($hash->{$key}->{minlat})=$lat;
		} elsif (($hash->{$key}->{maxlat})<$lat) {
			($hash->{$key}->{maxlat})=$lat;
		}
		if (($hash->{$key}->{minlong})>$long) {
			($hash->{$key}->{minlong})=$long;
		} elsif (($hash->{$key}->{maxlong})<$long) {
			($hash->{$key}->{maxlong})=$long;
		}
		push(@{$hash->{$key}->{info}},$citation);
		push(@{$hash->{$key}->{ids}},$eprint_id);
	}

}

1;
