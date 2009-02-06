# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Encode-LaTeX.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 4;
use Encode;
BEGIN { use_ok('TeX::Encode') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $chr = chr(0xfffd); # what character will never be supported by TeX?
my $str = "start ".$chr." end";

my $left = encode('latex', $str, Encode::FB_QUIET);

is( $left, "start " );
is( $str, $chr." end" );

ok(1);
