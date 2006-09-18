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


use strict;

use EPrints;
use Unicode::String qw(utf8 latin1 utf16);

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

# in addition to the required username, email and password.
$c->{user_registration_fields} = [ "name" ];

# See also the user type configuration section.

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

# The type of user that gets created when someone signs up
# over the web. This can be modified after they sign up by
# staff with the right priv. set. 
$c->{default_user_type} = "user";
#$c->{default_user_type} = "minuser";

# This is a list of fields which the user is asked for when registering
# If true then use cookie based authentication.
# Don't use basic login unless you are coming from EPrints 2.
$c->{cookie_auth} = 1;

$c->{disable_userinfo} = 0;
