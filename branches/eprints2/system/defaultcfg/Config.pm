######################################################################
#
#  Site Information
#
#   Constants and information about the local EPrints repository
#   *PATHS SHOULD NOT END WITH SLASHES, LEAVE THEM OUT*
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
#
######################################################################

package EPrints::Config::devel;

foreach my $file ( 
	"cfg/OAI.pm",
	"cfg/Render.pm",
	"cfg/Validate.pm",
	"cfg/Indexing.pm",
	"cfg/Fields.pm" )
{
	unless (my $return = do $file) {
		warn "couldn't parse $file: $@" if $@;
		warn "couldn't do $file: $!"    unless defined $return;
		warn "couldn't run $file"       unless $return;
	}
}

use Unicode::String qw(utf8 latin1 utf16);

use strict;

use EPrints;

sub get_conf
{
	my( $repository_info ) = @_;
	my $c = {};

######################################################################
#
#  General repository information
#
######################################################################

# First we import information that was configured in
# the XML file. It can be over-ridden, but that's 
# probably not a good idea.
foreach( keys %{$repository_info} ) { 
	$c->{$_} = $repository_info->{$_} 
};

# If 1, users can request the removal of their submissions from the repository
$c->{allow_user_removal_request} = 1;

######################################################################
#
# Local Paths 
#
#  These probably don't need changing.
#
######################################################################

# Where the full texts (document files) are stored:
$c->{documents_path} = $c->{archiveroot}."/documents";

# The location of the configuration files (and where some
# automatic files will be written to)
$c->{config_path} = $c->{archiveroot}."/cfg";

# The location where eprints will build the website
$c->{htdocs_path} = $c->{archiveroot}."/html";

# The directory which will be secured for web access to 
# protect non-public documents.
$c->{htdocs_secure_path} = $c->{htdocs_path}."/secure";

######################################################################
#
# URLS
#
#  These probably don't need changing.
#
######################################################################

# Server of static HTML + images, including port
$c->{base_url} = "http://$c->{host}";
if( $c->{port} != 80 )
{
	# Not SSL port 443 friendly
	$c->{base_url}.= ":".$c->{port};
}
$c->{base_url} .= $c->{urlpath}; 

# Site "home page" address
$c->{frontpage} = "$c->{base_url}/";

# URL of secure document file hierarchy. EPrints needs to know the
# path from the baseurl as this is used by the authentication module
# to extract the document number from the url, eg.
# http://www.lemurprints.org/secure/00000120/01/index.html
$c->{secure_url_dir} = "/secure"; 
$c->{secure_url} = $c->{base_url}.$c->{secure_url_dir};

# Mod_perl script base URL
$c->{perl_url} = $c->{base_url}."/perl";

# The user area home page URL
$c->{userhome} = "$c->{perl_url}/users/home";

# Use shorter URLs for records. 
# Ie. use /23/ instead of /archive/00000023/
$c->{use_short_urls} = 1;

# By default all paths are rewritten to the relevant language directory
# except for /perl/. List other exceptions here.
# These will be used in a regular expression, so characters like
# .()[]? have special meaning.
$c->{rewrite_exceptions} = [ '/cgi/' ];

######################################################################
#
#  Document file upload information
#
######################################################################

# AT LEAST one of the following formats will be required. If you do
# not want this requirement, then make the list empty (Although this
# means users will be able to submit eprints with ZERO documents.
#
# Available formats are configured elsewhere. See the docs.

$c->{required_formats} = 
[
	"html",
	"pdf",
	"ps",
	"ascii"
];

# if you want to make this depend on the values in the eprint then
# you can make it a function pointer instead. The function should
# return a list as above.

# This example requires all normal formats for all eprints except
# for those of type book where a document is optional.
#
# $c->{required_formats} = sub {
# 	my( $session, $eprint ) = @_;
# 
# 	if( $eprint->get_value( 'type' ) eq "book" )
# 	{
# 		return [];
# 	}
# 	return ['html','pdf','ps','ascii'];
# };

# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$c->{diskspace_error_threshold} = 64*1024;

# If ever the amount of free space drops below this threshold, the
# repository administrator is sent a warning email. In kilobytes.
$c->{diskspace_warn_threshold} = 512*1024;

######################################################################
#
# Complexity Customisation
#
#  Things you might not want to bother the users with, or might 
#  consider really useful.
#
######################################################################

# If you are setting up a very simple system or 
# are starting with lots of data entry you can
# make user submissions bypass the editorial buffer
# by setting this option:
$c->{skip_buffer} = 0;

######################################################################
#
# Web Sign-up customisation
#
######################################################################

# Allow users to sign up for an account on
# the web.
# NOTE: If you disable this you should edit the template file 
#   cfg/template-en.xml
# and the error page 
#   cfg/static/en/error401.xpage 
# to remove the links to web registration.
$c->{allow_web_signup} = 1;

# Set this to "minimal" to allow minimal user accounts -
# users can set up subscriptions but not deposit
$c->{signup_style} = "full";

# Allow users to change their password via the web?
# You may wish to disable this if you import passwords from an
# external system or use LDAP.
$c->{allow_reset_password} = 1;

# The type of user that gets created when someone signs up
# over the web. This can be modified after they sign up by
# staff with the right priv. set. 
$c->{default_user_type} = "user";
#$c->{default_user_type} = "minuser";


# This is a list of fields which the user is asked for when registering
# in addition to the required username, email and password.
$c->{user_registration_fields} = [ "name" ];

# See also the user type configuration section.

######################################################################
#
#  Field Property Defaults
#
######################################################################

# This lets you set the default values for 
# certain cosmetic properties of metadata fields
# rather than set them individually. Settings on
# a metafield will override these values.

# Number of rows of a textarea input or max number of elements before
# a scrollbar appears in sets, subjects and datatype fields. A value
# of ALL will show all the settings in a set, subject or datatype.
$c->{field_defaults}->{input_rows} = 10;

# Number of columns (characters) of a textarea input or text
# input field.
$c->{field_defaults}->{input_cols} = 60;

# Default size of the "name" input field parts.
$c->{field_defaults}->{input_name_cols} = {
	honourific=>8,
	given=>20,
	family=>20,
	lineage=>8 
};

# Default number of cols in an ID input field.
$c->{field_defaults}->{input_id_cols} = 40;

# Default number of boxes to add when clicking the "more spaces"
# button on a multiple field.
$c->{field_defaults}->{input_add_boxes} = 2;

# Default number of boxes to show on a multiple field.
$c->{field_defaults}->{input_boxes} = 3;

# Max digits in an integer.
$c->{field_defaults}->{digits} = 20;

# Width of a search field
$c->{field_defaults}->{search_cols} = 40;

# Maximum rows to display in a subject or set search
$c->{field_defaults}->{search_rows} = 12;

# You may hide the "lineage" and "honourific"
# fields in the "name" type field input, if you
# feel that they will confuse your users. This
# makes no difference to the actual database,
# the fields will just be unused.
$c->{field_defaults}->{hide_honourific} = 0;
$c->{field_defaults}->{hide_lineage} = 1;

# By default names are asked for as given,family
# if you want to swap this to family,given then
# set this flag to 1
$c->{field_defaults}->{family_first} = 0;

######################################################################
#
#  Submission Form Customisation
#
######################################################################

# These items let you skip the various stages
# of the submission form if they are not relevant.

# If you skip "type" then your eprint-defaults
# sub (far below in this file) should set a 
# default type.
$c->{submission_stage_skip}->{type} = 0;

# You can skip "linking" with no ill effects.
$c->{submission_stage_skip}->{linking} = 1;

# If you skip the main metadata input you must
# set all the required fields in the default.
$c->{submission_stage_skip}->{meta} = 0;

# If you really must skip the file upload then
# you must make it valid to submit no files.
$c->{submission_stage_skip}->{files} = 0;

# The following options deal with the information 
# the user is asked for when submitting a document
# associated with a record. 

# Hide the format option, if you do this you must
# set a default.
$c->{submission_hide_format} = 0;

# Hide the optional format description field, no
# big whup if you do this.
$c->{submission_hide_formatdesc} = 0;

# Hide the language field. This field does not do
# anything useful anyway, but it might provide 
# useful data in a multilingual repository.
$c->{submission_hide_language} = 0;

# Hide the security field, you might want to do
# this if you don't plan to have any secret or
# confidential contents.
$c->{submission_hide_security} = 0;

# The document license field, you might want this
# if you want to allow users to specify a
# per-document license
$c->{submission_hide_license} = 0;

# These options allow you to suppress various file
# upload methods. You almost certainly do not want
# to supress "plain" but you may well wish to supress
# URL capture. Especially if wget is broken for some 
# reason. They must not ALL be supressed.
$c->{submission_hide_upload_archive} = 0;
$c->{submission_hide_upload_graburl} = 0;
$c->{submission_hide_upload_plain} = 0;

# If you want the long form of the eprint type selection
# page set this to 1. A value of 0 will generate a simple
# pick-list.
$c->{submission_long_types} = 1;

# By default even editors can't modfiy deleted records. To
# allow them to, set this flag.
$c->{allow_edit_deleted} = 0;

######################################################################
#
# Language
#
######################################################################

# Setting this to zero will simplify the
# interface to the system if you want to 
# operate in a single language. 
$c->{multi_language_options} = 0;

$c->{lang_cookie_domain} = $c->{host};
$c->{lang_cookie_name} = "lang";

######################################################################
#
# Experimental VLit support.
#
#  VLit support will allow character ranges to be served as well as 
#  whole documents. 
#
######################################################################

# set this to 0 to disable vlit (and run generate_apacheconf)
$c->{vlit}->{enable} = 1;

# The URL which the (C) points to.
$c->{vlit}->{copyright_url} = $c->{base_url}."/vlit.html";


######################################################################
#
# Userhome Extra Bits
#
#  Allows you to add additional links to the user home page.
#
######################################################################

#$c->{userhome_extras} =
#[
#        {
#                location=>"review",
#                code=>"footle2",
#                page=>"/perl/users/status",
#                priv=>"view-status"
#        },
#];


######################################################################
#
# Internal log handling
#
#  Enables a hook into Apache to catch logging events and
#  record them directly into the eprints database for usage analysis
#
######################################################################

# set this to 1 to enable log handling
# (then run generate_apacheconf and restart apache)
$c->{loghandler}->{enable} = 1;


######################################################################
#
#  Search and subscription information
#
#   Before the repository goes public, ensure that these are correct and work OK.
#
#   To specify a search field that will search >1 metadata field, enter
#   all of the fields to be searched separated by slashes "/" as a single
#   entry. e.g.  "title/abstract/keywords".
#
#   When specifying ordering, separate the fields with a "/", and specify
#   proceed the fieldname with a dash "-" for reverse sorting.
#
#   To search or sort on the id part of a field eg. "creators" append
#   ".id" to it's name. eg. "creators.id"
#
######################################################################

# Browse views. allow_null indicates that no value set is 
# a valid result. 
# Multiple fields may be specified for one view, but avoid
# subject or allowing null in this case.
$c->{browse_views} = [
        { id=>"year", allow_null=>1, fields=>"-date_effective;res=year", subheadings=>"type", order=>"-date_effective/title", heading_level=>2 },
        { id=>"subjects", fields=>"subjects", order=>"-date_effective/title", hideempty=>1 }
];
# examples of some other useful views you might want to add
#
# Browse by the ID's of creators & editors (CV Pages)
# { id=>"people", allow_null=>0, fields=>"creators.id/editors.id", order=>"title/creators", noindex=>1, nolink=>1, nohtml=>1, include=>1, citation=>"title_only", nocount=>1 }
#
# Browse by the names of creators (less reliable than Id's)
#{ id=>"people", allow_null=>0, fields=>"creators/editors", order=>"title/creators",  include=>1 }
#
# Browse by the type of eprint (poster, report etc).
#{ id=>"type",  fields=>"type", order=>"-date_effective" }




# Default number of results to display on a single search results page
# can be over-ridden per search config.
$c->{results_page_size} = 100;

$c->{search}->{simple} = 
{
	search_fields => [
		{
			id => "meta",
			meta_fields => [
				"title",
				"abstract",
				"creators",
				"date_effective" 
			]
		},
		{
			id => "full",
			meta_fields => [
				$EPrints::Utils::FULLTEXT,
				"title",
				"abstract",
				"creators",
				"date_effective" 
			]
		},
		{
			id => "person",
			meta_fields => [
				"creators",
				"editors"
			]
		},
		{	
			id => "date",
			meta_fields => [
				"date_effective"
			]
		}
	],
	preamble_phrase => "cgi/search:preamble",
	title_phrase => "cgi/search:simple_search",
	citation => "neat",
	default_order => "byyear",
	page_size => 100,
	controls => { top=>0, bottom=>1 }
};
		

$c->{search}->{advanced} = 
{
	search_fields => [
		{ meta_fields => [ $EPrints::Utils::FULLTEXT ] },
		{ meta_fields => [ "title" ] },
		{ meta_fields => [ "creators" ] },
		{ meta_fields => [ "abstract" ] },
		{ meta_fields => [ "keywords" ] },
		{ meta_fields => [ "subjects" ] },
		{ meta_fields => [ "type" ] },
		{ meta_fields => [ "department" ] },
		{ meta_fields => [ "editors" ] },
		{ meta_fields => [ "ispublished" ] },
		{ meta_fields => [ "refereed" ] },
		{ meta_fields => [ "publication" ] },
		{ meta_fields => [ "date_effective" ] }
	],
	preamble_phrase => "cgi/advsearch:preamble",
	title_phrase => "cgi/advsearch:adv_search",
	citation => "neat",
	default_order => "byyear",
	page_size => 100,
	controls => { top=>1, bottom=>1 }
};

$c->{order_methods}->{subject} =
{
	"byname" 	 =>  "name",
	"byrevname"	 =>  "-name" 
};

# Fields used for specifying a subscription
$c->{subscription_fields} =
[
	"subjects",
	"refereed",
	"ispublished"
];

# Fields used for limiting the scope of editors
$c->{editor_limit_fields} =
[
	"subjects",
	"type"
];

# Ways of ordering search results
$c->{order_methods}->{eprint} =
{
	"byyear" 	 => "-date_effective/creators/title",
	"byyearoldest"	 => "date_effective/creators/title",
	"byname"  	 => "creators/-date_effective/title",
	"bytitle" 	 => "title/creators/-date_effective"
};

$c->{order_methods}->{"eprint.review"} =
{
	"bystatuschanged"	=> "status_changed",
	"bystatuschangedoldest"	=> "-status_changed",
	"bytitle"		=> "title",
	"bytitlerev"		=> "-title",
};



# Fields for a staff user search.
$c->{user_search_fields} =
[
	"name",
	"username",
	"userid",
	"dept/org",
	"address/country",
	"usertype",
	"email"
];

# Ways of ordering user search results
$c->{order_methods}->{user} =
{
	"byname" 	 =>  "name/joined",
	"byjoin"	 =>  "joined/name",
	"byrevjoin"  	 =>  "-joined/name",
	"bytype" 	 =>  "usertype/name"
};

# If set to true, this option causes name searches to match the
# starts of surnames. eg. if true then "smi" will match the name
# "Smith".
$c->{match_start_of_name} = 0;

# The default way of ordering a search result
#   (must be key to %eprint_order_methods)
$c->{default_order}->{user} = "byname";

# customise the citation used to give results on the latest page
# nb. This is the "last 7 days" page not the "latest_tool" page.
$c->{latest_citation} = "neat";


######################################################################
#
# Latest_tool Configuration
#
#  the latest_tool script is used to output the last "n" items 
#  accepted into the repository
#
######################################################################

$c->{latest_tool_modes} = {
	default => { citation => "neat" }
};

# Example of a latest_tool mode. This makes a mode=articles option
# which only lists eprints who's type equals "article".
#	
#	articles => {
#		citation => undef,
#		filters => [
#			{ meta_fields => [ "type" ], value => "article" }
#		],
#		max => 20
#	}



######################################################################
#
# User Types
#
#  Set the user types and what metadata they require in
#  metadata-types.xml
#
#  Here you can configure how different types of user are 
#  authenticated and which parts of the system they are allowed
#  to use.
#
######################################################################

# If true then use cookie based authentication.
# Don't use basic login unless you are coming from EPrints 2.
$c->{cookie_auth} = 1;

# Please the the documentation for a full explanation of user privs.
$c->{userauth} = {
#	minuser => { 
#		priv  =>  [ "subscription", "set-password", "change-email", "change-user", "no_edit_own_record", "lock-username-to-email" ] },
	user => { 
		priv  =>  [ "subscription", "set-password", "deposit", "change-email", "change-user" ] },
	editor => { 
		priv  =>  [ "subscription", "set-password", "deposit", "change-email", "change-user",
				"view-status", "editor", "staff-view" ] },
	admin => { 
		priv  =>  [ "subscription", "set-password", "deposit", "change-email", "change-user",
				"view-status", "editor", "staff-view", 
				"edit-subject", "edit-user" ] }
};

$c->{disable_userinfo} = 0;

######################################################################
#
# Timeouts
#
######################################################################

# Time (in hours) to allow a email/password change "pin" to be active.
# Set a time of zero ("0") to make pins never time out.
$c->{pin_timeout} = 24*7; # a week

# Search cache.
#
#   Number of minutes of unuse to timeout a search cache
$c->{cache_timeout} = 10;

#   Maximum lifespan of a cache, in use or not. In hours.
#   ( This will be the length of time an OAI resumptionToken is 
#   valid for ).
$c->{cache_maxlife} = 12;


######################################################################
#
# Dynamic Template
#
# If you use a dynamic template then this function is called every
# time a page is served to generate dynamic parts of it.
# 
# The dynamic template feature may be disabled to reduce server load.
#
# When enabling/disabling it, run 
# generate_apacheconf
# generate_static
# generate_views
# generate_abstracts
#
######################################################################

$c->{dynamic_template}->{enable} = 1;

# This method is called every time ANY html page in the system is
# requested so don't do anything that's very intensive.
# The best way to do things like that are to do them once every five
# miuntes and cache them to a file.

$c->{dynamic_template}->{function} = sub {
	my( $session, $parts ) = @_;

	my $user = $session->current_user;
	if( defined $user )
	{
		$parts->{login_status} = $session->html_phrase( "dynamic:logged_in", 
			user => $user->render_description );
	}
	else
	{
		$parts->{login_status} = $session->html_phrase( "dynamic:not_logged_in" );
	}
};

######################################################################
#
# Advanced Options
#
# Don't mess with these unless you really know what you are doing.
#
######################################################################

# Example page hooks to mess around with the metadata
# submission page.

# my $doc = EPrints::XML::make_document();
# my $link = $doc->createElement( "link" );
# $link->setAttribute( "rel", "copyright" );
# $link->setAttribute( "href", "http://totl.net/" );
# $c->{pagehooks}->{submission_meta}->{head} = $link;
# $c->{pagehooks}->{submission_meta}->{bodyattr}->{bgcolor} = '#ff0000';


# 404 override. This is handy if you want to catch some urls from an
# old system, or want to make some kind of weird dynamic urls work.
# It should be handled before it becomes a 404, but hey.
# If the function returns a string then the browser is redirected to
# that url. If it returns undef then then the normal error page is shown.
# $c->{catch404} = sub {
#	my( $session, $url ) = @_;
#	
#	if( $url =~ m#/subject-(\d+).html$# )
#	{
#		return "/views/subjects/$1.html";
#	}
#	
#	return undef;
# };

# If you use the Latex render function and want to use the mimetex
# package rather than the latex->dvi->ps->png route then enable this
# option and put the location of the executable "mimetex.cgi" into 
# SystemSettings.pm
$c->{use_mimetex} = 0;

# If you want to override the way eprints sends email, you can
# set the send_email config option to be a function to use 
# instead.
#
# The function will have to take the following paramaters.
# $repository, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname
# repository   string   utf8   utf8      utf8      DOM    DOM   string    utf8
#

# $c->{send_email} = \&EPrints::Utils::send_mail_via_sendmail;
# $c->{send_email} = \&some_function;

# Uses the smtp_server specified in SystemSettings
$c->{send_email} = \&EPrints::Utils::send_mail_via_smtp;

# If you want to import legacy data which is excempt from the normal
# validation methods, then uncomment this function and make it return
# true for eprints which are not to be validated.
# $c->{skip_validation} = sub { 
#	my( $eprint ) = @_;
#
#	return 0;
#};

# Log timings on submissions. 
# This feature creates a log file in the eprints var directory
# which logs timestamps of users doing the submission process. It's
# useful for us to monitor time taken on various pages in the submission
# process and maybe you want to to...
# $c->{log_submission_timing} = 1; 

######################################################################

# Stuff from other config files which are require'd above:
$c->{oai} = get_oai_conf( $c->{perl_url} );
$c->{archivefields} = get_metadata_conf();

return $c;
}




