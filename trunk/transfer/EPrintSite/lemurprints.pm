
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

#  Files

$self->{user_meta_file} 	= "$self->{site_root}/cfg/metadata.user";
$self->{eprint_fields_file}	= "$self->{site_root}/cfg/metadata.eprint-fields";
$self->{eprint_types_file} 	= "$self->{site_root}/cfg/metadata.eprint-types";
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
 
$self->{usertypes} = {
	User=>{ 
		auth_routine => \&Apache::AuthDBI::authen,
		auth_conf => {
			Auth_DBI_data_source => $connect_string,
			Auth_DBI_username => $self->{db_user},
			Auth_DBI_password => $self->{db_pass},
			Auth_DBI_pwd_table => "users",
			Auth_DBI_uid_field => "username",
			Auth_DBI_pwd_field => "passwd",
			Auth_DBI_grp_field => "groups",
			Auth_DBI_encrypted => "off" },
		auth_priv => [ "user" ] },
	Staff=>{ 
		auth_routine => \&Apache::AuthDBI::authen,
		auth_conf => {
			Auth_DBI_data_source => $connect_string,
			Auth_DBI_username => $self->{db_user},
			Auth_DBI_password => $self->{db_pass},
			Auth_DBI_pwd_table => "users",
			Auth_DBI_uid_field => "username",
			Auth_DBI_pwd_field => "passwd",
			Auth_DBI_grp_field => "groups",
			Auth_DBI_encrypted => "off" }, 
		auth_priv => [ "user" ] }
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
