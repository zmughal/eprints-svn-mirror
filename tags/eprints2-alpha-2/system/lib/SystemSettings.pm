######################################################################
#
# COMMENTME
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################
# HEADERS cjg

# This is only for the CVS version. It should be auto-generated by the
# installer.

# This file should only be use'd by EPrints::Config
package EPrints::SystemSettings;

$EPrints::SystemSettings::conf = 
{
	base_path => "/opt/eprints",
	executables => {
		unzip 	=> "/usr/bin/unzip",
		wget 	=> "/usr/bin/wget",
		sendmail => "/usr/sbin/sendmail",
		gunzip 	=> "/bin/gunzip",
		tar 	=> "/bin/tar"
	},
	invocation => {
		zip 	=> '$(zip) 1>/dev/null 2>&1 -qq -o -d $(DIR) $(ARC)',
	        targz  	=> '$(gunzip) -c < $(ARC) 2>/dev/null | $(tar) xf - -C $(DIR) >/dev/null 2>&1',
		wget 	=> '$(wget)  -r -L -q -m -nH -np --execute="robots=off" --cut-dirs=$(CUTDIRS) $(URL)',
		sendmail => '$(sendmail) -oi -t -odb --'
	},
	archive_extensions => {
		"zip"    =>  ".zip",
		"targz"  =>  ".tar.gz"
	},
	archive_formats => [ "zip", "targz" ],
	version_id => "CVS",
	version => "EPrints 2.? CVS Version",
	user => "eprints",
	group => "eprints"
};

1;