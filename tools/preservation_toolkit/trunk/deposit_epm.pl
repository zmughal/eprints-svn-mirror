#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;

# CONF

# collection end point:
my $sword_url = "http://bazaar.eprints.org/sword-app/deposit/archive";

# file to send via POST:
my $filename = $ARGV[0];

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

open(FILE, "$filename" ) or die('cant open input file');
binmode FILE;

my $ua = LWP::UserAgent->new();

$ua->credentials(
	"$host",
	"$realm",
	"$username" => "$password"
);

my $req = HTTP::Request->new( POST => $sword_url );

# Tell SWORD to process the XML file as EPrints XML
my $filebit = substr($filename,rindex($filename,"/")+1,length($filename));
$req->header( 'Content-Disposition' => 'form-data; name="'.$filebit.'"; filename="'.$filebit.'"');
#$req->header( 'X-Extract-Media' => 'true' );
#$req->header( 'X-Override-Metadata' => 'true' );
#$req->header( 'X-Extract-Archive' => 'true' );
$req->content_type( 'archive/zip+eprints_package' );

my $file = "";
while(<FILE>) { $file .= $_; }

$req->content( $file );

# Et Zzzzooo!
my $res = $ua->request($req);	

if ($res->is_success) 
{
	print $res->content;
}
else 
{
	print $res->status_line;
	print "\n";
	print $res->content;
}

close(FILE);
exit;
