######################################################################
#
#  Site Information
#
#   Constants and information about the local EPrints site
#   *PATHS SHOULD NOT END WITH SLASHES, LEAVE THEM OUT*
#
######################################################################
#
# License for eprints.org software version: Build: Fri Jan 26 19:32:17 GMT 2001
# 
# Copyright (C) 2001, University of Southampton
# 
# The University of Southampton retains the copyright of this software
# code with the exception of the open archives component (in the
# openarchives/ directory), which is a modified version of code
# distributed by Cornell University Digital Library Research Group.
# 
# This software is freely distributable. Modified versions of this
# software may be distributed provided that a file README is included
# describing the modifications and from where the original version may
# be obtained.
# 
# This software is provided with no guarantees of suitability for any
# intended purpose. Use of the software is entirely at the end user's
# risk.
#
######################################################################

package EPrintSite::SiteInfo;

use EPrints::Document;
use EPrints::OpenArchives;
use EPrints::Version;
use CGI qw/:standard/;


use strict;


######################################################################
#
#  General site information
#
######################################################################

# Name for the site
$EPrintSite::SiteInfo::sitename = "Eprint Archive";

# Short text description
$EPrintSite::SiteInfo::description = "";

# E-mail address for human-read administration mail
$EPrintSite::SiteInfo::admin = "admin\@lemur.ecs.soton.ac.uk";

# Root of EPrint installation on the machine
$EPrintSite::SiteInfo::local_root = "/opt/eprints";

# Host the machine is running on
$EPrintSite::SiteInfo::host = "lemur.ecs.soton.ac.uk";

# Stem for local ID codes
$EPrintSite::SiteInfo::eprint_id_stem = "zook";

# If 1, users can request the removal of their submissions from the archive
$EPrintSite::SiteInfo::allow_user_removal_request = 1;

# Server of static HTML + images, including port
$EPrintSite::SiteInfo::server_static = "http://$EPrintSite::SiteInfo::host";

# Mod_perl script server, including port
$EPrintSite::SiteInfo::server_perl = "http://$EPrintSite::SiteInfo::host/perl";


######################################################################
#
#  Site information that shouldn't need changing
#
######################################################################

# Site "home page" address
$EPrintSite::SiteInfo::frontpage = "$EPrintSite::SiteInfo::server_static/";

# Local directory holding HTML files read by the web server
$EPrintSite::SiteInfo::local_html_root = "$EPrintSite::SiteInfo::local_root/html";

# Local directory with the content of static web pages (to be given site border)
$EPrintSite::SiteInfo::static_html_root = "$EPrintSite::SiteInfo::local_root/static";

# Local directory containing the uploaded document file hierarchy
$EPrintSite::SiteInfo::local_document_root = "$EPrintSite::SiteInfo::local_html_root/documents";

# Corresponding URL of document file hierarchy
$EPrintSite::SiteInfo::server_document_root = "$EPrintSite::SiteInfo::server_static/documents";

# Local stem for HTML files generated for "browse by subject"
$EPrintSite::SiteInfo::local_subject_view_stem = "$EPrintSite::SiteInfo::local_html_root/view-";

# Corresponding URL stem for "browse by subject" HTML files
$EPrintSite::SiteInfo::server_subject_view_stem = "$EPrintSite::SiteInfo::server_static/view-";

# Local path of perl scripts
$EPrintSite::SiteInfo::local_perl_root = "$EPrintSite::SiteInfo::local_root/cgi";


######################################################################
#
# Local users customisations
#
######################################################################

# Field to use to associate papers with authors in username and
# nameusername fields. Set to undef to use normal username.
# The named field should be of type "text".

$EPrintSite::SiteInfo::useridfield = "ecsid";

######################################################################
#
#  Site Look and Feel
#
######################################################################

# Location of the root of the subject tree
$EPrintSite::SiteInfo::server_subject_view_root = 
	$EPrintSite::SiteInfo::server_subject_view_stem."ROOT.html";

# parameters to generate the HTML header with.
# TITLE will be set by the system as appropriate.
# See the CGI.pm manpage for more info ( man CGI ).

