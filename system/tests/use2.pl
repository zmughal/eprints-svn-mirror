#!/usr/bin/perl -w  

use TestLib;
use Test::More tests => 34;


use_ok('EPrints::AnApache');
use_ok('EPrints::Archive');
use_ok('EPrints::Auth');
use_ok('EPrints::Config');
use_ok('EPrints::Database');
use_ok('EPrints::DataObj');
use_ok('EPrints::DataSet');
use_ok('EPrints::Document');
use_ok('EPrints::EPrint');
use_ok('EPrints::Extras');
use_ok('EPrints::ImportXML');
use_ok('EPrints::Index');
use_ok('EPrints::Language');
use_ok('EPrints::Latex');
use_ok('EPrints::MetaField');
use_ok('EPrints::OpenArchives');
use_ok('EPrints::Paracite');
use_ok('EPrints::Probity');
use_ok('EPrints::RequestWrapper2');
use_ok('EPrints::Rewrite');
use_ok('EPrints::SearchCondition');
use_ok('EPrints::SearchExpression');
use_ok('EPrints::SearchField');
use_ok('EPrints::Session');
use_ok('EPrints::Subject');
use_ok('EPrints::SubmissionForm');
use_ok('EPrints::Subscription');
use_ok('EPrints::SystemSettings');
use_ok('EPrints::UserForm');
use_ok('EPrints::UserPage');
use_ok('EPrints::User');
use_ok('EPrints::Utils');
use_ok('EPrints::VLit');
use_ok('EPrints::XML');

#TODO: {
#	      local $TODO = "Don't have mod_perl v1 tests yet";
#
#	use_ok('EPrints::RequestWrapper');
#      }

