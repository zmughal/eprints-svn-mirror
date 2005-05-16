#!/usr/bin/perl -w  

use Test::More tests => 6;

use TestLib;
use EPrints::Database;
use Test::MockObject;
use strict;











# testing get_index_ids

my $mocksth = Test::MockObject->new();
$mocksth->set_true( 'finish' );

my $mockdb = Test::MockObject->new();
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