######################################################################
#
# log( $repository, $message )
#
######################################################################
# $repository 
# - repository object
# $message 
# - log message string
#
# returns: nothing 
#
######################################################################
# This method is called to log something important. By default it 
# sends everything to STDERR which means it ends up in the apache
# error log ( or just stderr for the command line scripts in bin/ )
# If you want to write to a file instead, or add extra information 
# such as the name of the repository, this is the place to do it.
#
######################################################################

sub log
{
	my( $repository, $message ) = @_;

	print STDERR $message."\n";

	# You may wish to use this line instead if you have many repositories, but if you
	# only have on then it's just more noise.
	#print STDERR "[".$repository->get_id()."] ".$message."\n";
}


######################################################################
#
# %entities = get_entities( $repository , $langid );
#
######################################################################
# $repository 
# - the repository object
# $langid 
# - the 2 digit language ID string
#
# returns %entities 
# - a HASH which maps 
#      entity name string
#   to 
#      entity value string
#
######################################################################
# get_entities is used by eprints to get the entities
# for the phrase files and config files. 
#
# When EPrints loads the repository config, it is called once for each
# supported language, although that probably only affects the repository
# name.
#
# It should not need editing, unless you want to add entities to the
# DTD file. You might want to do that to help automate a large system.
#
######################################################################

