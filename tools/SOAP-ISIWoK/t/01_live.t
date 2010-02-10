# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl SOAP-ISIWoK.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('SOAP::ISIWoK') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

SKIP: {
	skip "Set SOAP_ISIWOK", 1 if !$ENV{SOAP_ISIWOK};

	my $wok = SOAP::ISIWoK->new();

	my $results = $wok->search( "OG = (Southampton)", max => 2 );

	diag( $results->toString( 1 ) );
	ok(1);
};
