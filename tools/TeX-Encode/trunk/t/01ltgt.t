# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Encode-LaTeX.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 3;
use Encode;
BEGIN { use_ok('TeX::Encode') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $str = "begin \$d_<=x/2\$ between \$d_>=3x/2\$ end";

is(decode('latex', $str), "begin <span class='mathrm'>d<sub>&lt;</sub>=x/2</span> between <span class='mathrm'>d<sub>&gt;</sub>=3x/2</span> end");

ok(1);
