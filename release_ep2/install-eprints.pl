#!/usr/bin/perl -w

use strict;

print <<INTRO;
EPrints 2 Installer
-------------------

This installer creates the necessary directories and files for 
you to begin configuring EPrints 2.

INTRO

print "Checking user...";
if (0) #($<!=0) -- removed while testing.
{
	print "Failed!\n";
	print "Sorry, his installer must be run as root.\n";
	exit 1;
}
else { print "OK.\n\n"; }

print <<USER;
EPrints must be run as a non-root user (typically 'eprints').
Please specify the user that you wish to use, or press enter to use
the default.

USER

my $user = get_string("User", "eprints");

# Check to see if user exists.
my $exists = 1;
my(undef, undef, $ruid, $rgid) = getpwnam($user) or $exists = 0;
my($name, $gid) = getgrnam($user);

if (!$exists)
{
	print <<GROUP;
User $user does not currently exist, so a group will be required
before it can be created. Please specify the group you would like
to use.

GROUP
	my $group = get_string("Group", "eprints");
	print "Creating group...";
	if (system("/usr/sbin/groupadd $group")==0)
	{
		print "OK.\n\n";
	}
	else
	{
		print "Failed!\n";
		print "Unable to create EPrints group: $!\n";
		exit 1;
	}

	print "Creating user...";
	if (system("/usr/sbin/useradd -g $group $user")==0)
	{
		print "OK.\n\n";
	} 
	else
	{
		print "Failed!\n";
		print "Unable to create EPrints user: $!\n";
		exit 1;
	}
}

print <<DIR;
EPrints installs by default to the /opt/eprints directory. If you
would like to install to a different directory, please specify it
here.

DIR

my $dir = get_string("Directory", "/opt/eprints");
print "Making directory...";
if (!mkdir($dir))
{
	print "Failed!\n";
	print "Unable to make installation directory.\n";
	exit 1;
}
else
{ print "OK.\n\n"; }


sub get_string
{
	my($question, $default) = @_;
	my($response) = "";
	
	print "$question [$default] :";
	# Get response and set to default if necessary.
	$response = <STDIN>;
	chomp($response);
	if ($response eq "") { $response = $default; }
	return $response;
}