%EPrintSite::SiteInfo::start_html_params  = (
	-BGCOLOR=>"#ffffff",
	-FGCOLOR=>"#000000",
	-HEAD=>[ Link( {-rel=>'stylesheet',
			-type=>'text/css',
			-href=>'/eprints.css',
			-title=>'screen stylesheet',
			-media=>'screen'} ) ],
	-AUTHOR=>$EPrintSite::SiteInfo::admin,
	-TOPMARGIN=>"0",
	-LEFTMARGIN=>"0",
	-MARGINWIDTH=>"0",
	-MARGINHEIGHT=>"0" );

# This is the HTML put at the top of every page. It will be put in the <BODY>,
#  so shouldn't include a <BODY> tag.
$EPrintSite::SiteInfo::html_banner = <<ENDHTML;
<table border="0" cellpadding="0" cellspacing="0">
  <tr>
    <td align="center" valign="top" bgcolor="#dddddd" fgcolor="white">
      <br>
      <a href="$EPrintSite::SiteInfo::frontpage"><img border="0" width="100" height="100" src="$EPrintSite::SiteInfo::server_static/images/logo_sidebar.gif" ALT="$EPrintSite::SiteInfo::sitename"></a>
    </td>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderr.gif"><IMG src="http://lemur.ecs.soton.ac.uk/~cjg/probity/4x4.gif" alt="" width="10" height="2"></td>
    <td>
      &nbsp;&nbsp;&nbsp;&nbsp;
    </td>
    <td>
      <BR>
      <H1>TITLE_PLACEHOLDER</H1>
    </td>
  </tr>
  <tr>
    <td bgcolor="#dddddd" align="center" valign="top">
      <table border="0" cellpadding="0" cellspacing="0">
        <tr>
          <td align=center valign=top>
            <A HREF="$EPrintSite::SiteInfo::frontpage">Home</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_static/information.html">About</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_subject_view_stem"."ROOT.html">Browse</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_perl/search">Search</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_static/register.html">Register</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_perl/users/subscribe">Subscriptions</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_perl/users/home">Deposit\&nbsp;Items</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_static/help">Help</A>
          </td>
        </tr>
      </table>
      <br>
    </td>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderr.gif"><IMG src="http://lemur.ecs.soton.ac.uk/~cjg/probity/4x4.gif" alt="" width="10" height="2"></td>
    <td>
      &nbsp;&nbsp;&nbsp;&nbsp;
    </td>
    <td valign="top" width="95%">
<BR>
ENDHTML

# This is the HTML put at the bottom of every page. Obviously, it should close
#  up any tags left open in html_banner.
$EPrintSite::SiteInfo::html_tail = <<ENDHTML;
<BR>
<HR noshade size="2">
<address>
Contact site administrator at: <a href=\"mailto:$EPrintSite::SiteInfo::admin\">$EPrintSite::SiteInfo::admin</a>
</address>
<BR><BR>
    </td>
  </tr>
  <tr>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderb.gif"><IMG src="http://lemur.ecs.soton.ac.uk/~cjg/probity/4x4.gif" alt="" width="10" height="10"></td>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderc.gif"><IMG src="http://lemur.ecs.soton.ac.uk/~cjg/probity/4x4.gif" alt="" width="10" height="15"></td>
  </tr>
</table>
ENDHTML

#  E-mail signature, appended to every email sent by the software
$EPrintSite::SiteInfo::signature =
"--
 $EPrintSite::SiteInfo::sitename
 $EPrintSite::SiteInfo::frontpage
 $EPrintSite::SiteInfo::admin\n";

#  Default text to send a user when "bouncing" a submission back to their
#  workspace. It should leave some space for staff to give a reason.
$EPrintSite::SiteInfo::default_bounce_reason =
"Unfortunately your eprint:\n\n".
"  _SUBMISSION_TITLE_\n\n".
"could not be accepted into $EPrintSite::SiteInfo::sitename as-is.\n\n\n\n".
"The eprint has been returned to your workspace. If you\n".
"visit your item depositing page you will be able to\n".
"edit your eprint, fix the problem and redeposit.\n";

#  Default text to send a user when rejecting a submission outright.
$EPrintSite::SiteInfo::default_delete_reason =
"Unfortunately your eprint:\n\n".
"  _SUBMISSION_TITLE_\n\n".
"could not be accepted into $EPrintSite::SiteInfo::sitename.\n\n\n\n".
"The eprint has been deleted.\n";

