# MapPlot Eprints Mapping Plugin (Google Maps API)
# Part of EPrints3 
# Distributed under GPL Licience
#
# Package Written by David Tarrant (dct05r@ecs.soton.ac.uk) & Mike Jewell (moj@ecs.soton.ac.uk)
#
# IMPORTANT INFORMATION
#  Installation Instructions
#
#    Before you can use this plugin with your repository you need to register with the Google Maps service and obtain a key for the 
#    url of your repository. 
#
#    To do this put enter the base URL of your repository into the registration page at http://www.google.com/apis/maps/signup.html
#
#    Enter your key below at the line which currently reads:
#    my $google_key = "";  
#


package EPrints::Plugin::Export::MapPlot;

use EPrints::Plugin::Export;
use HTML::Entities ();
use XML::Parser;
use LWP::Simple;

@ISA = ( "EPrints::Plugin::Export" );

use Unicode::String qw(latin1);

use strict;
my $google_key = "";

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
		"src"=>"http://maps.google.com/maps?file=api&v=2.67&key=$google_key",
		"type"=>"text/javascript");


	$head->appendChild ($script1);

	#build script2_var

	my $script2_varAll = $session->make_element("script",
                "type"=>"text/javascript");

	my %coordinates;
	my $countryData = {};
	my $locationData = {};

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
			$cite = "lt()+\"a href='$link'\"+gt()+\"$cite\"+lt()+\"/a\"+gt()";
			push(@{$coordinates{"$latitude:$longitude"}},$cite);
			#push(@{$coordinates{"$latitude:$longitude"}},EPrints::XML::to_string($eprint->render_citation( "brief" )));
		}
	}

	foreach my $key ( keys %coordinates ) {
		my ($lat, $long) = split(/:/, $key);
		my $values = $coordinates{$key};
		
		my $result = join ("+br()+", @$values);
		
		my $xml = get("http://ws.geonames.org/findNearbyPlaceName?lat=$lat&lng=$long");
		print STDERR "http://ws.geonames.org/findNearbyPlaceName?lat=$lat&lng=$long\n\n\n";
		my $dom = EPrints::XML::parse_xml_string( $xml );

		my @country = $dom->getElementsByTagName( "countryCode" );
		my @location = $dom->getElementsByTagName( "name" );
		my $countryString = $country[0]->getFirstChild->getNodeValue;
		my $locationString = $location[0]->getFirstChild->getNodeValue;	

		if (!defined $countryData->{"$countryString"}) {
			$countryData->{"$countryString"} = {};
			$countryData->{"$countryString"}->{minlat} = $lat;
			$countryData->{"$countryString"}->{maxlat} = $lat;
			$countryData->{"$countryString"}->{minlong} = $long;
			$countryData->{"$countryString"}->{maxlong} = $long;
			push(@{$countryData->{"$countryString"}->{info}},$result);
		} else {
			if (($countryData->{"$countryString"}->{minlat})>$lat) {
				($countryData->{"$countryString"}->{minlat})=$lat;
			} elsif (($countryData->{"$countryString"}->{maxlat})<$lat) {
                        	($countryData->{"$countryString"}->{maxlat})=$lat;
			}
			if (($countryData->{"$countryString"}->{minlong})>$long) {
                	        ($countryData->{"$countryString"}->{minlong})=$long;
	                } elsif (($countryData->{"$countryString"}->{maxlong})<$long) {
        	                ($countryData->{"$countryString"}->{maxlong})=$long;
	                }		
			push(@{$countryData->{"$countryString"}->{info}},$result);
		}
	
		if ($locationString eq "Bassett") {$locationString="Southampton";}
		if ($locationString eq "Paddington") {$locationString="London";}
		if ($locationString eq "Saint Pancras") {$locationString="London";}
		if ($locationString eq "Bloomsbury") {$locationString="London";}
		if (!defined $locationData->{"$locationString"}) {
                        $locationData->{"$locationString"} = {};
                        $locationData->{"$locationString"}->{minlat} = $lat;
                        $locationData->{"$locationString"}->{maxlat} = $lat;
                        $locationData->{"$locationString"}->{minlong} = $long;
                        $locationData->{"$locationString"}->{maxlong} = $long;
                        push(@{$locationData->{"$locationString"}->{info}},$result);
                } else {
                        if (($locationData->{"$locationString"}->{minlat})>$lat) {
                                ($locationData->{"$locationString"}->{minlat})=$lat;
                        } elsif (($locationData->{"$locationString"}->{maxlat})<$lat) {
                                ($locationData->{"$locationString"}->{maxlat})=$lat;
                        }
                        if (($locationData->{"$locationString"}->{minlong})>$long) {
                                ($locationData->{"$locationString"}->{minlong})=$long;
                        } elsif (($locationData->{"$locationString"}->{maxlong})<$long) {
                                ($locationData->{"$locationString"}->{maxlong})=$long;
                        }
                        push(@{$locationData->{"$locationString"}->{info}},$result);
                }

	}

	my $script2_var = "function br() { return String.fromCharCode(60,98,114,47,62) };\n\n";
	$script2_var .= "function b() { return String.fromCharCode(60,98,62) };\n\n";
	$script2_var .= "function closeb() { return String.fromCharCode(60,47,98,62) };\n\n";
	$script2_var .= "function lt() { return String.fromCharCode(60) };\n\n";
	$script2_var .= "function gt() { return String.fromCharCode(62) };\n\n";

	$script2_var .= "\t\tvar eprintsLayer = [\n";
	$script2_var .= "\t\t\t{\n";
	$script2_var .= "\t\t\t\t\"zoom\": [0,3],\n";
	$script2_var .= "\t\t\t\t\"places\": [\n";	
	foreach my $key (keys %$countryData) {
                my $minlat = $countryData->{$key}->{minlat};
		my $maxlat = $countryData->{$key}->{maxlat};
		my $minlong = $countryData->{$key}->{minlong};
		my $maxlong = $countryData->{$key}->{maxlong};
		#ARG FIX AS LAT * LONG GO FROM -180 to 180 so your screwed if a country is on the border.
		my $avelat = $minlat + (($maxlat-$minlat)/2);
		my $avelong = $minlong + (($maxlong-$minlong)/2);
		$script2_var .= "\t\t\t\t\t{\n";
		$script2_var .= "\t\t\t\t\t\t\"name\": \"$key\",\n";
		$script2_var .= "\t\t\t\t\t\t\"posn\": [$avelat,$avelong],\n";

		#LIMIT AND COUNT HERE;		
		
		my @values = @{$countryData->{$key}->{info}};
        	
		my $result = join ('+br()+', @values);
		$script2_var .= "\t\t\t\t\t\t\"info\": lt()+\"div align='left'\"+gt()+b()+\"Country Code: $key \"+closeb()+br()+$result+lt()+\"div\"+gt(),\n";

		$script2_var .= "\t\t\t\t\t},\n";
        }
	$script2_var .= "\t\t\t\t]\n";
	$script2_var .= "\t\t\t},\n";
	
	$script2_var .= "\t\t\t{\n";
        $script2_var .= "\t\t\t\t\"zoom\": [4,8],\n";
        $script2_var .= "\t\t\t\t\"places\": [\n";
	foreach my $key (keys %$locationData) {
                my $minlat = $locationData->{$key}->{minlat};
                my $maxlat = $locationData->{$key}->{maxlat};
                my $minlong = $locationData->{$key}->{minlong};
                my $maxlong = $locationData->{$key}->{maxlong};
                #ARG FIX AS LAT * LONG GO FROM -180 to 180 so your screwed if a country is on the border.
                my $avelat = $minlat + (($maxlat-$minlat)/2);
                my $avelong = $minlong + (($maxlong-$minlong)/2);
                $script2_var .= "\t\t\t\t\t{\n";
                $script2_var .= "\t\t\t\t\t\t\"name\": \"$key\",\n";
                $script2_var .= "\t\t\t\t\t\t\"posn\": [$avelat,$avelong],\n";

                #LIMIT AND COUNT HERE;

                my @values = @{$locationData->{$key}->{info}};

                my $result = join ("+br()+", @values);
                $script2_var .= "\t\t\t\t\t\t\"info\": lt()+\"div align='left'\"+gt()+b()+\"Location: $key \"+closeb()+br()+$result+lt()+\"div\"+gt(),\n";

                $script2_var .= "\t\t\t\t\t},\n";
        }
	$script2_var .= "\t\t\t\t]\n";
        $script2_var .= "\t\t\t},\n";

	$script2_var .= "\t\t\t{\n";
	$script2_var .= "\t\t\t\t\"zoom\": [9,17],\n";
        $script2_var .= "\t\t\t\t\"places\": [\n";
	foreach my $key ( keys %coordinates ) {
		my ($lat, $long) = split(/:/, $key);
                my $values = $coordinates{$key};
                my $result = join ("+br()+", @$values);

		$script2_var .= "\t\t\t\t\t{\n";
                $script2_var .= "\t\t\t\t\t\t\"posn\": [$lat,$long],\n";
		$script2_var .= "\t\t\t\t\t\t\"info\": lt()+\"div align='left'\"+gt()+$result+lt()+\"div\"+gt(),\n";
		$script2_var .= "\t\t\t\t\t},\n";
	}
	$script2_var .= "\t\t\t\t]\n";
        $script2_var .= "\t\t\t}\n";
	$script2_var .= "\t\t];\n";

	$script2_varAll->appendChild( $session->make_text( $script2_var ) );
        $head->appendChild($script2_varAll);	


	# build script2 as text	
	my $script2 = $session->make_element("script",
		"type"=>"text/javascript");
	

	#my $script2_text = "alert (window.location.protocol + window.location.host + window.location.pathname);";
	my $script2_text .= "\n\t//CDATA[\n\t\tvar map=null;\n\t\tvar batch = [];\n";
	$script2_text .= "\n\n";
	$script2_text .= "\t\tfunction EPrintMarker( lat, lon, info ) {\n";
	$script2_text .= "\t\t\tvar currmarker = new GMarker(new GLatLng( lat,lon ) );\n";
	$script2_text .= "\t\t\tGEvent.addListener(currmarker, \"click\", function() {\n";
	$script2_text .= "\t\t\t\tcurrmarker.openInfoWindowHtml(info);\n";
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
	$script2_text .= "\t\t\t\t\tmarkers.push(EPrintMarker(place[\"posn\"][0], place[\"posn\"][1],place[\"info\"]));\n";
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

1;

