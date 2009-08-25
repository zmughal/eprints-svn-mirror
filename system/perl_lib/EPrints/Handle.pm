######################################################################
#
# EPrints::Handle
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


=pod

=head1 NAME

B<EPrints::Handle> - Single connection to the EPrints system

=head1 SYNOPSIS

	# cgi script	
	$handle = EPrints->get_handle();
	exit( 1 ) unless( defined $handle );

	# bin script
	$handle = EPrints->get_handle( repository => $repository_id, noise => $noise );

	$repository = $handle->get_repository;
	$dataset = $handle->get_dataset( $dataset_id );
	$handle->log( "Something bad occurred" );
	$conf = $handle->get_conf( "base_url" );

	$eprint = $handle->get_live_eprint( $eprint_id );
	$eprint = $handle->get_eprint( $eprint_id );
	$user = $handle->get_user( $user_id );
	$user = $handle->get_user_with_username( $username );
	$user = $handle->get_user_with_email( $email );
	$document = $handle->get_document( $doc_id );
	$subject = $handle->get_subject( $subject_id );

	$handle->terminate

=head1 DESCRIPTION

EPrints::Handle represents a connection to the EPrints system. It
connects to a single EPrints repository, and the database used by
that repository. Thus it has an associated EPrints::Database and
EPrints::Repository object.

Each "handle" has a current language. If you are running in a 
multilingual mode, this is used by the HTML rendering functions to
choose what language to return text in. See EPrints::Handle::Language for
the language specific methods.

The "session" object also knows about the current apache connection,
if there is one, including the CGI parameters. 

If the connection requires a username and password then it can also 
give access to the EPrints::DataObj::User object representing the user who is
causing this request. 

The session object also provides many methods for creating XHTML 
results which can be returned via the web interface. 

Specific sets of functions are documented in:

=over 8

L<EPrints::Handle::XML> - XML DOM utilties.  

L<EPrints::Handle::Render> - XHTML generating utilities.  

L<EPrints::Handle::Language> - I18L methods.  

L<EPrints::Handle::Page> - XHTML Page and templating methods.  

L<EPrints::Handle::CGI> - Methods for detail with the web-interface.  

=back

=head1 METHODS

These are general methods, not documented in the above modules.

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{repository}
#     The EPrints::Repository object this session relates to.
#
#  $self->{database}
#     A EPrints::Database object representing this session's connection
#     to the database.
#
#  $self->{noise}
#     The "noise" level which this connection should run at. Zero 
#     will produce only error messages. Higher numbers will produce
#     more warnings and commentary.
#
#  $self->{request}
#     A mod_perl object representing the request to apache, if any.
#
#  $self->{query}
#     A CGI.pm object also representing the request, if any.
#
#  $self->{offline}
#     True if this is a command-line script.
#
#  $self->{doc}
#     A XML DOM document object. All XML created by this session will
#     be part of this document.
#
#  $self->{page}
#     Used to store the output XHTML page between "prepage_page" and
#     "send_page"
#
#  $self->{lang}
#     The current language that this session should use. eg. "en" or "fr"
#     It is used to determine which phrases and template will be used.
#
######################################################################


package EPrints::Handle;

use EPrints;
use EPrints::Handle::XML;
use EPrints::Handle::Render;
use EPrints::Handle::Language;
use EPrints::Handle::Page;
use EPrints::Handle::CGI;

#use URI::Escape;
use CGI qw(-compile);

use strict;
#require 'sys/syscall.ph';

######################################################################
# $handle = EPrints::Handle->new( %opts )
# 
# See EPrints.pm for details.
######################################################################