#  Agreement text, for when user completes the depositing process.
#  Set to "undef" if you don't want it to appear.
$EPrintSite::SiteInfo::deposit_agreement_text =
	"<P><EM><STRONG>For work being deposited by its own author:</STRONG> ".
	"In self-archiving this collection of files and associated bibliographic ".
	"metadata, I grant $EPrintSite::SiteInfo::sitename the right to store ".
	"them and to make them permanently available publicly for free on-line. ".
	"I declare that this material is my own intellectual property and I ".
	"understand that $EPrintSite::SiteInfo::sitename does not assume any ".
	"responsibility if there is any breach of copyright in distributing these ".
	"files or metadata. (All authors are urged to prominently assert their ".
	"copyright on the title page of their work.)</EM></P>\n".
	"<P><EM><STRONG>For work being deposited by someone other than its ".
	"author:</STRONG> I hereby declare that the collection of files and ".
	"associated bibliographic metadata that I am archiving at ".
	"$EPrintSite::SiteInfo::sitename) is in the public domain. If this is ".
	"not the case, I accept full responsibility for any breach of copyright ".
	"that distributing these files or metadata may entail.</EM></P>\n".
	"<P>Clicking on the deposit button indicates your agreement to these ".
	"terms.</P>\n";


######################################################################
#
#  Document file upload information
#
######################################################################

# Supported document storage formats, given as an array and a hash value,
#  so that some order of preference can be imposed.
@EPrintSite::SiteInfo::supported_formats =
(
	"HTML",
	"PDF",
	"PS",
	"ASCII"
);

%EPrintSite::SiteInfo::supported_format_names = 
(
	"HTML"                     => "HTML",
	"PDF"                      => "Adobe PDF",
	"PS"                       => "Postscript",
	"ASCII"                    => "Plain ASCII Text"
);

# AT LEAST one of the following formats will be required. Include
# $EPrints::Document::other as well as those in your list if you want to
# allow any format. Leave this list empty if you don't want to require that
# full text is deposited.
@EPrintSite::SiteInfo::required_formats =
(
	"HTML",
	"PDF",
	"PS",
	"ASCII"
);

#  If 1, will allow non-listed formats to be uploaded.
$EPrintSite::SiteInfo::allow_arbitrary_formats = 1;

# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$EPrintSite::SiteInfo::diskspace_error_threshold = 20480;

# If ever the amount of free space drops below this threshold, the
# archive administrator is sent a warning email. In kilobytes.
$EPrintSite::SiteInfo::diskspace_warn_threshold = 512000;

# A list of compressed/archive formats that are accepted
@EPrintSite::SiteInfo::supported_archive_formats =
(
	"ZIP",
	"TARGZ"
);


# Executables for unzip and wget
$EPrintSite::SiteInfo::unzip_executable = "/usr/bin/unzip";
$EPrintSite::SiteInfo::wget_executable = "/usr/bin/wget";

# Command lines to execute to extract files from each type of archive.
# Note that archive extraction programs should not ever do any prompting,
# and should be SILENT whatever the error.  _DIR_ will be replaced with the 
# destination dir, and _ARC_ with the full pathname of the .zip. (Each
# occurence will be replaced if more than one of each.) Make NO assumptions
# about which dir the command will be run in. Exit code is assumed to be zero
# if everything went OK, non-zero in the case of any error.
%EPrintSite::SiteInfo::archive_extraction_commands =
(
	"ZIP"   => "$EPrintSite::SiteInfo::unzip_executable 1>/dev/null 2>\&1 -qq -o -d _DIR_ _ARC_",
	"TARGZ" => "gunzip -c < _ARC_ 2>/dev/null | /bin/tar xf - -C _DIR_ >/dev/null 2>\&1"
);

# Displayable names for the compressed/archive formats.
%EPrintSite::SiteInfo::archive_names =
(
	"ZIP"   => "ZIP Archive [.zip]",
	"TARGZ" => "Compressed TAR archive [.tar.Z, .tar.gz]"
);

# The extensions to give the temporary uploaded file for each format.
%EPrintSite::SiteInfo::archive_extensions =
(
	"ZIP"   => ".zip",
	"TARGZ" => ".tar.gz"
);

