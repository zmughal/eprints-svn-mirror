#!/usr/bin/perl -w

my $ARCID;
BEGIN
{
	@INC = ( '/opt/eprints2/perl_lib',@INC);
	$ARCID = "ep2stable";
}
use Test::More tests => 16;

use EPrints;

# load perl modules
ok(require EPrints::Session,'loaded EPrints::Session');

# open a noisy offline session with no database check
my $session = EPrints::Session->new( 1, $ARCID, 2, 1 );
ok(defined $session, 'opened an EPrints::Session object (noisy, no_check_db)');

# check it's the right type
ok($session->isa(EPrints::Session),'it really was an EPrints::Session');

is($session->{noise},2,"Correct noise setting?");
is($session->{offline},1,"Correct offline setting?");
is($session->{query},undef,"There should be no query, we're offline");

ok(defined $session->get_archive, "is there an archive config attached?");
ok($session->get_archive->isa(EPrints::Archive), "and it's really an archive config?");


ok(defined $session->get_db, "is there a database attached?");
ok($session->get_db->isa(EPrints::Database), "and it's really an EPrints::Database?");

ok(defined $session->{doc}, "is there a XML base document?");
ok($session->{doc}->isa(XML::GDOME::Document), "and it's really an XML::GDOME::Document?");

ok(defined $session->{lang}, "session has a language set" );
ok($session->{lang}->isa(EPrints::Language), "and it's EPrints::Language" );
is($session->{lang}->{id}, 'en', "and it's the default (english)" );
$session->terminate;


# open a quiet session and check the db is correct version
$session = EPrints::Session->new( 1, $ARCID, 0, 0 );
ok(defined $session, 'opened an EPrints::Session object' );

$session->terminate;


# TODO
# need to check it works under mod_perl
# test all the methods!
