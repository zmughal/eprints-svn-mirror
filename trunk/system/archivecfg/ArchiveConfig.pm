######################################################################
#
#  Site Information
#
#   Constants and information about the local EPrints archive
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

package EPrints::Config::lemurprints;

#cjg NO UNICODE IN PASSWORDS!!!!!!!!!
# remove additional + suggestion fields from eprint static and add
# them to the normal roster.

use EPrints::Utils;
use EPrints::DOM;
use Unicode::String qw(utf8 latin1 utf16);
use EPrints::OpenArchives;

use strict;

## Config to add: MAX browse items, MAX search results to display sorted
## Fields to make browseable.
my $CJGDEBUG = 0;

## WP1: BAD
sub get_conf
{
	my( $archiveinfo ) = @_;
	my $c = {};

	# First we import information that was configured in
	# the XML file. It can be over-ridden, but that's 
	# probably not a good idea.
	foreach( keys %{$archiveinfo} ) { 
		$c->{$_} = $archiveinfo->{$_} 
	};

######################################################################
#
#  General archive information
#
######################################################################

# If 1, users can request the removal of their submissions from the archive
$c->{allow_user_removal_request} = 1;

# Time (in hours) to allow a email/password change "pin" to be active.
# Set a time of zero ("0") to make pins never time out.
$c->{pin_timeout} = 3;

# Cache timeout:
# Number of minutes of unuse to timeout a search cache
$c->{cache_timeout} = 10;
# Maximum lifespan of a cache, in use or not. In hours.
$c->{cache_maxlife} = 12;

######################################################################
#
#  Site information that shouldn't need changing
#
######################################################################


######################################################################
# paths

$c->{config_path} = $c->{archiveroot}."/cfg";
$c->{system_files_path} = $c->{archiveroot}."/cfg";
$c->{static_html_root} = $c->{archiveroot}."/cfg/static";
$c->{local_html_root} = $c->{archiveroot}."/html";
$c->{local_document_root} = $c->{archiveroot}."/documents";
$c->{local_secure_root} = $c->{local_html_root}."/secure";

######################################################################
# URLS

# Server of static HTML + images, including port
$c->{server_static} = "http://$c->{host}";
if( $c->{port} != 80 )
{
	# cjg: Not SSL port 443 friendly
	$c->{server_static}.= ":".$c->{port}; 
}

# Site "home page" address
$c->{frontpage} = "$c->{server_static}/";

# Corresponding URL of document file hierarchy
$c->{server_document_path} = "/archive";
$c->{server_document_root} = $c->{server_static}.$c->{server_document_path};

# URL of secure document file hierarchy
$c->{server_secure_path} = "/secure"; 
$c->{server_secure_root} = $c->{server_static}.$c->{server_secure_path};

# Mod_perl script server, including port
$c->{server_perl_path} = "/perl";
$c->{server_perl_root} = $c->{server_static}.$c->{server_perl_path};

######################################################################
#
#  Document file upload information
#
######################################################################


# AT LEAST one of the following formats will be required. Include
# $EPrints::Document::OTHER as well as those in your list if you want to
# allow any format. Leave this list empty if you don't want to require that
# full text is deposited.
$c->{required_formats} =
[
	"html",
	"pdf",
	"ps",
	"ascii"
];

# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$c->{diskspace_error_threshold} = 20480;

# If ever the amount of free space drops below this threshold, the
# archive administrator is sent a warning email. In kilobytes.
$c->{diskspace_warn_threshold} = 512000;


### Where put this info, cjg?
# Command lines to execute to extract files from each type of archive.
# Note that archive extraction programs should not ever do any prompting,
# and should be SILENT whatever the error.  _DIR_ will be replaced with the 
# destination dir, and _ARC_ with the full pathname of the .zip. (Each
# occurence will be replaced if more than one of each.) Make NO assumptions
# about which dir the command will be run in. Exit code is assumed to be zero
# if everything went OK, non-zero in the case of any error.

### Where put this info, cjg?
#  Command to run to grab URLs. Should:
#  - Produce no output
#  - only follow relative links to same or subdirectory
#  - chop of the number of top directories _CUTDIRS_, so a load of pointlessly
#    deep directories aren't created
#  - start grabbing at _URL_
#


######################################################################
#
#  Open Archives interoperability
#
######################################################################

# Site specific **UNIQUE** archive identifier.
# See http://www.openarchives.org/sfc/sfc_archives.htm for existing identifiers.

$c->{oai_archive_id} = "GenericEPrints";

# Exported metadata formats. The hash should map format ids to namespaces.
$c->{oai_metadata_formats} =
{
	"oai_dc"    =>  "http://purl.org/dc/elements/1.1/"
};

# Exported metadata formats. The hash should map format ids to schemas.
$c->{oai_metadata_schemas} =
{
	"oai_dc"    =>  "http://www.openarchives.org/OAI/1.1/dc.xsd"
};

# Base URL of OAI
$c->{oai_base_url} = $c->{server_perl_root}."/oai";

$c->{oai_sample_identifier} = EPrints::OpenArchives::to_oai_identifier(
	$c->{oai_archive_id},
	"23" );

# Information for "Identify" responses.

# "content" : Text and/or a URL linking to text describing the content
# of the repository.  It would be appropriate to indicate the language(s)
# of the metadata/data in the repository.

$c->{oai_content}->{"text"} = latin1( <<END );
OAI Site description has not been configured.
END
$c->{oai_content}->{"url"} = undef;

# "metadataPolicy" : Text and/or a URL linking to text describing policies
# relating to the use of metadata harvested through the OAI interface.

# oai_metadataPolicy{"text"} and/or oai_metadataPolicy{"url"} 
# MUST be defined to comply to OAI.

$c->{oai_metadata_policy}->{"text"} = latin1( <<END );
No metadata policy defined. 
This server has not yet been fully configured.
Please contact the admin for more information, but if in doubt assume that
NO rights at all are granted to this data.
END
$c->{oai_metadata_policy}->{"url"} = undef;

# "dataPolicy" : Text and/or a URL linking to text describing policies
# relating to the data held in the repository.  This may also describe
# policies regarding downloading data (full-content).

# oai_dataPolicy{"text"} and/or oai_dataPolicy{"url"} 
# MUST be defined to comply to OAI.

$c->{oai_data_policy}->{"text"} = latin1( <<END );
No data policy defined. 
This server has not yet been fully configured.
Please contact the admin for more information, but if in doubt assume that
NO rights at all are granted to this data.
END
$c->{oai_data_policy}->{"url"} = undef;

# "submissionPolicy" : Text and/or a URL linking to text describing
# policies relating to the submission of content to the repository (or
# other accession mechanisms).

$c->{oai_submission_policy}->{"text"} = latin1( <<END );
No submission-data policy defined. 
This server has not yet been fully configured.
END
$c->{oai_submission_policy}->{"url"} = undef;

# "comment" : Text and/or a URL linking to text describing anything else
# that is not covered by the fields above. It would be appropriate to
# include additional contact details (additional to the adminEmail that
# is part of the response to the Identify request).

# An array of comments to be returned. May be empty.

$c->{oai_comments} = [
	latin1( "System is EPrints ").
	EPrints::Config::get( "version_desc" ).
	" (http://www.eprints.org)" ];

###########################################
# Complexity Customisation
#
# aka. things you might not want to bother
# the users with, or might consider really 
# useful.
###########################################

# You may hide the "lineage" and "honourific"
# fields in the "name" type field input, if you
# feel that they will confuse your users. This
# makes no difference to the actual database,
# the fields will just be unused.
$c->{hide_honourific} = 0;
$c->{hide_lineage} = 0;

###########################################
# Web Sign-up customisation
###########################################

# Allow users to sign up for an account on
# the web. If you disable this you should
# edit the template file and the error page
# to not offer this option.
$c->{allow_web_signup} = 1;

# To prevent users from changing their email
# and/or passwords via the web, see the 
# user permissions section elsewhere in this
# file.

###########################################
#  Submission Form Customisation
###########################################

# These items let you skip the various stages
# of the submission form if they are not relevant.

# If you skip "type" then your eprint-defaults
# sub (far below in this file) should set a 
# default type.
$c->{submission_stage_skip}->{type} = 0;

# You can skip "linking" with no ill effects.
$c->{submission_stage_skip}->{linking} = 0;

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
# useful data in a multilingual archive.
$c->{submission_hide_language} = 1;

# Hide the security field, you might want to do
# this if you don't plan to have any secret or
# confidential contents.
$c->{submission_hide_security} = 0;

###########################################
#  Language
###########################################

# Setting this to zero will simplify the
# interface to the system if you want to 
# operate in a single language. 
# It will disable the following:
# -cjg Stuff...
$c->{multi_language_options} = 1;

$c->{lang_cookie_domain} = $c->{host};
$c->{lang_cookie_name} = "lang";

###########################################
#  User Types
###########################################

# We need to calculate the connection string, so we can pass it
# into the AuthDBI config. 
my $connect_string = EPrints::Database::build_connection_string(
	dbname  =>  $c->{dbname}, 
	dbport  =>  $c->{dbport},
	dbsock  =>  $c->{dbsock}, 
	dbhost  =>  $c->{dbhost}  );

my $userdata = EPrints::DataSet->new_stub( "user" );

my $UNENCRYPTED_DBI = {
	handler  =>  \&Apache::AuthDBI::authen,
	Auth_DBI_data_source  =>  $connect_string,
	Auth_DBI_username  =>  $c->{dbuser},
	Auth_DBI_password  =>  $c->{dbpass},
	Auth_DBI_pwd_table  =>  $userdata->get_sql_table_name(),
	Auth_DBI_uid_field  =>  "username",
	Auth_DBI_pwd_field  =>  "password",
	Auth_DBI_grp_field  =>  "usertype",
	Auth_DBI_encrypted  =>  "off" };

my $ENCRYPTED_DBI = {
	handler  =>  \&Apache::AuthDBI::authen,
	Auth_DBI_data_source  =>  $connect_string,
	Auth_DBI_username  =>  $c->{dbuser},
	Auth_DBI_password  =>  $c->{dbpass},
	Auth_DBI_pwd_table  =>  $userdata->get_sql_table_name(),
	Auth_DBI_uid_field  =>  "username",
	Auth_DBI_pwd_field  =>  "password",
	Auth_DBI_grp_field  =>  "usertype",
	Auth_DBI_encrypted  =>  "on" };

# The type of user that gets created when someone signs up
# over the web. This can be modified after they sign up by
# staff with the right priv. set. 
#
# If you change this, you should probably change the user
# automatic field generator (lower down this file) too.
$c->{default_user_type} = "user";

#cjg = no default user type = no web signup???

#subscription
#set-password
#deposit
#view-status
#editor
#staff-view -> view & search users & eprints in staff mode.
#edit-subject
#edit-user
#change-email

 
$c->{userauth} = {
	user => { 
		auth  => $ENCRYPTED_DBI,
		priv  =>  [ "subscription", "set-password", "deposit", "change-email" ] },
	editor => { 
		auth  => $ENCRYPTED_DBI,
		priv  =>  [ "subscription", "set-password", "deposit", "change-email",
				"view-status", "editor", "staff-view" ] },
	admin => { 
		auth  => $ENCRYPTED_DBI,
		priv  =>  [ "subscription", "set-password", "deposit", "change-email",
				"view-status", "editor", "staff-view", 
				"edit-subject", "edit-user" ] }
};


######################################################################
# METADATA CONFIGURATION
######################################################################
# The archive specific fields for users and eprints.
######################################################################

$c->{archivefields}->{document} = [
	{ name => "citeinfo", type => "longtext", multiple => 1 }
];

$c->{archivefields}->{user} = [

	{ name => "name", type => "name" },

	{ name => "dept", type => "text" },

	{ name => "org", type => "text" },

	{ name => "address", type => "longtext", displaylines => 5 },

	{ name => "country", type => "text" },

	{ name => "url", type => "url" }

];

if( $CJGDEBUG ) {
	push @{$c->{archivefields}->{user}},{ name => "ecsid", type=>"int" };
}

$c->{archivefields}->{eprint} = [
	{ name => "abstract", displaylines => 10, type => "longtext" },

	{ name => "altloc", type => "url", multiple => 1 },

	{ name => "authors", type => "name", multiple => 1, hasid => 1 },

	{ name => "chapter", type => "text", maxlength => 5 },

	{ name => "comments", type => "longtext", displaylines => 3 },

	{ name => "commref", type => "text" },

	{ name => "confdates", type => "text" },

	{ name => "conference", type => "text" },

	{ name => "confloc", type => "text" },

	{ name => "department", type => "text" },

	{ name => "editors", type => "name", multiple => 1, hasid=>1 },

	{ name => "institution", type => "text" },

	{ name => "ispublished", type => "set", 
			options => [ "unpub","inpress","pub" ] },

	{ name => "keywords", type => "longtext", displaylines => 2 },

	{ name => "month", type => "set",
		options => [ "jan","feb","mar","apr","may","jun",
			"jul","aug","sep","oct","nov","dec" ] },

	{ name => "number", type => "text", maxlength => 6 },

	{ name => "pages", type => "pagerange" },

	{ name => "pubdom", type => "boolean" },

	{ name => "publication", type => "text" },

	{ name => "publisher", type => "text" },

	{ name => "refereed", type => "boolean" },

	{ name => "referencetext", type => "longtext", displaylines => 3 },

	{ name => "reportno", type => "text" },

	{ name => "series", type => "text" },

	{ name => "subjects", type=>"subject", top=>"subjects", multiple => 1 },

	{ name => "thesistype", type => "text" },

	{ name => "title", type => "text" },

	{ name => "volume", type => "text", maxlength => 6 },

	{ name => "year", type => "year" },

	{ name => "suggestions", type => "longtext" }
];
	

######################################################################
#
#  Search and subscription information
#
#   Before the archive goes live, ensure that these are correct and work OK.
#
#   To specify a search field that will search >1 metadata field, enter
#   all of the fields to be searched separated by slashes "/" as a single
#   entry. e.g.  "title/abstract/keywords".
#
#   When specifying ordering, separate the fields with a comma, and specify
#   ASC for ascending order, or DESC for descending. Ascending order is
#   the default.  e.g. "year DESC, authors ASC, title"
#
######################################################################

$c->{browse_fields} = 
[ 
	"year", 
	"subjects" 
];


# Fields for a simple user search
$c->{simple_search_fields} =
[
	"title/abstract/keywords",
	"authors/editors",
	#"abstract/keywords",
	#"authors.id",
	#"publication",
	"year"
];

# Fields for an advanced user search
$c->{advanced_search_fields} =
[
	"title",
	"authors",
	"abstract",
	"keywords",
	"subjects",
	"type",
	"conference",
	"department",
	"editors",
	"ispublished",
	"refereed",
	"publication",
	"year"
];

# Fields used for specifying a subscription
$c->{subscription_fields} =
[
	"subjects",
	"refereed",
	"ispublished"
];

#cjg normalise so byname=>by_name becomes by_name=>by_name

# Ways of ordering search results
$c->{order_methods}->{eprint} =
{
	"test"		=> "authors.id/-year",
	"byyear" 	 => "-year/authors/title",
	"byyearoldest"	 => "year/authors/title",
	"byname"  	 => "authors/-year/title",
	"bytitle" 	 => "title/authors/-year"
};


# The default way of ordering a search result
#   (must be key to %eprint_order_methods)
$c->{default_order}->{eprint} = "byname";

# How to order the articles in a "browse by subject" view.
#cjg HMMMM.
$c->{view_order} = \&eprint_cmp_by_author;

# Fields for a staff user search.
$c->{user_search_fields} =
[
	"name",
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

# The default way of ordering a search result
#   (must be key to %eprint_order_methods)
$c->{default_order}->{user} = "byname";


#####
##### This is the point from which chaos reigns
##### but it will be made better. Later...
#####


# How to display articles in "version of" and "commentary" threads.
#  See lib/Citation.pm for information on how to specify this.
$c->{thread_citation_specs} =
{
	"succeeds"    =>  "{title} (deposited {datestamp})",
	"commentary"  =>  "{authors}. {title}. (deposited {datestamp})"
};

	return $c;
}

######################################################################
#
#  Free Text search configuration
#
######################################################################

# These values control what words do and don't make it into
# the free text search index. They are used by the extract_words
# method in the cjg SiteRoutines file which you can edit directly for
# finer control.

# Minimum size word to normally index.
my $FREETEXT_MIN_WORD_SIZE = 3;

# We use a hash rather than an array for good and bad
# words as we only use these to lookup if words are in
# them or not. If we used arrays and we had lots of words
# it might slow things down.

#cjg STOP WORDS APPEAR TO BE BUGGY.

# Words to never index, despite their length.
my $FREETEXT_STOP_WORDS = {
	"this"=>1,	"are"=>1,	"which"=>1,	"with"=>1,
	"that"=>1,	"can"=>1,	"from"=>1,	"these"=>1,
	"those"=>1,	"the"=>1,	"you"=>1,	"for"=>1,
	"been"=>1,	"have"=>1,	"were"=>1,	"what"=>1,
	"where"=>1,	"is"=>1,	"and"=>1 
};

# Words to always index, despite their length.
my $FREETEXT_ALWAYS_WORDS = {
		"ok" => 1 
};

# This map is used to convert ASCII characters over
# 127 to characters below 127, in the word index.
# This means that the word F�te is indexed as 'fete' and
# "fete" or "f�te" will match it.
# There's no reason mappings have to be a single character.

my $FREETEXT_CHAR_MAPPING = {
	latin1("�") => "!",	latin1("�") => "c",	
	latin1("�") => "L",	latin1("�") => "o",	
	latin1("�") => "Y",	latin1("�") => "|",	
	latin1("�") => "S",	latin1("�") => "\"",	
	latin1("�") => "(c)",	latin1("�") => "a",	
	latin1("�") => "<<",	latin1("�") => "-",	
	latin1("�") => "-",	latin1("�") => "(R)",	
	latin1("�") => "-",	latin1("�") => "o",	
	latin1("�") => "+-",	latin1("�") => "2",	
	latin1("�") => "3",	latin1("�") => "'",	
	latin1("�") => "u",	latin1("�") => "q",	
	latin1("�") => ".",	latin1("�") => ",",	
	latin1("�") => "1",	latin1("�") => "o",	
	latin1("�") => ">>",	latin1("�") => "1/4",	
	latin1("�") => "1/2",	latin1("�") => "3/4",	
	latin1("�") => "?",	latin1("�") => "A",	
	latin1("�") => "A",	latin1("�") => "A",	
	latin1("�") => "A",	latin1("�") => "A",	
	latin1("�") => "A",	latin1("�") => "AE",	
	latin1("�") => "C",	latin1("�") => "E",	
	latin1("�") => "E",	latin1("�") => "E",	
	latin1("�") => "E",	latin1("�") => "I",	
	latin1("�") => "I",	latin1("�") => "I",	
	latin1("�") => "I",	latin1("�") => "D",	
	latin1("�") => "N",	latin1("�") => "O",	
	latin1("�") => "O",	latin1("�") => "O",	
	latin1("�") => "O",	latin1("�") => "O",	
	latin1("�") => "x",	latin1("�") => "O",	
	latin1("�") => "U",	latin1("�") => "U",	
	latin1("�") => "U",	latin1("�") => "U",	
	latin1("�") => "Y",	latin1("�") => "b",	
	latin1("�") => "B",	latin1("�") => "a",	
	latin1("�") => "a",	latin1("�") => "a",	
	latin1("�") => "a",	latin1("�") => "a",	
	latin1("�") => "a",	latin1("�") => "ae",	
	latin1("�") => "c",	latin1("�") => "e",	
	latin1("�") => "e",	latin1("�") => "e",	
	latin1("�") => "e",	latin1("�") => "i",	
	latin1("�") => "i",	latin1("�") => "i",	
	latin1("�") => "i",	latin1("�") => "d",	
	latin1("�") => "n",	latin1("�") => "o",	
	latin1("�") => "o",	latin1("�") => "o",	
	latin1("�") => "o",	latin1("�") => "o",	
	latin1("�") => "/",	latin1("�") => "o",	
	latin1("�") => "u",	latin1("�") => "u",	
	latin1("�") => "u",	latin1("�") => "u",	
	latin1("�") => "y",	latin1("�") => "B",	
	latin1("�") => "y",	latin1("'") => "" };


# Chars which seperate words. Pretty much anything except
# A-Z a-z 0-9 and single quote '

# If you want to add other seperator characters then they
# should be encoded in utf8. The Unicode::String man page
# details some useful methods.

my $FREETEXT_SEPERATOR_CHARS = {
	'@' => 1, 	'[' => 1,
	'\\' => 1, 	']' => 1,
	'^' => 1, 	'_' => 1,
	' ' => 1, 	'`' => 1,
	'!' => 1, 	'"' => 1,
	'#' => 1, 	'$' => 1,
	'%' => 1, 	'&' => 1,
	'(' => 1, 	')' => 1,
	'*' => 1, 	'+' => 1,
	',' => 1, 	'-' => 1,
	'.' => 1, 	'/' => 1,
	':' => 1, 	';' => 1,
	'{' => 1, 	'<' => 1,
	'|' => 1, 	'=' => 1,
	'}' => 1, 	'>' => 1,
	'~' => 1, 	'?' => 1
};

######################################################################
#
# extract_words( $text )
#
#  This method is used when indexing a record, to decide what words
#  should be used as index words.
#  It is also used to decide which words to use when performing a
#  search. 
#
#  It returns references to 2 arrays, one of "good" words which should
#  be used, and one of "bad" words which should not.
#
######################################################################

sub extract_words
{
	my( $text ) = @_;

	# Acronym processing only works on uppercase non accented
	# latin letters. If you don't want this processing comment
	# out the next few lines.

	# Normalise acronyms eg.
	# The F.B.I. is like M.I.5.
	# becomes
	# The FBI  is like MI5
	my $a;
	$text =~ s#[A-Z0-9]\.([A-Z0-9]\.)+#$a=$&;$a=~s/\.//g;$a#ge;
	# Remove hyphens from acronyms
	$text=~ s#[A-Z]-[A-Z](-[A-Z])*#$a=$&;$a=~s/-//g;$a#ge;

	# Process string. 
	# First we apply the char_mappings.
	my( $i, $len ),
	my $utext = utf8( "$text" ); # just in case it wasn't already.
	$len = $utext->length;
	my $buffer = utf8( "" );
	for($i = 0; $i<$len; ++$i )
	{
		my $s = $utext->substr( $i, 1 );
		# $s is now char number $i
		if( defined $FREETEXT_CHAR_MAPPING->{$s} )
		{
			$s = $FREETEXT_CHAR_MAPPING->{$s};
		} 
		$buffer.=$s;
	}

	$len = $buffer->length;
	my @words = ();
	my $cword = utf8( "" );
	for($i = 0; $i<$len; ++$i )
	{
		my $s = $buffer->substr( $i, 1 );
		# $s is now char number $i
		if( defined $FREETEXT_SEPERATOR_CHARS->{$s} )
		{
			push @words, $cword; # even if it's empty	
			$cword = utf8( "" );
		}
		else
		{
			$cword .= $s;
		}
	}
	push @words,$cword;
	
	# Iterate over every word (bits divided by seperator chars)
	# We use hashes rather than arrays at this point to make
	# sure we only get each word once, not once for each occurance.
	my %good = ();
	my %bad = ();
	my $word;
	foreach $word ( @words )
	{	
		# skip if this is nothing but whitespace;
		next if ($word =~ /^\s*$/);

		# calculate the length of this word
		my $wordlen = length $word;

		# $ok indicates if we should index this word or not

		# First approximation is if this word is over or equal
		# to the minimum size set in SiteInfo.
		my $ok = $wordlen >= $FREETEXT_MIN_WORD_SIZE;
	
		# If this word is at least 2 chars long and all capitals
		# it is assumed to be an acronym and thus should be indexed.
		if( $word =~ m/^[A-Z][A-Z0-9]+$/ )
		{
			$ok=1;
		}

		# Consult list of "never words". Words which should never
		# be indexed.	
		if( $FREETEXT_STOP_WORDS->{lc $word} )
		{
			$ok = 0;
		}
		# Consult list of "always words". Words which should always
		# be indexed.	
		if( $FREETEXT_ALWAYS_WORDS->{lc $word} )
		{
			$ok = 1;
		}
	
		# Add this word to the good list or the bad list
		# as appropriate.	
		if( $ok )
		{
			# Only "bad" words are used in display to the
			# user. Good words can be normalised even further.

			# non-acronyms (ie not all UPPERCASE words) have
			# a trailing 's' removed. Thus in searches the
			# word "chair" will match "chairs" and vice-versa.
			# This isn't perfect "mose" will match "moses" and
			# "nappy" still won't match "nappies" but it's a
			# reasonable attempt.
			$word =~ s/s$//;

			# If any of the characters are lowercase then lower
			# case the entire word so "Mesh" becomes "mesh" but
			# "HTTP" remains "HTTP".
			if( $word =~ m/[a-z]/ )
			{
				$word = lc $word;
			}
	
			$good{$word}++;
		}
		else 
		{
			$bad{$word}++;
		}
	}
	# convert hash keys to arrays and return references
	# to these arrays.
	my( @g ) = keys %good;
	my( @b ) = keys %bad;
	return( \@g , \@b );
}


sub render_value_with_id
{
	my( $field, $session, $value, $alllangs, $rendered ) = @_;

	# You might want to wrap the rendered value in an anchor, 
	# eg if the ID is a staff username
	# you may wish to link to their homepage. 

#cjg Link Baton?

# Simple Example:
#
#	if( $field->get_name() eq "SOMENAME" ) 
#	{	
#		my $fragment = $session->make_doc_fragment();
#		$fragment->appendChild( $rendered );
#		$fragment->appendChild( 
#			$session->make_text( " (".$value->{id}.")" ) );
#		return( $fragment );
#	}

	return( $rendered );
}

sub can_user_view_document
{
	my( $doc, $user ) = @_;

	my $eprint = $doc->get_eprint();
	my $security = $doc->get_value( "security" );

	# If the document belongs to an eprint which is in the
	# inbox or the submissionbuffer then we treat the security
	# as staff only, whatever it's actual setting.
	if( $eprint->get_dataset()->id() ne "archive" )
	{
		$security = "staffonly";
	}

	# Add/remove types of security in metadata-types.xml

	# Trivial cases:
	return( 1 ) if( $security eq "public" );
	return( 1 ) if( $security eq "validuser" );
	
	if( $security eq "staffonly" )
	{
		# If you want to finer tune this, you could create
		# a new priv. and use that.
		return $user->has_priv( "editor" );
	}

	# Unknown security type, be paranoid and deny permission.
	return( 0 );
}

######################################################################
#
# $title = eprint_render_short_title( $eprint )
#
#  Return a single line concise title for an EPrint, for rendering
#  lists
#
######################################################################

## WP1: BAD
sub eprint_render_short_title
{
	my( $eprint ) = @_;
	
	if( !defined $eprint->get_value( "title" ) )
	{
		#cjg LANGIT!
		return $eprint->get_session()->make_text( 
			"Untitled ".$eprint->get_value( "eprintid" ) );
	}

	return( $eprint->render_value( "title" ) );
}


######################################################################
#
# $title = eprint_render_full( $eprint, $show_all )
#
#  Return HTML for rendering an EPrint. If $show_all is non-zero,
#  extra information appropriate for only staff may be shown.
#
######################################################################

## WP1: BAD
sub eprint_render
{
	my( $eprint, $session, $show_all ) = @_;

	my $succeeds_field = $session->get_archive()->get_dataset( "eprint" )->get_field( "succeeds" );
	my $commentary_field = $session->get_archive()->get_dataset( "eprint" )->get_field( "commentary" );
	my $has_multiple_versions = $eprint->in_thread( $succeeds_field );

	my( $page, $p, $a );

	$page = $session->make_doc_fragment;

	# Citation
	$p = $session->make_element( "p" );
	$p->appendChild( $eprint->render_citation() );
	$page->appendChild( $p );

	# Put in a message describing how this document has other versions
	# in the archive if appropriate
	if( $has_multiple_versions )
	{
		my $latest = $eprint->last_in_thread( $succeeds_field );
#
		if( $latest->get_value( "eprintid" ) == $eprint->get_value( "eprintid" ) )
		{
			$page->appendChild( $session->html_phrase( 
						"page:latest_version" ) );
		}
		else
		{
			$page->appendChild( $session->html_phrase( 
				"page:not_latest_version",
				link => $session->make_element(
					"a",
					href => $latest->static_page_url() 
								) ) );
		}
	}		

	# Available documents
	my @documents = $eprint->get_all_documents();

	$p = $session->make_element( "p" );
	$p->appendChild( $session->html_phrase( "page:fulltext" ) );
	foreach( @documents )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $_->render_link() );
	}
	$page->appendChild( $p );


	# Then the abstract
	if( defined $eprint->get_value( "abstract" ) )
	{
		my $h2 = $session->make_element( "h2" );
		$h2->appendChild( 
			$session->html_phrase( "eprint_fieldname_abstract" ) );
	
		$p = $session->make_element( "p" );
		$p->appendChild( $eprint->render_value( "abstract", $show_all ) );
		$page->appendChild( $p );
	}
	
	my( $table, $tr, $td, $th );	# this table needs more class cjg
	$table = $session->make_element( "table",
					border=>"0",
					cellpadding=>"3" );
	$page->appendChild( $table );

	# Commentary
	if( defined $eprint->get_value( "commentary" ) )
	{
		my $target = EPrints::EPrint->new( $session,
			$session->get_archive()->get_dataset( "archive" ), 
			$eprint->get_value( "commentary" ) );
		if( defined $target )
		{
			$table->appendChild( _render_row(
				$session,
				$session->html_phrase( 
					"eprint_fieldname_commentary" ),
				$target->render_citation_link() ) );
		}
	}

	# Keywords
	if( defined $eprint->get_value( "keywords" ) )
	{
		$table->appendChild( _render_row(
			$session,
			$session->html_phrase( "eprint_fieldname_keywords" ),
			$eprint->render_value( "keywords", $show_all ) ) );
	}

	# Subjects...
	$table->appendChild( _render_row(
		$session,
		$session->html_phrase( "eprint_fieldname_subjects" ),
		$eprint->render_value( "subjects", $show_all ) ) );

	$table->appendChild( _render_row(
		$session,
		$session->html_phrase( "page:id_code" ),
		$eprint->render_value( "eprintid", $show_all ) ) );

	my $user = new EPrints::User( 
			$eprint->{session},
 			$eprint->get_value( "userid" ) );
	my $usersname;
	if( defined $user )
	{
		$usersname = $session->make_element( "a", 
				href=>$eprint->{session}->get_archive()->get_conf( "server_perl_root" )."/user?userid=".$user->get_value( "userid" ) );
		$usersname->appendChild( 
			$session->make_text( $user->full_name() ) );
	}
	else
	{
		$usersname = $session->html_phrase( "page:invalid_user" );
	}

	$table->appendChild( _render_row(
		$session,
		$session->html_phrase( "page:deposited_by" ),
		$usersname ) );

	$table->appendChild( _render_row(
		$session,
		$session->html_phrase( "page:deposited_on" ),
		$eprint->render_value( "datestamp", $show_all ) ) );

	# Alternative locations
	if( defined $eprint->get_value( "altloc" ) )
	{
		$table->appendChild( _render_row(
			$session,
			$session->html_phrase( "eprint_fieldname_altloc" ),
			$eprint->render_value( "altloc", $show_all ) ) );
	}

	# Now show the version and commentary response threads
	if( $has_multiple_versions )
	{
		$page->appendChild( 
			$session->html_phrase( "page:available_versions" ) );
		#$html .= $eprint->{session}->{render}->write_version_thread(
			#$eprint,
			#$succeeds_field );
	}
	
	if( $eprint->in_thread( $commentary_field ) )
	{
		$page->appendChild( 
			$session->html_phrase( "page:commentary_threads" ) );
		#$html .= $eprint->{session}->{render}->write_version_thread(
			#$eprint,
			#$commentary_field );
	}

	# If being viewed by a staff member, we want to show any suggestions for
	# additional subject categories
	if( $show_all )
	{
		# Show all the other fields
		$page->appendChild( $session->render_ruler() );
		$table = $session->make_element( "table",
					border=>"0",
					cellpadding=>"3" );
		$page->appendChild( $table );
		my $field;
		foreach $field ( $eprint->get_dataset()->get_type_fields(
			  $eprint->get_value( "type" ) ) )
		{
			print STDERR "ST:".$field->get_name()."\n";
			$table->appendChild( _render_row(
				$session,
				$session->make_text( 
					$field->display_name( $session ) ),	
				$eprint->render_value( 
					$field->get_name(), 
					$show_all ) ) );

		}
	}
			

	my $title = eprint_render_short_title( $eprint );

	return( $page, EPrints::Utils::tree_to_utf8( $title ) );
}


