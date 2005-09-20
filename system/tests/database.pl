#!/usr/bin/perl -w  

use Test::More tests => 14;

use TestLib;
use EPrints::Database;
use Test::MockObject;
use strict;








my $mocksth;
my $mockdb;
my $mockdbh;
my $mocksession;
my $mockarchive;


# testing get_index_ids

$mocksth = Test::MockObject->new();
$mocksth->set_true( 'finish' );

$mockdb = Test::MockObject->new();
$mockdb->set_true( 'execute' );
$mockdb->set_always( 'prepare', $mocksth );
#ok( $mockdb->somemethod() );

$mocksth->set_series( 'fetchrow_array', ('100:200:300'), () );
ok( eq_set( EPrints::Database::get_index_ids( $mockdb, 'aaa', 'bbb' ), [100,200,300] ), 'Simple case' );

$mocksth->set_series( 'fetchrow_array', (join( ":",1..20000), () ) );
ok( eq_set( EPrints::Database::get_index_ids( $mockdb, 'aaa', 'bbb' ), [1..20000] ), '20000 items in one row' );

$mocksth->set_series( 'fetchrow_array', ('1:2:3:4:5:6:100:200:4:5'), () );
ok( eq_set( EPrints::Database::get_index_ids( $mockdb, 'aaa', 'bbb' ), [1,2,3,4,5,6,100,200] ), 'Duplicates' );

$mocksth->set_series( 'fetchrow_array', ('1'), () );
ok( eq_set( EPrints::Database::get_index_ids( $mockdb, 'aaa', 'bbb' ), [1] ), 'Single item' );

$mocksth->set_series( 'fetchrow_array', () );
ok( eq_set( EPrints::Database::get_index_ids( $mockdb, 'aaa', 'bbb' ), [] ), 'No items' );

$mocksth->set_series( 'fetchrow_array', ('1:2:3'),('4:5:6'),('7:8:9'),()) ;
ok( eq_set( EPrints::Database::get_index_ids( $mockdb, 'aaa', 'bbb' ), [1,2,3,4,5,6,7,8,9] ), 'Multiple rows' );

####################

my @args;

# test SQL regexp callback: sub do

$mockdb = Test::MockObject->new();
$mockdbh = Test::MockObject->new();
$mocksession = Test::MockObject->new();
$mockarchive = Test::MockObject->new();
$mockdb->{dbh} = $mockdbh;
$mockdb->{session} = $mocksession;
$mocksession->set_always( 'get_archive',$mockarchive );
$mockarchive->set_always( 'get_conf', undef );
$mockdbh->set_true( 'do' );
ok( EPrints::Database::do( $mockdb, "some_sql" ), "basic call to sub do" );
@args = $mockdbh->call_args( 0 );
ok( eq_array( \@args, [$mockdbh,'some_sql'] ), "passed SQL to database OK" );

$mockdb = Test::MockObject->new();
$mockdbh = Test::MockObject->new();
$mocksession = Test::MockObject->new();
$mockarchive = Test::MockObject->new();
$mockdb->{dbh} = $mockdbh;
$mockdb->{session} = $mocksession;
$mocksession->set_always( 'get_archive',$mockarchive );
$mockarchive->set_always( 'get_conf', sub { my( $sql ) = @_; $sql="\U$sql"; return $sql;} );
$mockdbh->set_true( 'do' );
ok( EPrints::Database::do( $mockdb, "some_sql" ), "(with callback) basic call to sub do" );
@args = $mockdbh->call_args( 0 );
ok( eq_array( \@args, [$mockdbh,'SOME_SQL'] ), "(with callback) passed SQL to database OK" );


# test SQL regexp callback: sub prepare
$mockdb = Test::MockObject->new();
$mockdbh = Test::MockObject->new();
$mocksth = Test::MockObject->new();
$mocksession = Test::MockObject->new();
$mockarchive = Test::MockObject->new();
$mockdb->{dbh} = $mockdbh;
$mockdb->{session} = $mocksession;
$mocksession->set_always( 'get_archive',$mockarchive );
$mockarchive->set_always( 'get_conf', undef );
$mockdbh->set_always( 'prepare', $mocksth );
is( EPrints::Database::prepare( $mockdb, "some_sql" ), $mocksth, "basic call to sub prepare" );
@args = $mockdbh->call_args( 0 );
ok( eq_array( \@args, [$mockdbh,'some_sql'] ), "passed SQL to database OK" );


$mockdb = Test::MockObject->new();
$mockdbh = Test::MockObject->new();
$mocksth = Test::MockObject->new();
$mocksession = Test::MockObject->new();
$mockarchive = Test::MockObject->new();
$mockdb->{dbh} = $mockdbh;
$mockdb->{session} = $mocksession;
$mocksession->set_always( 'get_archive',$mockarchive );
$mockarchive->set_always( 'get_conf', sub { my( $sql ) = @_; $sql="\U$sql"; return $sql;} );
$mockdbh->set_always( 'prepare', $mocksth );
is( EPrints::Database::prepare( $mockdb, "some_sql" ), $mocksth, "(with callback) basic call to sub prepare" );
@args = $mockdbh->call_args( 0 );
ok( eq_array( \@args, [$mockdbh,'SOME_SQL'] ), "(with callback) passed SQL to database OK" );

