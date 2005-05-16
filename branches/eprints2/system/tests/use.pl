#!/usr/bin/perl -w  

use TestLib;
use Test::More tests => 35;


testmodule('EPrints::AnApache');
testmodule('EPrints::Archive');
testmodule('EPrints::Auth');
testmodule('EPrints::Config');
testmodule('EPrints::Database');
testmodule('EPrints::DataObj');
testmodule('EPrints::DataSet');
testmodule('EPrints::Document');
testmodule('EPrints::EPrint');
testmodule('EPrints::Extras');
testmodule('EPrints::ImportXML');
testmodule('EPrints::Index');
testmodule('EPrints::Language');
testmodule('EPrints::Latex');
testmodule('EPrints::MetaField');
testmodule('EPrints::OpenArchives');
testmodule('EPrints::Paracite');
testmodule('EPrints::Probity');
testmodule('EPrints::RequestWrapper2');
testmodule('EPrints::Rewrite');
testmodule('EPrints::SearchCondition');
testmodule('EPrints::SearchExpression');
testmodule('EPrints::SearchField');
testmodule('EPrints::Session');
testmodule('EPrints::Subject');
testmodule('EPrints::SubmissionForm');
testmodule('EPrints::Subscription');
testmodule('EPrints::SystemSettings');
testmodule('EPrints::UserForm');
testmodule('EPrints::UserPage');
testmodule('EPrints::User');
testmodule('EPrints::Utils');
testmodule('EPrints::VLit');
testmodule('EPrints::XML');

TODO: {
	      local $TODO = "Don't have mod_perl v1 tests yet";

	testmodule('EPrints::RequestWrapper');
      }

sub testmodule
{
	my( $module ) = @_;
	my $code = "use TestLib; use $module; print \"1\";";
	my $exec = "/usr/bin/perl -w -e '$code'";
	$rc = `$exec`;
	ok($rc, $module);
}

# not yet doing MetaField/x*
# not yet doing bundled modules