sub new
{
	my( $class, %opts ) = @_;

	$opts{check_database} = 1 if( !defined $opts{check_database} );
	$opts{consume_post_data} = 1 if( !defined $opts{consume_post_data} );
	$opts{noise} = 0 if( !defined $opts{noise} );

	my $self = {};
	bless $self, $class;

	$self->{noise} = $opts{noise};
	$self->{used_phrases} = {};

	if( defined $opts{repository} )
	{
		$self->{offline} = 1;
		$self->{repository} = EPrints->get_repository( $opts{repository} );
		if( !defined $self->{repository} )
		{
			print STDERR "Can't load repository module for: ".$opts{repository}."\n";
			return undef;
		}
		$opts{consume_post_data} = 0;
	}
	else
	{
		if( !$ENV{MOD_PERL} )
		{
			EPrints::abort( "No repository specified, but not running under mod_perl." );
		}
		$self->{request} = EPrints::Apache::AnApache::get_request();
		$self->{offline} = 0;
		$self->{repository} = EPrints::Repository->new_from_request( $self->{request} );
	}

	#### Got Repository Config Module ###

	if( $self->{noise} >= 2 ) { print "\nStarting EPrints Session.\n"; }

	$self->_add_http_paths;

	if( $self->{offline} )
	{
		# Set a script to use the default language unless it 
		# overrides it
		$self->change_lang( 
			$self->{repository}->get_conf( "defaultlanguage" ) );
	}
	else
	{
		# running as CGI, Lets work out what language the
		# client wants...
		$self->change_lang( get_language( 
			$self->{repository}, 
			$self->{request} ) );
	}
	
	$self->{doc} = EPrints::XML::make_document;

	# Create a database connection
	if( $self->{noise} >= 2 ) { print "Connecting to DB ... "; }
	$self->{database} = EPrints::Database->new( $self );
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->render_error( $self->html_phrase( 
			"lib/session:fail_db_connect" ) );
		return undef;
	}

	# Check there are some tables.
	# Well, check for the most important table, which 
	# if it's not there is a show stopper.
	if( $opts{check_database} && !$self->{database}->is_latest_version )
	{ 
		my $cur_version = $self->{database}->get_version || "unknown";
		if( $self->{database}->has_table( "eprint" ) )
		{	
			EPrints::abort(
	"Database tables are in old configuration (version $cur_version). Please run:\nepadmin upgrade ".$self->get_repository->get_id );
		}
		else
		{
			EPrints::abort(
	"No tables in the MySQL database! Did you run create_tables?" );
		}
		$self->{database}->disconnect();
		return undef;
	}

	$self->{storage} = EPrints::Storage->new( $self );

	if( $self->{noise} >= 2 ) { print "done.\n"; }
	
	if( $opts{consume_post_data} ) { $self->read_params; }

	$self->{repository}->call( "session_init", $self, $self->{offline} );

	return( $self );
}

# add the relative paths + http_* config if not set already by cfg.d
sub _add_http_paths
{
	my( $self ) = @_;

	my $config = $self->{repository}->{config};

	$config->{"rel_path"} = $self->get_url(
		path => "static",
	);
	$config->{"rel_cgipath"} = $self->get_url(
		path => "cgi",
	);
	$config->{"http_url"} ||= $self->get_url(
		scheme => "http",
		host => 1,
		path => "static",
	);
	$config->{"http_cgiurl"} ||= $self->get_url(
		scheme => "http",
		host => 1,
		path => "cgi",
	);
	$config->{"https_url"} ||= $self->get_url(
		scheme => "https",
		host => 1,
		path => "static",
	);
	$config->{"https_cgiurl"} ||= $self->get_url(
		scheme => "https",
		host => 1,
		path => "cgi",
	);
}

######################################################################
=pod

=item $handle->terminate

Perform any cleaning up necessary, for example SQL cache tables which
are no longer needed.

=cut
######################################################################

sub terminate
{
	my( $self ) = @_;
	
	
	$self->{repository}->call( "session_close", $self );
	$self->{database}->disconnect();

	# If we've not printed the XML page, we need to dispose of
	# it now.
	EPrints::XML::dispose( $self->{doc} );

	if( $self->{noise} >= 2 ) { print "Ending EPrints Session.\n\n"; }

	# give garbage collection a hand.
	foreach( keys %{$self} ) { delete $self->{$_}; } 
}





