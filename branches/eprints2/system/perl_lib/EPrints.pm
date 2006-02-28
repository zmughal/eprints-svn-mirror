package EPrints;

use EPrints::SystemSettings;

BEGIN {
	use Carp qw(cluck);

	# Paranoia: This may annoy people, or help them... cjg

	# mod_perl will probably be running as root for the main httpd.
	# The sub processes should run as the same user as the one specified
	# in $EPrints::SystemSettings
	# An exception to this is running as root (uid==0) in which case
	# we can become the required user.
	unless( $ENV{MOD_PERL} ) 
	{
		#my $req($login,$pass,$uid,$gid) = getpwnam($user)
		my $req_username = $EPrints::SystemSettings::conf->{user};
		my $req_group = $EPrints::SystemSettings::conf->{group};
		my $req_uid = (getpwnam($req_username))[2];
		my $req_gid = (getgrnam($req_group))[2];

		my $username = (getpwuid($>))[0];
		if( $> == 0 )
		{
			# Special case: Running as root, we change the 
			# effective UID to be the one required in
			# EPrints::SystemSettings

			# remember kids, change the GID first 'cus you
			# can't after you change from root UID.
			$) = $( = $req_gid;
			$> = $< = $req_uid;
		}
		elsif( $username ne $req_username )
		{
			abort( 
"We appear to be running as user: ".$username."\n".
"We expect to be running as user: ".$req_username );
		}
		# otherwise ok.
	}

	# abort($err) Defined here so modules can abort even at startup
######################################################################
=pod

=item EPrints::abort( $msg )

Print an error message and exit. If running under mod_perl then
print the error as a webpage and exit.

This subroutine is loaded before other modules so that it may be
used to report errors when initialising modules.

=cut
######################################################################

	sub abort
	{
		my( $errmsg ) = @_;

		my $r;
		if( $ENV{MOD_PERL} && $EPrints::SystemSettings::loaded)
		{
			$r = EPrints::AnApache::get_request();
		}
		if( defined $r )
		{
			# If we are running under MOD_PERL
			# AND this is actually a request, not startup,
			# then we should print an explanation to the
			# user in addition to logging to STDERR.

			$r->content_type( 'text/html' );
			EPrints::AnApache::send_http_header( $r );
			print <<END;
<html>
  <head>
    <title>EPrints System Error</title>
  </head>
  <body>
    <h1>EPrints System Error</h1>
    <p><tt>$errmsg</tt></p>
  </body>
</html>
END
		}

		
		print STDERR <<END;
	
------------------------------------------------------------------
---------------- EPrints System Error ----------------------------
------------------------------------------------------------------
$errmsg
------------------------------------------------------------------
END
		$@="";
		cluck( "EPrints System Error inducing stack dump\n" );
		exit;
		#exit;
	}
}

use EPrints::AnApache;
use EPrints::BackCompatibility;
use EPrints::XML;
use EPrints::Utils;
use EPrints::Config;
use EPrints::Auth;
use EPrints::Database;
use EPrints::DataObj;
use EPrints::DataObj::Access;
use EPrints::DataObj::Document;
use EPrints::DataObj::EPrint;
use EPrints::DataObj::History;
use EPrints::DataObj::License;
use EPrints::DataObj::Permission;
use EPrints::DataObj::Subject;
use EPrints::DataObj::Subscription;
use EPrints::DataObj::User;
use EPrints::DataSet;
use EPrints::Extras;
use EPrints::Index;
use EPrints::ImportXML;
use EPrints::Language;
use EPrints::Latex;
use EPrints::List;
use EPrints::MetaField;
use EPrints::OpenArchives;
use EPrints::Probity;
use EPrints::Repository;
use EPrints::Rewrite;
use EPrints::Search;
use EPrints::Search::Field;
use EPrints::Search::Condition;
use EPrints::Session;
use EPrints::SubmissionForm;
use EPrints::UserForm;
use EPrints::UserPage;
use EPrints::VLit;
use EPrints::Paracite;
use EPrints::Workflow;
use EPrints::Workflow::Stage;
use EPrints::Workflow::Processor;

1;