sub _render_row
{
	my( $session, $key, $value ) = @_;

	my( $tr, $th, $td );

	$tr = $session->make_element( "tr" );

	$th = $session->make_element( "th" ); 
	$th->appendChild( $key );
	$th->appendChild( $session->make_text( ":" ) );
	$tr->appendChild( $th );

	$td = $session->make_element( "td" ); 
	$td->appendChild( $value );
	$tr->appendChild( $td );

	return $tr;
}



######################################################################
#
# $name = user_display_name( $user )
#
#  Return the user's name in a form appropriate for display.
#
######################################################################

## WP1: BAD
sub user_display_name
{
	my( $user ) = @_;

	# If no surname, just return the username
	my $name = $user->get_value( "name" );

	if( !defined $name || !EPrints::Utils::is_set( $name->{family} ) )
	{
		#langify cjg
		return( "User ".$user->get_value( "username" ) );
	} 

	return( EPrints::Utils::format_name( $user->get_session(), $name, 1 ) );
}


#
# $DOM = user_render( $user, $session, $show_all )
#

sub user_render
{
	my( $user, $session, $show_all ) = @_;

	my $html;	

	my( $info, $p, $a );
	$info = $session->make_doc_fragment;

	if( !$show_all )
	{
		# Render the public information about this user.
		$p = $session->make_element( "p" );
		$p->appendChild( $session->make_text( $user->full_name() ) );
		# Address, Starting with dept. and organisation...
		if( defined $user->get_value( "dept" ) )
		{
			$p->appendChild( $session->make_element( "br" ) );
			$p->appendChild( $user->render_value( "dept" ) );
		}
		if( defined $user->get_value( "org" ) )
		{
			$p->appendChild( $session->make_element( "br" ) );
			$p->appendChild( $user->render_value( "org" ) );
		}
		if( defined $user->get_value( "address" ) )
		{
			$p->appendChild( $session->make_element( "br" ) );
			$p->appendChild( $user->render_value( "address" ) );
		}
		if( defined $user->get_value( "country" ) )
		{
			$p->appendChild( $session->make_element( "br" ) );
			$p->appendChild( $user->render_value( "country" ) );
		}
		$info->appendChild( $p );
		
	
		## E-mail and URL last, if available.
		if( defined $user->get_value( "email" ) )
		{
			$p = $session->make_element( "p" );
			$p->appendChild( $user->render_value( "email" ) );
			$info->appendChild( $p );
		}
		if( defined $user->get_value( "url" ) )
		{
			$p = $session->make_element( "p" );
			$p->appendChild( $user->render_value( "url" ) );
			$info->appendChild( $p );
		}
		
	}
	else
	{
		# Show all the fields
		my( $table );
		$table = $session->make_element( "table",
					border=>"0",
					cellpadding=>"3" );

		my @fields = $user->get_dataset()->get_fields( $user->get_value( "usertype" ) );
		my $field;
		foreach $field ( @fields )
		{
			my $name = $field->get_name();
			# Skip fields which are only used by eprints internals
			# and would just confuse the issue to print
			next if( $name eq "newemail" );
			next if( $name eq "newpassword" );
			next if( $name eq "pin" );
			next if( $name eq "pinsettime" );
			$table->appendChild( _render_row(
				$session,
				$session->make_text( 
					$field->display_name( $session ) ),	
				$user->render_value( 
					$field->get_name(), 
					$show_all ) ) );

		}
		$info->appendChild( $table );
			
	}	

	return( $info );
}


