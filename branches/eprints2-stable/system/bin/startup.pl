use lib '/opt/ep2stable/perl_lib';

######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

print STDERR "EPRINTS: Loading Core Modules\n";

## Apache::DBI MUST come before other modules using DBI or
## you won't get constant connections and everything
## will go horribly wrong...

use Carp qw(verbose);

BEGIN
{
	use EPrints::SystemSettings;
	my $av =  $EPrints::SystemSettings::conf->{apache_version};
	if( defined $av && $av eq "2" )
	{
        	eval 'use Apache2; use Apache::compat;'; die $@ if $@;
	}
}

use Apache::DBI;
#$Apache::DBI::DEBUG = 3;
use Apache::Registry;



$ENV{MOD_PERL} or EPrints::Utils::abort( "not running under mod_perl!" );

use EPrints::XML;
use EPrints::Utils;
use EPrints::Config;

# This code is interpreted *once* when the server starts
use EPrints::Archive;
use EPrints::Auth;
use EPrints::Database;
use EPrints::Document;
use EPrints::EPrint;
use EPrints::Extras;
use EPrints::ImportXML;
use EPrints::Language;
use EPrints::Latex;
use EPrints::MetaField;
use EPrints::OpenArchives;
use EPrints::Rewrite;
use EPrints::SearchExpression;
use EPrints::SearchField;
use EPrints::Session;
use EPrints::Subject;
use EPrints::SubmissionForm;
use EPrints::Subscription;
use EPrints::UserForm;
use EPrints::User;
use EPrints::UserPage;
use EPrints::VLit;
use EPrints::Paracite;

use strict;

print STDERR "********LOADED USE STUFF BONG\n";

EPrints::Config::ensure_init();

print STDERR "EPRINTS: Core Modules Loaded\n";

# cjg SYSTEM CONF SHOULD SAY IF TO PRELOAD OR NOT...

print STDERR "EPRINTS: Loading Config Modules\n";
my %done = ();
foreach( EPrints::Config::get_archive_ids() )
{
	next if $done{$_};
	EPrints::Archive->new_archive_by_id( $_ );
}
print STDERR "EPRINTS: Config Modules Loaded\n";

# Tell me more about warnings
$SIG{__WARN__} = \&Carp::cluck;

1;
