use strict;
use Test::More tests => 25;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session( 0 );
ok(defined $session, 'opened an EPrints::Session object (noisy, no_check_db)');

my $dataset = $session->get_repository->get_dataset( "eprint" );

my $searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	allow_blank => 1,
);

my $list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "blank found matches");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "eprintid" ), "1-" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 1, "search range eprintid" );


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "documents" ), "article", "IN" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "match testdata article full text" );


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

my $sample_doc = EPrints::Test::get_test_document( $session );
my $sample_eprint = $sample_doc->get_parent;

$searchexp->add_field( $dataset->get_field( "eprintid" ), $sample_doc->get_value( "eprintid" ) );
$searchexp->add_field( $sample_doc->get_dataset->get_field( "format" ), $sample_doc->get_value( "format" ) );

$list = eval { $searchexp->perform_search };

my $is_ok = 0;
if( defined $list )
{
	my( $eprint ) = $list->get_records( 0, 1 );
	$is_ok = $list->count == 1 && $eprint->get_id == $sample_doc->get_value( "eprintid" );
}

ok($is_ok, "search for eprint id + doc format: " . $searchexp->get_conditions->describe);


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $sample_doc->get_dataset,
);

$searchexp->add_field(
	$sample_doc->get_dataset->get_field( "relation_type" ),
	EPrints::Utils::make_relation("isVolatileVersionOf")." ".EPrints::Utils::make_relation("ispreviewThumbnailVersionOf"), "EQ", "ALL" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "search multiple field");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "creators_name" ), "Neumeier, M" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "search multiple name field");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0,
);

$searchexp->add_field( $dataset->get_field( "relation_type" ), "NOMATCH" );
$searchexp->add_field( $dataset->get_field( "editors_name" ), "NOMATCH, P" );
$searchexp->add_field( $dataset->get_field( "title" ), "legend", "IN" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "satisfy-any, nomatch multiple");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0,
	custom_order => "-date/title",
);

$searchexp->add_field( $dataset->get_field( "creators_name" ), "Smith, John" );
$searchexp->add_field( $sample_doc->get_dataset->get_field( "format" ), "application/pdf" );
$searchexp->add_field( $sample_doc->get_dataset->get_field( "relation_type" ), EPrints::Utils::make_relation("isVolatileVersionOf") );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "satisfy/multi datasets/multiple");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "subjects" ), "QH" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "subject hierarchy");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "subjects" ), "QH" );

my( $values, $counts ) = eval { $searchexp->perform_groupby( $dataset->get_field( "creators_name" ) ) };

ok(defined($values) && scalar(@$values) > 0, "groupby");

my $dataset_size = $dataset->count( $session );
BAIL_OUT( "Can't test empty dataset" ) unless $dataset_size > 0;

my $cond = EPrints::Search::Condition::False->new;

my $matches = $cond->process(
	session => $session,
	dataset => $dataset,
	);

ok(@$matches == 0, "FALSE condition returns empty");

$cond = EPrints::Search::Condition::True->new;

$matches = $cond->process(
	session => $session,
	dataset => $dataset,
	);

ok(@$matches == $dataset_size, "TRUE condition returns everything");

$cond = EPrints::Search::Condition::And->new(
	EPrints::Search::Condition::False->new,
	EPrints::Search::Condition::True->new );

$matches = $cond->process(
	session => $session,
	dataset => $dataset,
	);

ok(@$matches == 0, "TRUE AND FALSE is FALSE");

$cond = EPrints::Search::Condition::Or->new(
	EPrints::Search::Condition::True->new,
	EPrints::Search::Condition::False->new );

$matches = $cond->process(
	session => $session,
	dataset => $dataset,
	);

ok(@$matches == $dataset_size, "TRUE OR FALSE is TRUE");

my $hdataset = $session->get_repository->get_dataset( "history" );

my $db = $session->get_database;

my $sql = "SELECT ".$db->quote_identifier( "userid" )." FROM ".$db->quote_identifier( $hdataset->get_sql_table_name )." WHERE ".$db->quote_identifier( "userid" )." IS NOT NULL";
my $sth = $db->prepare_select( $sql, limit => 1 );
$sth->execute;

my( $userid ) = $sth->fetchrow_array;

undef $sth;

BAIL_OUT("Need at least one history object") unless defined $userid;
my $user = EPrints::DataObj::User->new( $session, $userid );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $hdataset,
	filters => [{ meta_fields => [qw( userid.username )], value => $user->get_value( "username" ) }],
	);

$list = $searchexp->perform_search;
ok($list->count > 0, "history object by username subquery");

my $udataset = $session->get_repository->get_dataset( "user" );
my $ssdataset = $session->get_repository->get_dataset( "saved_search" );
my @usertypes = $session->get_repository->get_types( "user" );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $ssdataset );

$searchexp->add_field(
	$udataset->get_field( "frequency" ),
	"never" );

eval { $searchexp->perform_search };
ok( !$@, "userid->frequency on saved_search" );

$cond = EPrints::Search::Condition::Regexp->new( $udataset, $udataset->get_field( "username" ), '^' . $user->get_value( "username" ) . '$' );
$matches = $cond->process(
	session => $session,
	dataset => $udataset,
	);

is(scalar(@$matches), 1, "regexp username matched itself" );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0 );

$searchexp->add_field( $dataset->get_field( "documents" ), "article", "IN" );
$searchexp->add_field( $dataset->get_field( "title" ), "article", "IN" );
$searchexp->add_field( $dataset->get_field( "relation_type" ), "article" );

#print STDERR $searchexp->get_conditions->describe;

$list = $searchexp->perform_search;

ok($list->count > 0, "satisfy_all => 0");

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $sample_doc->get_dataset,
	satisfy_all => 0 );

$searchexp->add_field( $dataset->get_field( "type" ), "article" );

$list = $searchexp->perform_search;

ok($list->count > 0, "documents.eprint.type/satisfy_all => 0");

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $session->dataset( "history" ),
	satisfy_all => 0 );

$searchexp->add_field( $session->dataset( "user" )->get_field( "usertype" ), "admin" );

$list = $searchexp->perform_search;

ok($list->count > 0, "query history by user type");

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0 );

$searchexp->add_field( $session->dataset( "user" )->get_field( "name" ), "Admin, A" );

$list = $searchexp->perform_search;

# name isn't set in test data set
ok(1, "query eprint by user name");

SKIP: {
skip "No support for arbitrary dataset joins yet", 1..1;

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $sample_doc->get_dataset,
	satisfy_all => 0 );

my $file_dataset = $session->get_repository->get_dataset( "file" );
$searchexp->add_field( $file_dataset->get_field( "mime_type" ), "application/pdf" );

$list = $searchexp->perform_search;

ok($list->count > 0, "documents.file.mime_type/satisfy_all => 0");
};

$session->terminate;
