

#cjg headers?


# This modules contains stuff
# common to this installation of eprints.

package EPrints::Archives::General;

use Unicode::String qw(utf8 latin1 utf16);

$EPrints::Archives::General::base_path = "/opt/eprints";
$EPrints::Archives::General::cgi_path = 
		$EPrints::Archives::General::base_path."/cgi";

$EPrints::Archives::General::lang_path = 
		$EPrints::Archives::General::base_path."/system-phrases";

%EPrints::Archives::General::languages = (
	"du" => latin1( "Demonstration Other Language" ),
	"fr" => latin1( "Fran�ais" ),
	"en" => latin1( "English" )
);


#English Espa�ol Deutsch Fran�ais Italiano

%EPrints::Archives::General::archives = (
	"destiny.totl.net" => "lemurprints",
	"destiny" => "lemurprints",
	"lemur.ecs.soton.ac.uk" => "lemurprints",
	"localhost" => "lemurprints"
);





1;
