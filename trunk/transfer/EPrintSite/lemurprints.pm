
# Lemur Prints!

package EPrintSite::lemurprints;

use EPrintSite;
use CGI qw/:standard/;

sub new
{
	my( $class ) = @_;

	my $self = {};
	bless $self, $class;

#  Main

$self->{sitename} = "Lemur Prints Archive";

# paths

$self->{site_root} = "$EPrintSite::base_path/sites/lemurprints";

$self->{static_html_root} = "$self->{site_root}/static";
$self->{local_html_root} = "$self->{site_root}/html";
$self->{local_document_root} = "$self->{local_html_root}/documents";

# Server of static HTML + images, including port
$self->{server_static} = "http://$EPrintSite::SiteInfo::host";

# Site "home page" address
$self->{frontpage} = "$self->{server_static}/";

# Corresponding URL of document file hierarchy
$self->{server_document_root} = "$self->{server_static}/documents"; 

# Corresponding URL stem for "browse by subject" HTML files
$self->{server_subject_view_stem} = "$self->{server_static}/view-";

#  Files

$self->{template_user_intro} 	= "$self->{site_root}/cfg/template.user-intro";
$self->{subject_config} 	= "$self->{site_root}/cfg/subjects";

#  Language

# List of supported languages is in EPrintSite.pm
# Default Language for this archive
$self->{default_language} = "english";

#  Database

$self->{db_name} = "eprints";
$self->{db_host} = undef;
$self->{db_port} = undef;
$self->{db_sock} = undef;
$self->{db_user} = "eprints";
$self->{db_pass} = "fnord";

#  User Types
#

# We need to calculate the connection string, so we can pass it
# into the AuthDBI config. 
my $connect_string = EPrints::Database::build_connection_string(
	{ db_name => $self->{db_name}, db_port => $self->{db_port},
 	  db_sock => $self->{db_sock}, db_host => $self->{db_host} } );
 
$self->{userauth} = {
	User=>{ 
		routine => \&Apache::AuthDBI::authen,
		conf => {
			Auth_DBI_data_source => $connect_string,
			Auth_DBI_username => $self->{db_user},
			Auth_DBI_password => $self->{db_pass},
			Auth_DBI_pwd_table => EPrints::Database::table_name( "user" ),
			Auth_DBI_uid_field => "username",
			Auth_DBI_pwd_field => "passwd",
			Auth_DBI_grp_field => "groups",
			Auth_DBI_encrypted => "off" },
		priv => [ "user" ] },
	Staff=>{ 
		routine => \&Apache::AuthDBI::authen,
		conf => {
			Auth_DBI_data_source => $connect_string,
			Auth_DBI_username => $self->{db_user},
			Auth_DBI_password => $self->{db_pass},
			Auth_DBI_pwd_table => EPrints::Database::table_name( "user" ),
			Auth_DBI_uid_field => "username",
			Auth_DBI_pwd_field => "passwd",
			Auth_DBI_grp_field => "groups",
			Auth_DBI_encrypted => "off" }, 
		priv => [ "user" ] }
};

######################################################################
# USER FIELDS
######################################################################

$self->{sitefields}->{user} = [
	{
		name=>"name",
		type=>"name",
		required=>1,
		editable=>1,
		visible=>1
	},
	{
		name=>"dept",
		type=>"text",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"org",
		type=>"text",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"address",
		type=>"longtext",
		displaylines=>"5",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"country",
		type=>"text",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"url",
		type=>"url",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"filter",
		type=>"subject",
		required=>0,
		editable=>1,
		visible=>1,
		multiple=>1
	}
];

$self->{sitefields}->{eprint} = [
	{
		name=>"abstract",
		type=>"longtext",
		displaylines=>"10",
		editable=>1,
		visible=>1
	},
	{
		name=>"altloc",
		type=>"url",
		displaylines=>"3",
		editable=>1,
		multiple=>1,
		visible=>1
	},
	{
		name=>"authors",
		type=>"name",
		editable=>1,
		visible=>1,
		multiple=>1
	},
	{
		name=>"chapter",
		type=>"text",
		editable=>1,
		visible=>1,
		maxlength=>5
	},
	{
		name=>"comments",
		type=>"longtext",
		editable=>1,
		displaylines=>"3",
		visible=>1
	},
	{
		name=>"commref",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"confdates",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"conference",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"confloc",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"department",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"editors",
		type=>"name",
		editable=>1,
		visible=>1,
		multiple=>1
	},
	{
		name=>"institution",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"ispublished",
		type=>"set",
		editable=>1,
		visible=>1,
		options=>[ "unpub","inpress","pub" ]
	},
	{
		name=>"keywords",
		type=>"longtext",
		editable=>1,
		displaylines=>2,
		visible=>1
	},
	{
		name=>"month",
		type=>"set",
		editable=>1,
		visible=>1,
		options=>[ "unspec","jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec" ]
	},
	{
		name=>"number",
		type=>"text",
		maxlength=>"6",
		editable=>1,
		visible=>1
	},
	{
		name=>"pages",
		type=>"pagerange",
		editable=>1,
		visible=>1
	},
	{
		name=>"pubdom",
		type=>"boolean",
		editable=>1,
		visible=>1
	},
	{
		name=>"publication",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"publisher",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"refereed",
		type=>"boolean",
		editable=>1,
		visible=>1
	},
	{
		name=>"referencetext",
		type=>"longtext",
		editable=>1,
		visible=>1,
		displaylines=>3
	},
	{
		name=>"reportno",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"thesistype",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"title",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"organization",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"pind",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"address",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"journal",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"school",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"note",
		type=>"longtext",
		editable=>1,
		visible=>1
	},
	{
		name=>"volume",
		type=>"text",
		maxlength=>"6",
		editable=>1,
		visible=>1
	},
	{
		name=>"year",
		type=>"year",
		editable=>1,
		visible=>1
	}
];
	
$self->{sitetypes}->{eprint} = {
	"bookchapter"=>[
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"REQUIRED:abstract",
		"REQUIRED:publication",
		"chapter",
		"pages",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"confpaper"=>[
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"REQUIRED:abstract",
		"REQUIRED:conference",
		"pages",
		"confdates",
		"confloc",
		"volume",
		"number",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"confposter"=>[
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"REQUIRED:abstract",
		"REQUIRED:conference",
		"pages",
		"confdates",
		"confloc",
		"volume",
		"number",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"techreport"=>[
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:department",
		"REQUIRED:institution",
		"reportno",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"journale"=>[
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:publication",
		"volume",
		"number",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"journalp"=>[
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:publication",
		"volume",
		"number",
		"pages",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"newsarticle"=>[
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:publication",
		"volume",
		"number",
		"pages",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"other"=>[
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"preprint"=>[
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"thesis"=>[
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:thesistype",
		"REQUIRED:department",
		"REQUIRED:institution",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	]
};

$self->{sitetypes}->{user} = { 
	Staff => [],
	User => []
};

######################################################################
#
#  Site Look and Feel
#
######################################################################

# Location of the root of the subject tree
#$EPrintSite::SiteInfo::server_subject_view_root = 
#	$EPrintSite::SiteInfo::server_subject_view_stem."ROOT.html";

# parameters to generate the HTML header with.
# TITLE will be set by the system as appropriate.
# See the CGI.pm manpage for more info ( man CGI ).

$self->{start_html_params}  = {
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
	-MARGINHEIGHT=>"0" };

# This is the HTML put at the top of every page. It will be put in the <BODY>,
#  so shouldn't include a <BODY> tag.
$self->{html_banner} = <<END;
<table border="0" cellpadding="0" cellspacing="0">
  <tr>
    <td align="center" valign="top" bgcolor="#dddddd" fgcolor="white">
      <br>
      <a href="$self->{frontpage}"><img border="0" width="100" height="100" src="$self->{server_static}/images/logo_sidebar.gif" ALT="$self->{sitename}"></a>
    </td>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderr.gif"></td>
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
            <A HREF="$self->{frontpage}">Home</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_static}/information.html">About</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_subject_view_stem}"."ROOT.html">Browse</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_perl/search">Search</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_static}/register.html">Register</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_perl/users/subscribe">Subscriptions</A>\&nbsp;<BR><BR>
            <A HREF="$EPrintSite::SiteInfo::server_perl/users/home">Deposit\&nbsp;Items</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_static}/help">Help</A>
          </td>
        </tr>
      </table>
      <br>
    </td>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderr.gif"></td>
    <td>
      &nbsp;&nbsp;&nbsp;&nbsp;
    </td>
    <td valign="top" width="95%">
<BR>
END

# This is the HTML put at the bottom of every page. Obviously, it should close
#  up any tags left open in html_banner.
$self->{html_tail} = <<END;
<BR>
<HR noshade size="2">
<address>
Contact site administrator at: <a href=\"mailto:$EPrintSite::SiteInfo::admin\">$EPrintSite::SiteInfo::admin</a>
</address>
<BR><BR>
    </td>
  </tr>
  <tr>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderb.gif"></td>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderc.gif"></td>
  </tr>
</table>
END

#  E-mail signature, appended to every email sent by the software
$self->{signature} = <<END;
--
 $self->{sitename}
 $self->{frontpage}
 $EPrintSite::SiteInfo::admin

END

#  Default text to send a user when "bouncing" a submission back to their
#  workspace. It should leave some space for staff to give a reason.
$self->{default_bounce_reason} = <<END;
Unfortunately your eprint:

  _SUBMISSION_TITLE_

could not be accepted into $self->{sitename} as-is.


The eprint has been returned to your workspace. If you
visit your item depositing page you will be able to
edit your eprint, fix the problem and redeposit.

END

#  Default text to send a user when rejecting a submission outright.
$self->{default_delete_reason} = <<END;
Unfortunately your eprint:

  _SUBMISSION_TITLE_

could not be accepted into $self->{sitename}.



The eprint has been deleted.

END

#  Agreement text, for when user completes the depositing process.
#  Set to "undef" if you don't want it to appear.
$self->{deposit_agreement_text} = <<END;

<P><EM><STRONG>For work being deposited by its own author:</STRONG> 
In self-archiving this collection of files and associated bibliographic 
metadata, I grant $self->{sitename} the right to store 
them and to make them permanently available publicly for free on-line. 
I declare that this material is my own intellectual property and I 
understand that $self->{sitename} does not assume any 
responsibility if there is any breach of copyright in distributing these 
files or metadata. (All authors are urged to prominently assert their 
copyright on the title page of their work.)</EM></P>

<P><EM><STRONG>For work being deposited by someone other than its 
author:</STRONG> I hereby declare that the collection of files and 
associated bibliographic metadata that I am archiving at 
$self->{sitename}) is in the public domain. If this is 
not the case, I accept full responsibility for any breach of copyright 
that distributing these files or metadata may entail.</EM></P>

<P>Clicking on the deposit button indicates your agreement to these 
terms.</P>
END

	
######################################################################
#
#  Search and subscription information
#
#   Before the site goes live, ensure that these are correct and work OK.
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

# Fields for a simple user search
$self->{simple_search_fields} =
[
	"title/abstract/keywords",
	"authors/editors",
	"publication/organization",
	"year"
];

# Fields for an advanced user search
$self->{advanced_search_fields} =
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
	"institution",
	"ispublished",
	"refereed",
	"publication",
	"year"
];

# Fields used for specifying a subscription
$self->{subscription_fields} =
[
	"subjects",
	"refereed",
	"ispublished"
];

# Ways of ordering search results
$self->{eprint_order_methods} =
{
	"by year (most recent first)" 
		=> \&eprint_cmp_by_year,
	"by year (oldest first)"      
		=> \&eprint_cmp_by_year_oldest_first,
	"by author's name"            
		=> \&eprint_cmp_by_author,
	"by title"                    
		=> \&eprint_cmp_by_title 
};

# The default way of ordering a search result
#   (must be key to %eprint_order_methods)
$self->{eprint_default_order} = "by author's name";

# How to order the articles in a "browse by subject" view.
$self->{subject_view_order} = \&eprint_cmp_by_author;

# Fields for a staff user search.
$self->{user_search_fields} =
[
	"name",
	"dept/org",
	"address/country",
	"groups",
	"email"
];

# Ways to order the results of a staff user search.
# cjg needs doing....
$self->{user_order_methods} =
{
	"by surname"                          => "name",
	"by joining date (most recent first)" => "joined DESC, name",
	"by joining date (oldest first)"      => "joined ASC, name",
	"by group"                            => "group, name "
};

# Default order for a staff user search (must be key to user_order_methods)
$self->{default_user_order} = "by surname";	

# How to display articles in "version of" and "commentary" threads.
#  See lib/Citation.pm for information on how to specify this.
$self->{thread_citation_specs} =
{
	"succeeds"   => "{title} (deposited {datestamp})",
	"commentary" => "{authors}. {title}. (deposited {datestamp})"
};


	return $self;
}

######################################################################
#
# Sort Routines
#
#  The following routines are used to sort lists of eprints according
#  to different schemes. They are linked to text descriptions of ways
#  of ordering eprints lists in SiteInfo.
#
#  Each method has two automatic parameters $_[0] and $_[1], both of which 
#  are eprint objects. The routine should return 
#   -1 if $_[0] is earlier in the ordering scheme than $_[1]
#    1 if $_[0] is later in the ordering scheme than $_[1]
#    0 if $_[0] is at the same point in the ordering scheme than $_[1]
#
#  These routines are not called by name, but by reference (see above)
#  so you can create your own methods as long as you add them to the
#  hash of sort methods.
#
######################################################################

sub eprint_cmp_by_year
{
	return ( $_[1]->{year} <=> $_[0]->{year} ) ||
		EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[0]->{title} cmp $_[1]->{title} ) ;
}

sub eprint_cmp_by_year_oldest_first
{
	return ( $_[0]->{year} <=> $_[1]->{year} ) ||
		EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[0]->{title} cmp $_[1]->{title} ) ;
}

sub eprint_cmp_by_author
{
	
	return EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[1]->{year} <=> $_[0]->{year} ) || # largest year first
		( $_[0]->{title} cmp $_[1]->{title} ) ;
}

sub eprint_cmp_by_title
{
	return ( $_[0]->{title} cmp $_[1]->{title} ) ||
		EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[1]->{year} <=> $_[0]->{year} ) ; # largest year first
}


1;
