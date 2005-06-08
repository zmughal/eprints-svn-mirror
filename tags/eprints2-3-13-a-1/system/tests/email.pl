#!/usr/bin/perl -w  

use Test::More tests => 8;

use TestLib;
use EPrints::Utils;
use Test::MockObject;
use strict;




#
my $mock_archive;
$mock_archive = Test::MockObject->new();
$mock_archive->set_always( 'get_conf', sub { return 1; } );

ok( EPrints::Utils::send_mail( $mock_archive, 'en','Bob Smith','cjg@ecs.soton.ac.uk','test',undef,undef),
 	"sending mail returned true on success" );


$mock_archive = Test::MockObject->new();
$mock_archive->set_true( 'log' );
$mock_archive->set_always( 'get_conf', sub { return 0; } );
ok( !EPrints::Utils::send_mail( $mock_archive, 'en','Bob Smith','cjg@ecs.soton.ac.uk','test subject',undef,undef),
 	"sending mail returned false on failure" );
my @args = $mock_archive->call_args( 2 );
$mock_archive->called_ok( 'log' );
is( $args[0], $mock_archive, "log to correct archive" );
ok( index($args[1],'Failed to send mail')!=-1, 'Failure causes warning to be logged' );
ok( index($args[1],'Bob Smith')!=-1, 'Warning mentions name' );
ok( index($args[1],'cjg@ecs.soton.ac.uk')!=-1, 'Warning mentions email' );
ok( index($args[1],'test subject')!=-1, 'Warning mentions subject' );