sub get_entities
{
	my( $repository, $langid ) = @_;

	my %entities = ();
	$entities{archivename} = $repository->get_conf( "archivename", $langid );
	$entities{adminemail} = $repository->get_conf( "adminemail" );
	$entities{base_url} = $repository->get_conf( "base_url" );
	$entities{perl_url} = $repository->get_conf( "perl_url" );
	$entities{https_base_url} = "https://" . $repository->get_conf("securehost") . $repository->get_conf("securepath");
	$entities{frontpage} = $repository->get_conf( "frontpage" );
	$entities{userhome} = $repository->get_conf( "userhome" );
	$entities{version} = EPrints::Config::get( "version" );
	$entities{ruler} = EPrints::XML::to_string( $repository->get_ruler() );

	return %entities;
}

# return one of:
# REQ 
# REQ_AND_USER [default]
# REQ_OR_USER
# for just USER security use REQ_AND_USER and make the REQ check always
# succeed.
# use REQ for request (location) based security, so it doesn't then
# ask for a username/password after passing the first part.
sub document_security_rule
{
	my( $security ) = @_;

	# these are example settings for domain based security
	# return( "REQ_AND_USER" ) if( $security eq "campus_and_validuser" );
	# return( "REQ_OR_USER" ) if( $security eq "campus_or_validuser" );
	# return( "REQ" ) if( $security eq "campus" );

	return( "REQ_AND_USER" );
}

