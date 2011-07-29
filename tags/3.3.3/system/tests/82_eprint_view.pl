use strict;
use Test::More tests => 4;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::ScreenProcessor" ); }

my $session = EPrints::Test::get_test_session();

# find an example eprint
my $dataset = $session->dataset( "eprint" );
my( $eprintid ) = @{ $dataset->get_item_ids( $session ) };

$session = EPrints::Test::OnlineSession->new( $session, {
	method => "GET",
	path => "/cgi/users/home",
	username => "admin",
	query => {
		screen => "EPrint::View",
		eprintid => $eprintid,
	},
});

EPrints::ScreenProcessor->process(
	session => $session,
	url => $session->config( "base_url" ) . "/cgi/users/home"
	);

$session->terminate;

my $content = $session->test_get_stdout();

#diag($content);

ok(1);