######################################################################
# 
# $id = $handle->get_next_id
#
# Return a number unique within this session. Used to generate id's
# in the HTML.
#
# DO NOT use this to generate anything other than id's for use in the
# workflow. Some tools will need to reset this value when the workflow
# is generated more than once in a single session.
#
######################################################################

sub get_next_id
{
	my( $self ) = @_;

	if( !defined $self->{id_counter} )
	{
		$self->{id_counter} = 1;
	}

	return $self->{id_counter}++;
}

######################################################################
=pod

=item $db = $handle->get_database

Return the current EPrints::Database connection object.

=cut
######################################################################

sub get_database
{
	my( $self ) = @_;
	return $self->{database};
}

=item $store = $handle->get_storage

Return the storage control object. See EPrints::Storage for details.

=cut

sub get_storage
{
	my( $self ) = @_;
	return $self->{storage};
}



######################################################################
=pod

=item $repository = $handle->get_repository

Return the EPrints::Repository object associated with the Session.

=cut
######################################################################

sub get_repository
{
	my( $self ) = @_;

	return $self->{repository};
}

######################################################################
=pod

=item $dataset = $handle->get_dataset( $dataset_id )

This is an alias for $handle->get_repository->get_dataset( $dataset_id ) to make for more readable code.

Returns the named EPrints::DataSet for the repository or undef.

=cut
######################################################################

sub get_dataset
{
	my( $self, $dataset_id ) = @_;

	return $self->{repository}->get_dataset( $dataset_id );
}

######################################################################
=pod

=item $object = $handle->get_dataobj( $dataset_id, $object_id )

This is an alias for $handle->get_repository->get_dataset( $dataset_id )->get_object( $handle, $object_id ) to make for more readable code.

Returns the EPrints::DataObj for the specified dataset and object_id or undefined if either the dataset or object do not exist.

=cut
######################################################################

sub get_dataobj
{
	my( $self, $dataset_id, $object_id ) = @_;

	my $ds = $self->{repository}->get_dataset( $dataset_id, $object_id );

	return unless defined $ds;

	return $ds->get_object( $object_id );
}

######################################################################
=pod

=item $eprint = $handle->get_live_eprint( $eprint_id )

Return an eprint which is publically available (ie. in the "archive"
dataset). Use this in preference to $handle->get_eprint if you are 
making scripts where the output will be shown to the public.

Returns undef if the eprint does not exist, or is not public.

=cut
######################################################################

sub get_live_eprint
{
	my( $self, $eprint_id ) = @_;

	return $self->{repository}->{datasets}->{"archive"}->{class}->new( $self, $eprint_id );
}

######################################################################
=pod

=item $eprint = $handle->get_user_with_username( $username )

Return a user dataobj with the given username, or undef.

=cut
######################################################################

sub get_user_with_username
{
	my( $self, $username ) = @_;

	return EPrints::DataObj::User::user_with_username( $self, $username );
}

######################################################################
=pod

=item $eprint = $handle->get_user_with_email( $email )

Return a user dataobj with the given email, or undef.

=cut
######################################################################

sub get_user_with_email
{
	my( $self, $email ) = @_;

	return EPrints::DataObj::User::user_with_email( $self, $email );
}

######################################################################
=pod

=item $eprint = $handle->get_eprint( $eprint_id )

=item $user = $handle->get_user( $user_id )

=item $document = $handle->get_document( $document_id )

=item $file = $handle->get_file( $file_id )

=item $subject = $handle->get_subject( $subject_id )

This is an alias for $handle->get_dataset( ... )->get_object( ... ) to make for more readable code.

Any dataset may be accessed in this manner, but only the ones listed above should be considered part of the API.

=cut
######################################################################