# this method handles checking to see if a basic request is allowed to
# view a secured document. Usually this means checking the IP address 
# but other aspects of the request could also be used.
sub can_request_view_document
{
	my( $doc, $r ) = @_;

	#my $eprint = $doc->get_eprint();
	my $security = $doc->get_value( "security" );

	return( 1 ) if( $security eq "" );

	# This _should_ work according to the mod_perl2 documentation,
	# but does not seem to. 
	#my $c = $r->connection();
	#my $remote_ip = $c->remote_ip();
	#my $remote_host = $c->remote_host();

	my $ip = $ENV{REMOTE_ADDR};

	# some examples of possible settings 

	# my( $oncampus ) = 0;
	# $oncampus = 1 if( $ip eq "152.78.69.157" );
	#
	# return( 1 ) if( $security eq "campus_and_validuser" && $oncampus );
	# return( 1 ) if( $security eq "campus_or_validuser" && $oncampus );
	# return( 1 ) if( $security eq "campus" && $oncampus );

	# return true if we are in a security model which does not care
	# about request-authentication.
	return( 1 ) if( $security eq "validuser" );
	return( 1 ) if( $security eq "staffonly" );


	$doc->get_session->get_repository->log( 
"unrecognized request security flag '$security' on document ".$doc->get_id );
	# return 0 if we don't recognise the security flag.
	return( 0 );
}