######################################################################
#
# session_init( $session, $offline )
#
#  Invoked each time a new session is needed (generally one per
#  script invocation.) $session is a session object that can be used
#  to store any values you want. To prevent future clashes, prefix
#  all of the keys you put in the hash with archive.
#
#  If $offline is non-zero, the session is an `off-line' session, i.e.
#  it has been run as a shell script and not by the web server.
#
######################################################################

## WP1: BAD
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

## WP1: BAD
sub session_close
{
	my( $session ) = @_;
}


######################################################################
#
# update_submitted_eprint( $eprint )
#
#  This function is called on an EPrint whenever it is transferred
#  from the inbox (the author's workspace) to the submission buffer.
#  You can alter the EPrint here if you need to, or maybe send a
#  notification mail to the administrator or something. 
#
#  Any changes you make to the EPrint object will be written to the
#  database after this function finishes, so you don't need to do a
#  commit().
#
######################################################################

## WP1: BAD
sub update_submitted_eprint
{
	my( $eprint ) = @_;
}


######################################################################
#
# update_archived_eprint( $eprint )
#
#  This function is called on an EPrint whenever it is transferred
#  from the submission buffer to the real archive (i.e. when it is
#  actually "archived".)
#
#  You can alter the EPrint here if you need to, or maybe send a
#  notification mail to the author or administrator or something. 
#
#  Any changes you make to the EPrint object will be written to the
#  database after this function finishes, so you don't need to do a
#  commit().
#
######################################################################