#  Command to run to grab URLs. Should:
#  - Produce no output
#  - only follow relative links to same or subdirectory
#  - chop of the number of top directories _CUTDIRS_, so a load of pointlessly
#    deep directories aren't created
#  - start grabbing at _URL_
#
$EPrintSite::SiteInfo::wget_command =
	"$EPrintSite::SiteInfo::wget_executable -r -L -q -m -nH -np --execute=\"robots=off\" --cut-dirs=_CUTDIRS_ _URL_";


######################################################################
#
#  Miscellaneous
#
######################################################################

# Command for sending mail
$EPrintSite::SiteInfo::sendmail_executable = "/usr/sbin/sendmail";
$EPrintSite::SiteInfo::sendmail =
	"$EPrintSite::SiteInfo::sendmail_executable -oi -t -odb";

# Database information: Since we hold the password here unencrypted, this
# file should have suitable strict read permissions
$EPrintSite::SiteInfo::database = "eprints";
$EPrintSite::SiteInfo::db_host = undef;
$EPrintSite::SiteInfo::db_port = undef;
$EPrintSite::SiteInfo::db_socket = undef;
$EPrintSite::SiteInfo::username = "eprints";
$EPrintSite::SiteInfo::password = "fnord";


######################################################################
#
#  Open Archives interoperability
#
######################################################################

# Site specific **UNIQUE** archive identifier.
# See http://www.openarchives.org/sfc/sfc_archives.htm for existing identifiers.
$EPrintSite::SiteInfo::archive_identifier = "";


# Exported metadata formats. The hash should map format ids to namespaces.
%EPrintSite::SiteInfo::oai_metadata_formats =
(
	"oai_dc"   => "http://purl.org/dc/elements/1.1/"
);

# Exported metadata formats. The hash should map format ids to schemas.
%EPrintSite::SiteInfo::oai_metadata_schemas =
(
	"oai_dc"   => "http://www.openarchives.org/OAI/dc.xsd"
);

# Base URL of OAI
$EPrintSite::SiteInfo::oai_base_url =
	$EPrintSite::SiteInfo::server_perl."/oai";

#$EPrintSite::SiteInfo::oai_sample_identifier = EPrints::OpenArchives::to_oai_identifier(
#	$EPrintSite::SiteInfo::eprint_id_stem."00000023" );

# Information for "Identify" responses.

# "content" : Text and/or a URL linking to text describing the content
# of the repository.  It would be appropriate to indicate the language(s)
# of the metadata/data in the repository.

$EPrintSite::SiteInfo::oai_content{"text"} = 
	$EPrintSite::SiteInfo::description;
$EPrintSite::SiteInfo::oai_content{"url"} = undef;

# "metadataPolicy" : Text and/or a URL linking to text describing policies
# relating to the use of metadata harvested through the OAI interface.

# oai_metadataPolicy{"text"} and/or oai_metadataPolicy{"url"} 
# MUST be defined to comply to OAI.

$EPrintSite::SiteInfo::oai_metadataPolicy{"text"} = 
	"No metadata policy defined. ".
	"This server has not yet been fully configured.";
$EPrintSite::SiteInfo::oai_metadataPolicy{"url"} = undef;

# "dataPolicy" : Text and/or a URL linking to text describing policies
# relating to the data held in the repository.  This may also describe
# policies regarding downloading data (full-content).

# oai_dataPolicy{"text"} and/or oai_dataPolicy{"url"} 
# MUST be defined to comply to OAI.

$EPrintSite::SiteInfo::oai_dataPolicy{"text"} = 
	"No data policy defined. ".
	"This server has not yet been fully configured.";
$EPrintSite::SiteInfo::oai_dataPolicy{"url"} = undef;

# "submissionPolicy" : Text and/or a URL linking to text describing
# policies relating to the submission of content to the repository (or
# other accession mechanisms).

$EPrintSite::SiteInfo::oai_submissionPolicy{"text"} = 
	"No submission-data policy defined. ".
	"This server has not yet been fully configured.";
$EPrintSite::SiteInfo::oai_submissionPolicy{"url"} = undef;