sub can_user_view_document
{
	my( $doc, $user ) = @_;

	my $eprint = $doc->get_eprint();
	my $security = $doc->get_value( "security" );

	# If the document belongs to an eprint which is in the
	# inbox or the editorial buffer then we treat the security
	# as staff only, whatever it's actual setting.
	if( $eprint->get_dataset()->id() ne "archive" )
	{
		$security = "staffonly";
	}

	# Add/remove types of security in metadata-types.xml

	# Trivial cases:
	return( 1 ) if( $security eq "" );
	return( 1 ) if( $security eq "validuser" );

	# examples for location validation
	# return( 1 ) if( $security eq "validuser_and_campus" );
	# return( 1 ) if( $security eq "validuser_or_campus" );
	# if the mode is "campus" then this method will never be called 
	# as we set the rule to "REQ" (above).
	
	if( $security eq "staffonly" )
	{
		# If you want to finer tune this, you could create
		# new privs and use them.

		# people with priv editor can read this document...
		if( $user->has_priv( "editor" ) )
		{
			return 1;
		}

		# ...as can the user who deposited it...
		if( $user->get_value( "userid" ) == $eprint->get_value( "userid" ) )
		{
			return 1;
		}

		# ...but nobody else can
		return 0;
		
	}

	$doc->get_session->get_repository->log( 
"unrecognized user security flag '$security' on document ".$doc->get_id );
	# Unknown security type, be paranoid and deny permission.
	return( 0 );
}



