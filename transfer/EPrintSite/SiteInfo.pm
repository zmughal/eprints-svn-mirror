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

# Short text description
$EPrintSite::SiteInfo::description = "";

# E-mail address for human-read administration mail
$EPrintSite::SiteInfo::admin = "admin\@lemur.ecs.soton.ac.uk";

# Host the machine is running on

my $host = `hostname`;
chomp $host;
$EPrintSite::SiteInfo::host = $host; # hack cus of CVS.

# Stem for local ID codes
$EPrintSite::SiteInfo::eprint_id_stem = "zook";

# If 1, users can request the removal of their submissions from the archive
$EPrintSite::SiteInfo::allow_user_removal_request = 1;

# Mod_perl script server, including port
$EPrintSite::SiteInfo::server_perl = "http://$EPrintSite::SiteInfo::host/perl";


######################################################################
#
#  Site information that shouldn't need changing
#
######################################################################


# Local path of perl scriptsA
$EPrintSite::SiteInfo::local_perl_root = "$EPrintSite::base_path/cgi";


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
# This means that the word Fête is indexed as 'fete' and
# "fete" or "fête" will match it.
# There's no reason mappings have to be a single character.

%EPrintSite::SiteInfo::freetext_char_mapping = (
"¡"=>"!",	"¢"=>"c",	"£"=>"L",	"¤"=>"o",	
"¥"=>"Y",	"¦"=>"|",	"§"=>"S",	"¨"=>"\"",	
"©"=>"(c)",	"ª"=>"a",	"«"=>"<<",	"¬"=>"-",	
"­"=>"-",	"®"=>"(R)",	"¯"=>"-",	"°"=>"o",	
"±"=>"+-",	"²"=>"2",	"³"=>"3",	"´"=>"'",	
"µ"=>"u",	"¶"=>"q",	"·"=>".",	"¸"=>",",	
"¹"=>"1",	"º"=>"o",	"»"=>">>",	"¼"=>"1/4",	
"½"=>"1/2",	"¾"=>"3/4",	"¿"=>"?",	"À"=>"A",	
"Á"=>"A",	"Â"=>"A",	"Ã"=>"A",	"Ä"=>"A",	
"Å"=>"A",	"Æ"=>"AE",	"Ç"=>"C",	"È"=>"E",	
"É"=>"E",	"Ê"=>"E",	"Ë"=>"E",	"Ì"=>"I",	
"Í"=>"I",	"Î"=>"I",	"Ï"=>"I",	"Ð"=>"D",	
"Ñ"=>"N",	"Ò"=>"O",	"Ó"=>"O",	"Ô"=>"O",	
"Õ"=>"O",	"Ö"=>"O",	"×"=>"x",	"Ø"=>"O",	
"Ù"=>"U",	"Ú"=>"U",	"Û"=>"U",	"Ü"=>"U",	
"Ý"=>"Y",	"Þ"=>"b",	"ß"=>"B",	"à"=>"a",	
"á"=>"a",	"â"=>"a",	"ã"=>"a",	"ä"=>"a",	
"å"=>"a",	"æ"=>"ae",	"ç"=>"c",	"è"=>"e",	
"é"=>"e",	"ê"=>"e",	"ë"=>"e",	"ì"=>"i",	
"í"=>"i",	"î"=>"i",	"ï"=>"i",	"ð"=>"d",	
"ñ"=>"n",	"ò"=>"o",	"ó"=>"o",	"ô"=>"o",	
"õ"=>"o",	"ö"=>"o",	"÷"=>"/",	"ø"=>"o",	
"ù"=>"u",	"ú"=>"u",	"û"=>"u",	"ü"=>"u",	
"ý"=>"y",	"þ"=>"B",	"ÿ"=>"y" );

$EPrintSite::SiteInfo::freetext_mapped_chars = 
	join( "", keys %EPrintSite::SiteInfo::freetext_char_mapping );


1 # For use/require success


