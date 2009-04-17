package IRStats::CLI::update_table;

use strict;
use warnings;

our @ISA = qw( IRStats::CLI );

use POSIX qw/strftime/;

use Logfile::EPrints;
use Logfile::EPrints::Filter::Robots;
use Logfile::EPrints::Filter::Repeated;

use IRStats::Update::Handler::MyHandler;
use IRStats::Update::Filter::FulltextOnly;
use IRStats::Update::Filter::NegateHandler;
use IRStats::Update::Filter::SelfReferrerFilter;
use IRStats::Update::Filter::SearchParser;

use constant LOCK_NAME => __PACKAGE__;

sub execute
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;

	my $sql;
	my $query;

	#Check existance of source tables (create if non-existant)
	$database->check_tables();

	if( $session->force )
	{
		$database->unlock_variable(LOCK_NAME);
	}
	unless( $database->lock_variable(LOCK_NAME) )
	{
		die "Can't get the exclusive update lock: perhaps the database is already being updated?\n";
	}

	# Check existant of set tables (not actually used here, but the user might forget to run import_metadata and wonder why it doesn't work)
	$database->check_set_tables();

	use IRStats::Update::Parser::Access;

#disabled for now
#	Logfile::EPrints::Hit::load_country_db( $conf->geo_ip_country_file );

	my $parser = IRStats::Update::Parser::Access->new(
				session => $session,
			handler=>Logfile::EPrints::Filter::Session->new(
			handler=>IRStats::Update::Filter::FulltextOnly->new(
				session => $session,
			handler=>IRStats::Update::Filter::NegateHandler->new(
				session => $session,
			handler=>IRStats::Update::Filter::SelfReferrerFilter->new(
				session => $session,
			handler=>Logfile::EPrints::Filter::MaxPerSession->new(
				fulltext => 20,
			handler=>Logfile::EPrints::Filter::Robots->new(
			handler=>Logfile::EPrints::Filter::Repeated->new(
				file => $conf->get_path( 'repeats_filter_file' ),
#			handler=>Logfile::EPrints::Filter::Debug->new(
			handler=>IRStats::Update::Filter::SearchParser->new(
				session => $session,
			handler=>IRStats::Update::Handler::MyHandler->new(
				session => $session,
	))))))))));

	$parser->parse;

	$session->log("Successfully Updated the Database");

	$database->unlock_variable(LOCK_NAME);

	IRStats::Cache::cleanup( $session );
}

sub utime_to_date
{
	strftime("%Y%m%d",gmtime($_[0]));
}

sub utime_to_datetime
{
	strftime("%Y%m%d%H%M%S",gmtime($_[0]));
}

1;