sub AUTOLOAD
{
	my( $self, @params ) = @_;

	our $AUTOLOAD;

	if( $AUTOLOAD =~ m/^.*::get_(.*)$/ )
	{
		my $ds = $self->{repository}->{datasets}->{$1};
		if( defined $ds && defined $ds->{class} )
		{
			return $ds->{class}->new( $self, @params );
		}
	}

	EPrints::abort( "Unknown method '$AUTOLOAD' called on EPrints::Handle" );
}

######################################################################
=pod

=item $handle->log( $conf_id, ... )

This is an alias for $handle->get_repository->log( ... ) to make for more readable code.

Write a message to the current log file.

=cut
######################################################################

sub log
{
	my( $self, @params ) = @_;

	$self->{repository}->log( @params );
}

######################################################################
=pod

=item $confitem = $handle->get_conf( $key, [@subkeys] )

This is an alias for $handle->get_repository->get_conf( ... ) to make for more readable code.

Return a configuration value. Can go deeper down a tree of parameters.

eg. if 
	$conf = $handle->get_conf( "a" );
returns { b=>1, c=>2, d=>3 } then
	$conf = $handle->get_conf( "a","c" );
will return 2.

=cut
######################################################################

sub get_conf
{
	my( $self, @params ) = @_;

	return $self->{repository}->get_conf( @params );
}


######################################################################
=pod

=item $url = $handle->get_url( [ @OPTS ] [, $page] )

Utility method to get various URLs. See L<EPrints::URL>. With no arguments returns the same as get_uri().

	# Return the current static path
	$handle->get_url( path => "static" );

	# Return the current cgi path
	$handle->get_url( path => "cgi" );

	# Return a full URL to the current cgi path
	$handle->get_url( host => 1, path => "cgi" );

	# Return a full URL to the static path under HTTP
	$handle->get_url( scheme => "http", host => 1, path => "static" );

	# Return a full URL to the image 'foo.png'
	$handle->get_url( host => 1, path => "images", "foo.png" );

=cut
######################################################################

sub get_url
{
	my( $self, @opts ) = @_;

	my $url = EPrints::URL->new( handle => $self );

	return $url->get( @opts );
}


######################################################################
=pod

=item $noise_level = $handle->get_noise

Return the noise level for the current session. See the explaination
under EPrints->get_handle()

=cut
######################################################################

sub get_noise
{
	my( $self ) = @_;
	
	return( $self->{noise} );
}


######################################################################
=pod

=item $boolean = $handle->get_online

Return true if this script is running via CGI, return false if we're
on the command line.

=cut
######################################################################

sub get_online
{
	my( $self ) = @_;
	
	return( !$self->{offline} );
}




######################################################################
=pod

=item $plugin = $handle->plugin( $pluginid )

Return the plugin with the given pluginid, in this repository or, failing
that, from the system level plugins.

=cut
######################################################################

sub plugin
{
	my( $self, $pluginid, %params ) = @_;

	return $self->get_repository->get_plugin_factory->get_plugin( $pluginid,
		%params,
		handle => $self,
		);
}



######################################################################
# @plugin_ids  = $handle->plugin_list( %restrictions )
# 
# Return either a list of all the plugins available to this repository or
# return a list of available plugins which can accept the given 
# restrictions.
# 
# Restictions:
#  vary depending on the type of the plugin.
######################################################################

sub plugin_list
{
	my( $self, %restrictions ) = @_;

	return
		map { $_->get_id() }
		$self->{repository}->get_plugin_factory->get_plugins(
			{ handle => $self },
			%restrictions,
		);
}

######################################################################
# @plugins = $handle->get_plugins( [ $params, ] %restrictions )
# 
# Returns a list of plugin objects that conform to %restrictions (may be empty).
# 
# If $params is given uses that hash reference to initialise the 
# plugins. Always passes this session to the plugin constructor method.
######################################################################

