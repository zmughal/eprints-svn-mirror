######################################################################
#
# URLS
#
#  These probably don't need changing.
#
######################################################################

# Site "home page" address
$c->{frontpage} = "$c->{base_url}/";

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