######################################################################
#
# session_init( $session, $offline )
#
#  Invoked each time a new session is needed (generally one per
#  script invocation.) $session is a session object that can be used
#  to store any values you want. To prevent future clashes, prefix
#  all of the keys you put in the hash with repository.
#
#  If $offline is non-zero, the session is an `off-line' session, i.e.
#  it has been run as a shell script and not by the web server.
#
######################################################################

sub session_init
{
	my( $session, $offline ) = @_;
}


######################################################################
#
# session_close( $session )
#
#  Invoked at the close of each session. Here you should clean up
#  anything you did in session_init().
#
######################################################################

sub session_close
{
	my( $session ) = @_;
}

######################################################################
#
# email_for_doc_request( $session, $eprint )
#
#  Invoked to determine the contact email address for an eprint. Used
#  by the "request documents" feature
#
######################################################################


sub email_for_doc_request {
	my ( $session, $eprint ) = @_;
	# To turn off this feature, uncomment the line below
	#return undef;
	if ($eprint->is_set("contact_email")) {
		return $eprint->get_value("contact_email");
	}
	my $user = $eprint->get_user;
	if( defined $user && $user->is_set("email")) {
		return $user->get_value("email");
	}
	return $session->get_repository->get_conf("adminemail");
}

# Return true to indicate the module loaded OK.
1;
