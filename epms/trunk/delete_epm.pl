#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;

# CONF

# collection end point:
my $sword_url = "http://bazaar.eprints.org/id/eprint/" . $ARGV[0];

# credentials:
print "Username: ";
my $username = Term::ReadKey::ReadLine( 0 );
BEGIN {
	eval "use Term::ReadKey";
	eval "use Compat::Term::ReadKey" if $@;
}
print "Enter your password: "; 
Term::ReadKey::ReadMode('noecho');
my $password = Term::ReadKey::ReadLine( 0 );
Term::ReadKey::ReadMode('normal');
#$password =~ s/\015?\012?$//s;
print "\n";

chomp $username;
chomp $password;

my $realm = 'Bazaar Store';
my $host = 'bazaar.eprints.org:80';

my $ua = LWP::UserAgent->new();

$ua->credentials(
	"$host",
	"$realm",
	"$username" => "$password"
);

my $req = HTTP::Request->new( DELETE => $sword_url );

my $res = $ua->request($req);

print $res->status_line . "\n";
print $res->content;

exit;