## WP1: BAD
sub update_archived_eprint
{
	my( $eprint ) = @_;
}


######################################################################
#
#  OPEN ARCHIVES INTEROPERABILITY ROUTINES
#
######################################################################


######################################################################
#
# @formats = oai_list_metadata_formats( $eprint )
#
#  This should return the metadata formats we can export for the given
#  eprint. If $eprint is undefined, just return all the metadata
#  formats supported by the archive.
#
#  The returned values must be keys to
#  the config element: oai_metadata_formats.
#
######################################################################

## WP1: BAD
sub oai_list_metadata_formats
{
	my( $eprint ) = @_;
	
	# This returns the list of all metadata formats, suitable if we
	# can export any of those metadata format for any record.
	return( keys %{$eprint->{session}->get_archive()->get_conf( "oai_metadata_formats" )} );
}


######################################################################
#
# %metadata = oai_get_eprint_metadata( $eprint, $format )
#
#  Return metadata for the given eprint in the given format.
#  The value of each key should be either a scalar value (string)
#  indicating the value for that string, e.g:
#
#   "title"  =>  "Full Title of the Paper"
#
#  or it can be a reference to a list of scalars, indicating multiple
#  values:
#
#   "author"  =>  [ "J. R. Hartley", "J. N. Smith" ]
#
#  it can also be nested:
#
#   "nested"  =>  [
#                  {
#                    "nested_key 1"  =>  "nested value 1",
#                    "nested_key 2"  =>  "nested value 2"
#                  },
#                  {
#                    "more nested values"
#                  }
#               ]
#
#  Return undefined if the metadata format requested is not available
#  for the given eprint.
#
######################################################################

