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
		gunzip 	=> "???",
		tar 	=> "/bin/tar"
	},
	invocation => {
		ZIP 	=> "$(EXE_ZIP) 1>/dev/null 2>\&1 -qq -o -d $(DIR) $(ARC)",
	        TARGZ  	=> "$(EXE_GUNZIP) -c < $(ARC) 2>/dev/null | $(EXE_TAR) xf - -C $(DIR) >/dev/null 2>\&1",
		WGET 	=> "$(EXE_WGET)  -r -L -q -m -nH -np --execute=\"robots=off\" --cut-dirs=$(CUTDIRS) $(URL)",
		SENDMAIL => "$(EXE_SENDMAIL) -oi -t -odb --"
	},
	archive_extensions => {
		"ZIP"    =>  ".zip",
		"TARGZ"  =>  ".tar.gz"
	},
	archives => [ "ZIP", "TARGZ" ],
	version => "2.0.a.2001-09-04",
	version_desc => "EPrints 2.0 Alpha (Nightly Build 2001-09-04)",
	orig_version => "2.0.a",
	orig_version_desc => "EPrints 2.0 Alpha (Anchovy)",
	user => "eprints",
	group => "eprints"
};

1;