# "comment" : Text and/or a URL linking to text describing anything else
# that is not covered by the fields above. It would be appropriate to
# include additional contact details (additional to the adminEmail that
# is part of the response to the Identify request).

# An array of comments to be returned. May be empty.

@EPrintSite::SiteInfo::oai_comments = ( "System is EPrints ".
	$EPrints::Version::eprints_software_version.
	" (http://www.eprints.org)" );



# Dienst configuration - not required but provided for 
# people who still might want the dienst interface

# Domain the software is running in
$EPrintSite::SiteInfo::domain = $EPrintSite::SiteInfo::host;
# Port the perl server is running on
$EPrintSite::SiteInfo::server_perl_port = "80";
# Standard time zone
$EPrintSite::SiteInfo::standard_time_zone = "GMT";
# Daylight savings time zone
$EPrintSite::SiteInfo::daylight_savings_time_zone = "BST";

######################################################################
#
#  Free Text search configuration
#
######################################################################

# These values control what words do and don't make it into
# the free text search index. They are used by the extract_words
# method in the SiteRoutines file which you can edit directly for
# finer control.

# Minimum size word to normally index.
$EPrintSite::SiteInfo::freetext_min_word_size = 3;

# Words to never index, despite their length.
%EPrintSite::SiteInfo::freetext_never_words = (
		"the"=>1,
		"you"=>1,
		"for"=>1,
		"and"=>1 );

# Words to always index, despite their length.
%EPrintSite::SiteInfo::freetext_always_words = (
		"ok"=>1 );

# This map is used to convert ASCII characters over
# 127 to characters below 127, in the word index.
# This means that the word F�te is indexed as 'fete' and
# "fete" or "f�te" will match it.
# There's no reason mappings have to be a single character.

%EPrintSite::SiteInfo::freetext_char_mapping = (
"�"=>"!",	"�"=>"c",	"�"=>"L",	"�"=>"o",	
"�"=>"Y",	"�"=>"|",	"�"=>"S",	"�"=>"\"",	
"�"=>"(c)",	"�"=>"a",	"�"=>"<<",	"�"=>"-",	
"�"=>"-",	"�"=>"(R)",	"�"=>"-",	"�"=>"o",	
"�"=>"+-",	"�"=>"2",	"�"=>"3",	"�"=>"'",	
"�"=>"u",	"�"=>"q",	"�"=>".",	"�"=>",",	
"�"=>"1",	"�"=>"o",	"�"=>">>",	"�"=>"1/4",	
"�"=>"1/2",	"�"=>"3/4",	"�"=>"?",	"�"=>"A",	
"�"=>"A",	"�"=>"A",	"�"=>"A",	"�"=>"A",	
"�"=>"A",	"�"=>"AE",	"�"=>"C",	"�"=>"E",	
"�"=>"E",	"�"=>"E",	"�"=>"E",	"�"=>"I",	
"�"=>"I",	"�"=>"I",	"�"=>"I",	"�"=>"D",	
"�"=>"N",	"�"=>"O",	"�"=>"O",	"�"=>"O",	
"�"=>"O",	"�"=>"O",	"�"=>"x",	"�"=>"O",	
"�"=>"U",	"�"=>"U",	"�"=>"U",	"�"=>"U",	
"�"=>"Y",	"�"=>"b",	"�"=>"B",	"�"=>"a",	
"�"=>"a",	"�"=>"a",	"�"=>"a",	"�"=>"a",	
"�"=>"a",	"�"=>"ae",	"�"=>"c",	"�"=>"e",	
"�"=>"e",	"�"=>"e",	"�"=>"e",	"�"=>"i",	
"�"=>"i",	"�"=>"i",	"�"=>"i",	"�"=>"d",	
"�"=>"n",	"�"=>"o",	"�"=>"o",	"�"=>"o",	
"�"=>"o",	"�"=>"o",	"�"=>"/",	"�"=>"o",	
"�"=>"u",	"�"=>"u",	"�"=>"u",	"�"=>"u",	
"�"=>"y",	"�"=>"B",	"�"=>"y" );

$EPrintSite::SiteInfo::freetext_mapped_chars = 
	join( "", keys %EPrintSite::SiteInfo::freetext_char_mapping );


1 # For use/require success