## WP1: BAD
sub oai_get_eprint_metadata
{
	my( $eprint, $format ) = @_;

	if( $format eq "oai_dc" )
	{
		my %tags;
		
		$tags{title} = $eprint->{title};

#cjg Name don't live here anymore :-)
##		my @authors = EPrints::Name::extract( $eprint->{authors} );
my @authors;
		$tags{creator} = [];
		my $author;
		foreach $author (@authors)
		{
			my( $surname, $firstnames ) = @$author;
			push @{$tags{creator}},"$surname, $firstnames";
		}

		# Subject field will just be the subject descriptions

		#cjg SubjectList deprecated do it another way?
		#my $subject_list = new EPrints::SubjectList( $eprint->{subjects} );
		my @subjects    ;#   = $subject_list->get_subjects( $eprint->{session} );
		$tags{subject} = [];
		my $subject;
		foreach $subject (@subjects)
		{
			push @{$tags{subject}},
		   	  $eprint->{session}->{render}->render_subject_desc( $subject, 0, 1, 0 );
		   	  $eprint->{session}->{render}->render_subject_desc( $_, 0, 1, 0 );
		}

		$tags{description} = $eprint->{abstract};
		
		# Date for discovery. For a month/day we don't have, assume 01.
		my $year = $eprint->{year};
		my $month = "01";

		if( defined $eprint->{month} )
		{
			my %month_numbers = (
				unspec  =>  "01",
				jan  =>  "01",
				feb  =>  "02",
				mar  =>  "03",
				apr  =>  "04",
				may  =>  "05",
				jun  =>  "06",
				jul  =>  "07",
				aug  =>  "08",
				sep  =>  "09",
				oct  =>  "10",
				nov  =>  "11",
				dec  =>  "12" );

			$month = $month_numbers{$eprint->{month}};
		}

		$tags{date} = "$year-$month-01";
		$tags{type} = $eprint->{session}->{metainfo}->get_type_name( $eprint->{session}, "archive" , $eprint->{type} );
		$tags{identifier} = $eprint->static_page_url();

		return( %tags );
	}
	else
	{
		return( undef );
	}
}

