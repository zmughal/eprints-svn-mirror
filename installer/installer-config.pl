%ENVIRONMENT =
(
	installer_title		=> "ePrints Installer",
	installer_version	=> "0.21",
	# 1 to display lots of info, 0 for a more concise mode. Set with --verbose on command-line.
	# silent takes precedence, and automagically forces verbose to 0.
	verbose			=> 1,
	# Display nothing.
	silent			=> 0,

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

	# System-specific
	add_group		=> "/usr/sbin/groupadd",
	add_user		=> "/usr/sbin/useradd",
);

@PACKAGES =
(
	{
		name		=> "perl",
		min_version	=> "5.6.0",
	},
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
		name		=> "apache",
		min_version	=> "1.3.14",
		search_string	=> "apache_([0-9]+)\.([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "Apache web server",
		description	=> "HTTP server designed as a plug-in replacement for the NCSA server version 1.4. It fixes numerous bugs in the NCSA server and includes many frequently requested new features, and has an API which allows it to be extended to meet users' needs more easily.",
		check_method	=> "standardcheck httpd /usr/local/apache/bin",
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
		long_name	=> "DataDumper",
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
		long_name	=> "MIME-Base64",
		description	=> "Provides functions to encode and decode strings into the RFC 2045 Base64 encoding. Designed to represent arbitrary sequences of octets in a form that need not be humanly readable.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck MIME::Base64",
	},
	{
		name		=> "unicode",
		min_version	=> "2.06",
		search_string	=> "Unicode-String-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "Unicode::String",
		description	=> "Provides an object representation of a sequence of Unicode characters. The Unicode standard is a fixed-width uniform encoding scheme for written characters and text.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck Unicode::String",
	},
	{
		name		=> "uri",
		min_version	=> "1.10",
		search_string	=> "URI-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "URI",
		description	=> "Provides an object representation of Uniform Resource Identifiers (compact strings of characters for identifying abstract or physical resources).",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck URI",
	},
	{
		name		=> "xmlwriter",
		min_version	=> "0.4",
		search_string	=> "XML-Writer-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "XML Writer",
		description	=> "XML::Writer is a helper module for Perl programs that write an XML document. The module handles all escaping for attribute values and character data and constructs different types of markup, such as tags, comments, and processing instructions.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck XML::Writer",
	},
	{
		name		=> "apachedbi",
		min_version	=> "0.87",
		search_string	=> "ApacheDBI-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "Apache DBI",
		description	=> "Initiates a persistent database connection using Perl's DBI (Database Independent) interface.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck Apache::AuthDBI",
	},
	{
		name		=> "htmlparser",
		min_version	=> "3.25",
		search_string	=> "HTML-Parser-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "HTML Parser",
		description	=> "A collection of modules that parse and extract information from HTML documents.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck HTML::Parser",
	},
	{
		name		=> "libwww",
		min_version	=> "5.53",
		search_string	=> "libwww-perl-([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "LWP",
		description	=> "A collection of Perl modules providing a simple API to the World Wide Web. Required by XML::DOM.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck LWP",
	},
	{
		name		=> "xmlparser",
		min_version	=> "2.30",
		search_string	=> "XML-Parser\.([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "XML::Parser",
		description	=> "A Perl extension interface to the expat XML parser.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck XML::Parser",
	},
	{
		name		=> "libenno",
		min_version	=> "1.02",
		search_string	=> "libxml-enno-\([0-9]+)\.([0-9]+)\.tar\.gz",
		long_name	=> "XML::* Packages",
		description	=> "Contains XML::DOM, XML::XQL, XML::Checker, and several other packages. Also provides XML::RegExp, which is used by ePrints.",
		install_method	=> "perlinstall",
		check_method	=> "perlcheck XML::DOM",
	},
	{
		name		=> "eprints",
		min_version	=> "1.0",
		search_string	=> "eprints-([0-9]+)\.([0-9]+)\.?([0-9]*)\.tar\.gz",
		long_name	=> "ePrints",
		description	=> "ePrints is dedicated to the freeing of the refereed research literature online through author/institution self-archiving. It complements centralised, discipline-based archiving with distributed, institution-based archiving.",
	},
);

# Custom package check methods

