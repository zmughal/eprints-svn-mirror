
#cjg headers?


# This modules contains stuff
# common to this installation of eprints.

package EPrints::Site::General;

$EPrints::Site::General::base_path = "/opt/eprints";

$EPrints::Site::General::log_language = "english";

$EPrints::Site::General::lang_path = 
	$EPrints::Site::General::base_path."/intl";

%EPrints::Site::General::languages = (
	"dummy" => "Demonstration Other Language",
	"french" => "Fran�ais",
	"english" => "English"
);


#English Espa�ol Deutsch Fran�ais Italiano

%EPrints::Site::General::sites = (
	"destiny.totl.net" => "lemurprints",
	"lemur.ecs.soton.ac.uk" => "lemurprints"
);





1;
