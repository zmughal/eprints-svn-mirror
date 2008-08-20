# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Net-HoneyComb.t'

#########################

# change 'tests => 2' to 'tests => last_test_to_print';

use Test::More tests => 3;
BEGIN { use_ok('Net::HoneyComb') };


my $fail = 0;
foreach my $constname (qw(
	HC_BINARY_TYPE HC_BOGUS_TYPE HC_BYTE_TYPE HC_CHAR_TYPE HC_DATE_TYPE
	HC_DOUBLE_TYPE HC_LONG_TYPE HC_OBJECTID_TYPE
	HC_STRING_TYPE HC_TIMESTAMP_TYPE HC_TIME_TYPE HC_UNKNOWN_TYPE)) {
  next if (eval "my \$a = $constname; 1");
  if ($@ =~ /^Your vendor has not defined Net::HoneyComb macro $constname/) {
    print "# pass: $@";
  } else {
    print "# fail: $@";
    $fail = 1;
  }

}

ok( $fail == 0 , 'Constants' );
#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $honey = Net::HoneyComb->new( "hc-data", 8080 );

my $test_data = "Hello, World!\n";

my $data = $test_data;

my $oid = $honey->store_both( sub { my( $context, $len ) = @_; my $r = substr($data,0,$len); substr($data,0,$len) = ""; return $r }, undef, {} );

warn "Got oid=$oid\n";

$data = "";

$honey->retrieve( $oid, sub { my( $context, $buffer ) = @_; $data .= $buffer }, undef );

ok( $data eq $test_data );

$honey->delete( $oid );