sub perl_check
{
	# CLEANME
	# I didn't want to put this in the installer.pl section, as not
	# all programs require a specific version of Perl. As such, this
	# is a bit of an icky work-around.

	if ($^V lt v5.6.0)
	{
		exit_nicely("\n\nYou do not have a suitable version of Perl (>=5.6.1) installed. This is required to run the installer and ePrints.\nPlease install a newer version, and try again.\n");
	}
	elsif (!module_installed("File::Copy"))
	{
		exit_nicely("\n\nYou have a suitable version of Perl, but it does not appear to have some of the File::* modules. Please make sure these are present, and try again.\n");
	}
	skip_component("perl");

	return "5.6.0";
}

sub mysql_check
{
	my($sql) = "";
	$sql = `/usr/local/mysql/bin/mysql -V 2>&1` || return 0;
	if ($sql =~ /Distrib (\d+)\.(\d+)\.?(\d*)/)
	{
		return "$1.$2.$3";
	}
	return 0;
}

sub eprints_check
{
        return 0;
}

# Custom package install methods

sub apache_install
{
	my($package) = @_;
        $currdir = getcwd();
        chdir decompress($package->{archive});
	print "Configuring	...";
	`./configure --enable-module=rewrite --enable-module=auth`;
	print "	Done.\n";
	print "Making		...";
	`make 2>&1 1>/dev/null`;
	print "	Done.\n";
	`make install`;
	chdir $currdir;
	return 1;
}

sub modperl_install
{
	# FIXME
	my($package) = @_;
 	$currdir = getcwd();
        chdir decompress($package->{archive});
        print "Configuring	...";
	`echo "EVERYTHING=1 DO_HTTPD=1" > makepl_args.mod_perl`;
	`perl Makefile.PL`;
	print "	Done.\n";
	print "Making		...";
	`make 2>&1 1>/dev/null`;
	print "	Done.\n";
	`make install`;
	chdir $currdir;
	return 1;
}

sub mysql_install
{
	my($package) = @_;
	$currdir = getcwd();
	chdir decompress($package->{archive});
	print "Adding users	...";
	`$ENVIRONMENT{add_group} mysql`;
	`$ENVIRONMENT{add_user} -g mysql mysql`;
	print "	Done.\n";
	print "Configuring	...";
	`./configure --prefix=/usr/local/mysql`;
	print "	Done.\n";
	print "Making		...";
	`make`;
	print "	Done.\n";
	print "Installing	...";
	`make install`;
	print "	Done.\n";
	print "Installing DB	...";
	`scripts/mysql_install_db`;
	print "	Done.\n";

	print "Setting groups	...";
	# Get uid/gids
	(undef, undef, $ruid, $rgid) = getpwnam("root") or 
		fail_nicely("Root user not found.");
	(undef, undef, $muid, $mgid) = getpwnam("mysql") or 
		fail_nicely("Mysql user not found.");
	chown $ruid, $rgid, "/usr/local/mysql";
	@mysqlconts 	= get_dir_contents("/usr/local/mysql") or 
		fail_nicely("Unable to examine /usr/local/mysql");
	@mysqlvarconts	= get_dir_contents("/usr/local/mysql/var") or 
		fail_nicely("Unable to examine /usr/local/mysql/var");

	# Do the chown/chgrping.
	fail_nicely("Couldn't chown all files in /usr/local/mysql") 
		if (chown $ruid, -1, @mysqlconts != $#mysqlconts+1);

	fail_nicely("Couldn't chown all files in /usr/local/mysql/var") 
		if (chown( $muid, -1, @mysqlvarconts ) != $#mysqlvarconts+1);

	fail_nicely("Couldn't chown all files in /usr/local/mysql") 
		if (chown ( -1, $muid, @mysqlconts ) != $#mysqlconts+1);	

	print "	Done.\n";

	print "Starting up	...";
	`cp support-files/my-medium.cnf /etc/my.cnf`;
	system("/usr/local/mysql/bin/safe_mysqld --user=mysql &");
	print "	Done.\n";
	chdir $currdir;
	return 1;
}

sub eprints_install
{
	my($package) = @_;
	$currdir = getcwd();
	chdir "eprints";
	`./configure`;
	`make`;
	`make install`;
	chdir $currdir;
	return 1;
}