######################################################################
#
# oai_write_eprint_metadata( $eprint, $format, $writer )
#
# This routine receives a handle to an XML::Writer it should
# write the entire XML output for the format; Everything between
# <metadata> and </metadata>.
#
# Ensure that all tags are closed in the order you open them.
#
# This routine is more low-level that oai_get_eprint_metadata
# and as such gives you more control, but is more work too.
#
# See the XML::Writer manual page for more useful information.
#
# You should use the EPrints::OpenArchives::to_utf8() function
# on your data to convert latin1 to UTF-8.
#
######################################################################


## WP1: BAD
sub oai_write_eprint_metadata
{
	my( $eprint, $format, $writer ) = @_;

	# This block of code is a minimal example
	# to get you started
	if ($format eq "not-a-real-format") {
		$writer->startTag("notaformat");
		$writer->dataElement(
			"title",
			EPrints::OpenArchives::to_utf8($eprint->{title}));
		$writer->dataElement(
			"description",
			EPrints::OpenArchives::to_utf8($eprint->{abstract}));
		$writer->endTag("notaformat");
	}
}



######################################################################
#
# VALIDATION 
#
######################################################################
# Validation routines. EPrints does some validation itself, such as
# checking for required fields, but you can add custom requirements
# here.
#
# All the validation routines should return a list of XHTML DOM 
# objects, one per problem. An empty list means no problems.
#
# $for_archive is a boolean flag (1 or 0) it is set to 0 when the
# item is being validated as a submission and to 1 when the item is
# being validated for submission to the actual archive. This allows
# a stricter validation for editors than for submitters. A useful 
# example would be that a deposit may have one of several format of
# documents but the editor must ensure that it has a PDF before it
# can be submitted into the main archive. If it doesn't have a PDF
# file, then the editor will have to generate one.
#
######################################################################

