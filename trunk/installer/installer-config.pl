%ENVIRONMENT =
(
	installer_version	=> "0.2",
	# 1 to display lots of info, 0 for a more concise mode. Set with --verbose on command-line.
	# silent takes precedence, and automagically forces verbose to 0.
	verbose			=> 1,
	# Display nothing.
	silent			=> 0,
	# 0 if the package is not installed, version number otherwise. You can use this to force the installation
	# of required packages. Can be forced at command-line with '--packagename_installed'
	gzip_installed		=> 0,
	xercesc_installed	=> 0,
	xercesp_installed	=> 0,
	eprints_installed	=> 0,
	apache_installed	=> 0,
	modperl_installed	=> 0,
	mysql_installed		=> 0,
	cgi_installed		=> 0,
	data_dumper_installed	=> 0,
	dbi_installed		=> 0,
	msql_installed		=> 0,	
	diskspace_installed	=> 0,
	mimebase_installed	=> 0,

	# 0 if we don't want resuming. Unset with --noresuming.
	resuming		=> 0,
	# Where to dump the resume file. Set with --resume_file=foo.
	resume_file		=> "install.resume",
	# Whether to fully automate the install (i.e. use all defaults). Handy for doing
	# lots of installs :-) Set with --automate_install.
	automate_install	=> 0,
	# System architecture. Set with --arch="foo". 
	system_arch		=> "linux",
	# Set to 1 if root is unecessary. It probably will be needed, so --no_root is the 
	# command-line option.
	no_root			=> 0,
	# Where to search for installed libraries. This can be set with --libraries. Contains
	# a colon-separated list. At runtime, $LD_LIBRARY_PATH is appended to this list, as is
	# the contents of /etc/ld.so.conf if running under Linux.
	library_paths		=> "/lib:/usr/lib/:/usr/local/lib/",
);

@PACKAGES =
(
	{
		name		=> "gzip",
		min_version	=> "1.2.4",
		search_string	=> "gzip-([0-9]+)\.([0-9]+)\.([0-9]+)\.tar",
		long_name	=> "GNU Zip",
		description	=> "`gzip' reduces the size of files using Lempel-Ziv coding (LZ77).",
		install_method	=> "standardinstall",
		check_method	=> "standardcheck gzip",
	},
	{
		name		=> "wget",
		min_version	=> "1.5",
		search_string	=> "wget-([0-9]+)\.([0-9]+)\.?([0-9]*)\.tar",
		long_name	=> "GNU Wget",
		description	=> "Freely available network utility to retrieve files from the World Wide Web using HTTP and FTP",
		install_method	=> "standardinstall",
		check_method	=> "standardcheck wget"
	},
	{
                name            => "xercesc",
                min_version     => "1.5",
		search_string	=> "xerces-c-src([0-9]+)_([0-9]+)_([0-9]+)\.tar\.gz",
               # search_string   => "xerces-c([0-9]+)_([0-9]+)_([0-9]+)-linux\.tar\.gz",
                long_name       => "Xerces-C",
                description     => "Xerces-C is a validating XML parser written in a portable subset if C++. Xerces-C makes it easy to give your application the ability to read and write XML data. A shared library is provided for parsing, generating, manipulating, and validating XML documents. Xerces-C is faithful to the XML 1.0 recommendation and associated standards. Xerces-C 1.5 also provides the implementation of a subset of the Schema. Provides high performance, modularity, and scalability.",
        },
	{
		name		=> "xercesp",
		min_version	=> "1.5.0",
		search_string	=> "XML-Xerces-([0-9]+)\.([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "Xerces-C Perl bindings",
		description	=> "Xerces-P implements the Perl API to the Apache project's Xerces XML parser. It is implemented using the Xerces C++ API, and it provides access to most of the C++ API from Perl.",
		check_method	=> "perlcheck XML::Xerces",
	},
	{
		name		=> "apache",
		min_version	=> "1.3.14",
		search_string	=> "apache_([0-9]+)\.([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "Apache web server",
		description	=> "HTTP server designed as a plug-in replacement for the NCSA server version 1.4 (or 1.4). It fixes numerous bugs in the NCSA server and includes many frequently requested new features, and has an API which allows it to be extended to meet users' needs more easily.",
	},
	{
		name		=> "modperl",
		min_version	=> "1.25",
		search_string	=> "mod_perl-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "mod_perl Apache Perl interpreter",
		description	=> "mod_perl links the Perl runtime library into the Apache server, allowing Apache modules written entirely in Perl. The persistent embedded interpreter avoids the overhead of starting an external interpreter and the penalty of Perl start-up (compile) time.",
		check_method	=> "perlcheck mod_perl",
	},
	{
		name		=> "mysql",
		min_version	=> "3.23.39",
		search_string	=> "mysql-([0-9]+)\.([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "MySQL",
		description	=> "The most popular Open Source SQL-based relational database management system. It is fast, reliable, and easy to use, and has a large amount of contributed software.",
		check_method	=> "standardcheck mysql",
	},
	# Perl modules
	{
		name		=> "cgi",
		min_version	=> "2.6",
		search_string	=> "CGI\.pm-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "the CGI module",
		description	=> "Perl library using perl5 objects to make it easy to create Web fill-out forms and parse their contents. Provides shortcut functions for making boilerplate HTML, and functionality for more advanced CGI scripting features.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck CGI",
	},
	{
		name		=> "data_dumper",
		min_version	=> "2.101",
		search_string	=> "Data-Dumper-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "the DataDumper module",
		description	=> "The Perl data-structure printing/stringification module.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck Data::Dumper",
	},
	{
		name		=> "dbi",
		min_version	=> "1.14",
		search_string	=> "DBI-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "the DBI module",
		description	=> "DBI is a database access API for the Perl Language. The DBI API Specification defines a set of functions, variables, and conventions that provide a consistent database interface independent of the actual database being used.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck DBI",
	},
	{
		name		=> "msql",
		min_version	=> "1.2",
		search_string	=> "Msql-Mysql-modules-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "the mSQL/mySQL drivers",
		description	=> "DBD::mysql and DBD:mSQL are the perl5 Database Interface drivers for the mysql, mSAQL 1.x and mSQL 2.x databases. They are an interface between the Perl programming language and the mSQL or mysql programming API.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck Mysql",
	},
	{
		name		=> "diskspace",
		min_version	=> "0.05",
		search_string	=> "Filesys-DiskSpace-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "Perl df",
		description	=> "Displays information on a file system such as its type, amount of disk space occupied, total disk space, and number of inodes.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck Filesys::DiskSpace",
	},
	{
		name		=> "mimebase",
		min_version	=> "2.11",
		search_string	=> "MIME-Base64-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "the MIME-Base64 module",
		description	=> "Provides functions to encode and decode strings into the RFC 2045 Base64 encoding. Designed to represent arbitrary sequences of octets in a form that need not be humanly readable.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck MIME::Base64",
	},
	{
		name		=> "eprints",
		min_version	=> "1.1.1",
		search_string	=> "eprints-([0-9]+)\.([0-9]+)\.?([0-9]*)\.tar\.gz",
		long_name	=> "ePrints",
		description	=> "ePrints is dedicated to the freeing of the refereed research literature online through author/institution self-archiving. It complements centralised, discipline-based archiving with distributed, institution-based archiving.",
	},
);

