
######################################################################
#
# Local Paths 
#
#  These probably don't need changing.
#
######################################################################

# Where the coversheets are stored:
$c->{coversheets_path_suffix} = '/coversheets';
$c->{coversheets_path} = $c->{archiveroot}."/cfg/static".$c->{coversheets_path_suffix};
$c->{coversheets_url} = $c->{base_url}.$c->{coversheets_path_suffix};

# Where the full texts (document files) are stored:
$c->{documents_path} = $c->{archiveroot}."/documents";

# The location of the configuration files (and where some
# automatic files will be written to)
# Don't change it!
$c->{config_path} = $c->{archiveroot}."/cfg";

# The location where eprints will build the website
$c->{htdocs_path} = $c->{archiveroot}."/html";