######################################################################
#
# validate_field( $field, $value, $session, $for_archive ) 
#
######################################################################
# $field 
# - MetaField object
# $value
# - metadata value (see docs)
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a particular field of metadata, currently used on users
# and eprints.
#
# This description should make sense on its own (i.e. should include 
# the name of the field.)
#
# The "required" field is checked elsewhere, no need to check that
# here.
#
######################################################################

sub validate_field
{
	my( $field, $value, $session, $for_archive ) = @_;

	# CHECKS IN HERE

	my @problems = ();

	# Ensure that a URL is valid (i.e. has the initial scheme like http:)
	if( $field->is_type( "url" ) && defined $value && $value ne "" )
	{
		if( $value !~ /^\w+:/ )
		{
			push @problems,
				$session->html_phrase( "validate:missing_http",
				fieldname=>$session->make_text( $field->display_name( $session ) ) );
		}
	}

	return( @problems );
}

######################################################################
#
# validate_eprint_meta( $eprint, $session, $for_archive ) 
#
######################################################################
# $field 
# - EPrint object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate just the metadata of an eprint. The validate_field method
# will have been called on each field first so only complex problems
# such as interdependancies need to be checked here.
#
######################################################################

sub validate_eprint_meta
{
	my( $eprint, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE
	
	#[ cjg NOT DONE
	# We check that if a journal article is published, then it 
	# has the volume number and page numbers.
	#if( $eprint->{type} eq "journalp" && $eprint->{ispublished} eq "pub" )
	#{
		#push @$problems, "You haven't specified any page numbers"
			#unless( defined $eprint->{pages} && $eprint->{pages} ne "" );
	#}
	#
	#if( ( $eprint->{type} eq "journalp" || $eprint->{type} eq "journale" )
		#&& $eprint->{ispublished} eq "pub" )
	#{	
		#push @$problems, "You haven't specified the volume number"
			#unless( defined $eprint->{volume} && $eprint->{volume} ne "" );
	#}

	return @problems;
}

######################################################################
#
# validate_eprint( $eprint, $session, $for_archive ) 
#
######################################################################
# $field 
# - EPrint object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate the whole eprint, this is the last part of a full 
# validation so you don't need to duplicate tests in 
# validate_eprint_meta, validate_field or validate_document.
#
######################################################################

sub validate_eprint
{
	my( $eprint, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	return( @problems );
}


######################################################################
#
# validate_document( $document, $session, $for_archive ) 
#
######################################################################
# $document 
# - Document object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a document.
#
######################################################################


sub validate_document
{
	my( $document, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	# "other" documents must have a description set
	if( $document->get_value( "format" ) eq "other" &&
	   !EPrints::Utils::is_set( $document->get_value( "formatdesc" ) ) )
	{
		push @problems, $session->html_phrase( 
					"validate:need_description" ,
					type=>$document->render_desc() );
	}

	return( @problems );
}

######################################################################
#
# validate_user( $user, $session, $for_archive ) 
#
######################################################################
# $user 
# - User object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a user, although all the fields will already have been
# checked with validate_field so only complex problems need to be
# tested.
#
######################################################################

sub validate_user
{
	my( $user, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	return( @problems );
}

######################################################################
# End of VALIDATION 
######################################################################



######################################################################
#
# log( $archive, $message )
#
######################################################################
# $archive 
# - archive object
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
# such as the name of the archive, this is the place to do it.
#
######################################################################

sub log
{
	my( $archive, $message ) = @_;

	print STDERR $message."\n";

	# You may wish to use this line instead if you have many archives, but if you
	# only have on then it's just more noise.
	#print STDERR "[".$archive->get_id()."] ".$message."\n";
}

######################################################################
#
# set_eprint_defaults( $data , $session )
# set_user_defaults( $data , $session )
# set_document_defaults( $data , $session )
# set_subscription_defaults( $data , $session )
#
######################################################################
# $data 
# - reference to HASH mapping 
#      fieldname string
#   to
#      metadata value structure (see docs)
# $session 
# - the session object
# $eprint 
# - (only for set_document_defaults) this is the
#   eprint to which this document will belong.
#
# returns: nothing (Modify $data instead)
#
######################################################################
# These methods allow you to set some default values when things
# are created. This is useful if you skip stages in the submission 
# form or just want to set a default.
#
######################################################################

sub set_eprint_defaults
{
	my( $data, $session ) = @_;
}

sub set_user_defaults
{
	my( $data, $session ) = @_;
}

sub set_document_defaults
{
	my( $data, $session, $eprint ) = @_;

	$data->{security} = "public";
	$data->{language} = $session->get_langid();
}

sub set_subscription_defaults
{
	my( $data, $session ) = @_;
}


######################################################################
#
# set_eprint_automatic_fields( $eprint )
# set_user_automatic_fields( $user )
# set_document_automatic_fields( $doc )
# set_subscription_automatic_fields( $subscription )
#
######################################################################
# $eprint/$user/$doc/$subscription 
# - the object to be modified
#
# returns: nothing (Modify the object instead).
#
######################################################################
# These methods are called every time commit is called on an object
# (commit writes it back into the database)
# These methods allow you to read and modify fields just before this
# happens. There are a number of uses for this. One is to encrypt 
# passwords as "secret" fields are only set if they are being changed
# otherwise they are empty. Another is to create fields which the
# submitter can't edit directly but you want to be searchable. eg.
# Number of authors.
#
######################################################################

sub set_eprint_automatic_fields
{
	my( $eprint ) = @_;
}

sub set_user_automatic_fields
{
	my( $user ) = @_;

	# Because password is a "secret" field, it is only set if it
	# is being changed - therefor if it's set we need to crypt
	# it. This could do something different like MD5 it (if you have
	# the appropriate authentication module.)
	# It could even access an external system to set the password
	# there and then set the value inside this system to undef.
	if( $user->get_value( "password" ) )
	{
		my @saltset = ('a'..'z', 'A'..'Z', '0'..'9', '.', '/');
		my $pass = $user->get_value( "password" );
		my $salt = $saltset[time % 64] . $saltset[(time/64)%64];
		my $cryptpass = crypt($pass,$salt);
		$user->set_value( "password", $cryptpass );
	}
}

sub set_document_automatic_fields
{
	my( $doc ) = @_;
}

sub set_subscription_automatic_fields
{
	my( $subscription ) = @_;
}

######################################################################
#
# %entities = get_entities( $archive , $langid );
#
######################################################################
# $archive 
# - the archive object
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
# get_entities is used by the generate_dtd script to get the entities
# for the phrase files and config files. It is called once for each
# supported language, although that probably only affects the archive
# name.
#
# It should not need editing, unless you want to add entities to the
# DTD file. You might want to do that to help automate a large system.
#
######################################################################

sub get_entities
{
	my( $archive, $langid ) = @_;

	my %entities = ();
	$entities{archivename} = $archive->get_conf( "archivename", $langid );
	$entities{adminemail} = $archive->get_conf( "adminemail" );
	$entities{cgiroot} = $archive->get_conf( "server_perl_root" );
	$entities{htmlroot} = $archive->get_conf( "server_static" );
	$entities{frontpage} = $archive->get_conf( "frontpage" );
	$entities{version} = EPrints::Config::get( "version_desc" );
	$entities{ruler} = $archive->get_ruler()->toString;

	return %entities;
}



# Return true to indicate the module loaded OK.
1;



