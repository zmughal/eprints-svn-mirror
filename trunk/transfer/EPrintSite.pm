
#cjg headers?


# This modules contains stuff
# common to this installation of eprints.

package EPrintSite;

$EPrintSite::base_path = "/opt/eprints";

$EPrintSite::log_language = "english";

%EPrintSite::languages = (
	"dummy"=>	"$EPrintSite::base_path/intl/dummy",
	"french"=>	"$EPrintSite::base_path/intl/french",
	"us"=>		"$EPrintSite::base_path/intl/us",
	"english"=>	"$EPrintSite::base_path/intl/english"
);






1;
