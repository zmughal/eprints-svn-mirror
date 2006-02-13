use lib '/opt/ep2stable/perl_lib';

BEGIN
{
	use EPrints::SystemSettings;

	my $conf_v = $ENV{EPRINTS_APACHE};
	if( defined $conf_v )
	{
		my $av =  $EPrints::SystemSettings::conf->{apache};
		$av = "1" unless defined $av;

		my $mismatch = 0;
		$mismatch = 1 if( $av eq "2" && $conf_v ne "2" );
		$mismatch = 1 if( $av ne "2" && $conf_v ne "1" );
		if( $mismatch )
		{
			print STDERR <<END;

------------------------------------------------------------
According to a flag in the Apache configuration, the part
of it relating to EPrints was generated for running with 
Apache $conf_v but this version of EPrints is configured 
to use version $av of Apache.

You should probably check the "apache" parameter setting in
perl_lib/EPrints/SystemSettings.pm then run the script
generate_apacheconf, then try to start Apache again.
------------------------------------------------------------

END
			die "Apache version mismatch";
		}
	}
}
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

## Apache::DBI MUST come before other modules using DBI or
## you won't get constant connections and everything
## will go horribly wrong...

use Carp qw(verbose);

use EPrints::AnApache;

use Apache::DBI;
#$Apache::DBI::DEBUG = 3;

$ENV{MOD_PERL} or EPrints::Config::abort( "not running under mod_perl!" );

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
use EPrints::SearchCondition;
use EPrints::Session;
use EPrints::Subject;
use EPrints::SubmissionForm;
use EPrints::Subscription;
use EPrints::UserForm;
use EPrints::User;
use EPrints::UserPage;
use EPrints::VLit;
use EPrints::Paracite;
use EPrints::Workflow;
use EPrints::Workflow::Stage;
use EPrints::Workflow::Processor;

use strict;


EPrints::Config::ensure_init();

my %done = ();
foreach( EPrints::Config::get_archive_ids() )
{
	next if $done{$_};
	EPrints::Archive->new_archive_by_id( $_ );
}
print STDERR "EPrints archives loaded: ".join( ", ",  EPrints::Config::get_archive_ids() )."\n";

# Tell me more about warnings
$SIG{__WARN__} = \&Carp::cluck;

$EPrints::SystemSettings::loaded = 1;
1;
