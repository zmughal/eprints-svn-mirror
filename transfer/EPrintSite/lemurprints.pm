
# Lemur Prints!

use EPrintSite;

package EPrintSite::lemurprints;

sub new
{
	my( $class ) = @_;

	my $self = {};
	bless $self, $class;

#  Main

$self->{site_root} = $EPrintSite::base_path."/sites/lemurprints";

$self->{local_document_root} = "$self->{site_root}/html/docs";

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