sub get_plugins
{
	my( $self, @opts ) = @_;

	my $params = scalar(@opts) % 2 ?
		shift(@opts) :
		{};

	$params->{handle} = $self;

	return $self->{repository}->get_plugin_factory->get_plugins( $params, @opts );
}



######################################################################
# $spec = $handle->get_citation_spec( $dataset, [$ctype] )
# 
# Return the XML spec for the given dataset. If a $ctype is specified
# then return the named citation style for that dataset. eg.
# a $ctype of "foo" on the eprint dataset gives a copy of the citation
# spec with ID "eprint_foo".
# 
# This returns a copy of the XML citation spec., so that it may be 
# safely modified.
######################################################################

sub get_citation_spec
{
	my( $self, $dataset, $ctype ) = @_;

	my $ds_id = $dataset->confid();

	my $citespec = $self->{repository}->get_citation_spec( 
				$ds_id,
				$ctype );

	if( !defined $citespec )
	{
		return $self->make_text( "Error: Unknown Citation Style \"$ds_id.$ctype\"" );
	}
	
	my $r = $self->clone_for_me( $citespec, 1 );

	return $r;
}

sub get_citation_type
{
	my( $self, $dataset, $ctype ) = @_;

	my $ds_id = $dataset->confid();

	return $self->{repository}->get_citation_type( 
				$ds_id,
				$ctype );
}


######################################################################
# 
# $time = EPrints::Handle::microtime();
# 
# This function is currently buggy so just returns the time in seconds.
# 
# Return the time of day in seconds, but to a precision of microseconds.
# 
# Accuracy depends on the operating system etc.
# 
######################################################################

sub microtime
{
        # disabled due to bug.
        return time();

        my $TIMEVAL_T = "LL";
	my $t = "";
	my @t = ();

        $t = pack($TIMEVAL_T, ());

	syscall( &SYS_gettimeofday, $t, 0) != -1
                or die "gettimeofday: $!";

        @t = unpack($TIMEVAL_T, $t);
        $t[1] /= 1_000_000;

        return $t[0]+$t[1];
}



######################################################################
=pod

=item $ok = $handle->mail_administrator( $subjectid, $messageid, %inserts )

Sends a mail to the repository administrator with the given subject and
message body.

$subjectid is the name of a phrase in the phrase file to use
for the subject.

$messageid is the name of a phrase in the phrase file to use as the
basis for the mail body.

%inserts is a hash. The keys are the pins in the messageid phrase and
the values the utf8 strings to replace the pins with.

Returns true on success, false on failure.

=cut
######################################################################

sub mail_administrator
{
	my( $self,   $subjectid, $messageid, %inserts ) = @_;
	
	# Mail the admin in the default language
	my $langid = $self->{repository}->get_conf( "defaultlanguage" );
	return EPrints::Email::send_mail(
		handle => $self,
		langid => $langid,
		to_email => $self->{repository}->get_conf( "adminemail" ),
		to_name => $self->phrase( "lib/session:archive_admin" ),	
		from_email => $self->{repository}->get_conf( "adminemail" ),
		from_name => $self->phrase( "lib/session:archive_admin" ),	
		subject =>  EPrints::Utils::tree_to_utf8(
			$self->html_phrase( $subjectid ) ),
		message => $self->html_phrase( $messageid, %inserts ) );
}



my $PUBLIC_PRIVS =
{
	"eprint_search" => 1,
};

sub allow_anybody
{
	my( $handle, $priv ) = @_;

	return 1 if( $PUBLIC_PRIVS->{$priv} );

	return 0;
}



######################################################################
# 
# $handle->DESTROY
# 
# Destructor. Don't call directly.
# 
######################################################################

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}


sub cache_subjects
{
  my( $self ) = @_;

  ( $self->{subject_cache}, $self->{subject_child_map} ) =
    EPrints::DataObj::Subject::get_all( $self );
    $self->{subjects_cached} = 1;
}

######################################################################
=pod

=back

=cut

######################################################################



1;