# Custom package check methods

sub xercesc_check
{
        $curr_highversion = 0;
        @libs = get_library_paths("xerces-c");

        foreach(@libs)
        {
                s/.*\///;               # Get short name
                if (/libxerces-c([0-9]+)_([0-9]+).so/)
                {
                        $version = "$1.$2";
                        if (compare_version($version, $curr_highversion)>0) { $curr_highversion = $version; }
                }
        }
        return $curr_highversion;
}

sub eprints_check
{
        return 0;
}

sub apache_check
{
        my($httpd) = "";

        $httpd = `/usr/local/apache/bin/httpd -v 2>&1`;
        if ($httpd =~ /(\d+)\.(\d+)\.?(\d*)/)
        {
                return "$1.$2.$3";
        }
        return 0;
}


# Custom package install methods

sub xercesc_install
{
	my($package) = @_;
	$currdir = getcwd();
	chdir decompress($package->{archive});
	$longname = getcwd();
	$ENV{XERCESCROOT} = $longname;
	chdir "src";
	print "Configuring	...";
	`autoconf`;
	`./configure`;
	print "	Done.\n";
#       print "Making	...";
#       `make 2>&1 1>/dev/null`;
	print "	Done.\n";
	chdir $currdir;
	return 1;
}

sub xercesp_install
{
	my($package) = @_;
	$currdir = getcwd();
	chdir decompress($package->{archive});
	print "Configuring	...";
	`perl Makefile.PL`;
 	print "	Done.\n";
#       print "Making		...";
#       `make 2>&1 1>/dev/null`;
#       print " Done.\n";
#       print "Testing		...";
#       `make test`;
#	print "	Done.\n";
	chdir $currdir;
	return 1;
}

sub apache_install
{
	return 1;
}

sub modperl_install
{
	return 1;
}

sub mysql_install
{
	return 1;
}

sub eprints_install
{
	return 1;
}
