use lib '/opt/eprints/perl_lib';
use strict;

######################################################################
#
# COMMENTME
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

print STDERR "EPRINTS: Loading Modules\n";

## Apache::DBI MUST come before other modules using DBI or
## you won't get constant connections and everything
## will go horribly wrong...

use Apache::DBI;
$Apache::DBI::DEBUG = 3;
use Apache::Registry;          

use EPrints::Utils;
use EPrints::Config;

$ENV{MOD_PERL} or EPrints::Utils::abort( "not running under mod_perl!" );
 
# This code is interpreted *once* when the server starts

use EPrints::Auth;
use EPrints::Database;
use EPrints::Deletion;
use EPrints::Document;
use EPrints::EPrint;
use EPrints::HTMLRender;
use EPrints::ImportXML;
use EPrints::Language;
use EPrints::MetaField;
use EPrints::OpenArchives;
use EPrints::Archive;
use EPrints::SearchExpression;
use EPrints::SearchField;
use EPrints::Session;
use EPrints::Subject;
use EPrints::SubmissionForm;
use EPrints::Subscription;
use EPrints::UserForm;
use EPrints::User;

print STDERR "EPRINTS: Modules Loaded\n";

# cjg SYSTEM CONF SHOULD SAY IF TO PRELOAD OR NOT...

my %done = ();
foreach( EPrints::Config::get_archive_ids() )
{
	next if $done{$_};
	print STDERR "Preloading: ".$_."\n";
	EPrints::Archive->new_archive_by_id( $_ );
}


# Tell me more about warnings
use Carp ();
$SIG{__WARN__} = \&Carp::cluck;

1;
