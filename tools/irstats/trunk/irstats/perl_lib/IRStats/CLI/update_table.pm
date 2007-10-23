package IRStats::CLI::update_table;

use strict;
use warnings;

our @ISA = qw( IRStats::CLI );

use POSIX qw/strftime/;

use Logfile::EPrints;
use Logfile::EPrints::RobotsFilter;

use IRStats::Update::Handler::MyHandler;
use IRStats::Update::Filter::FulltextOnly;
use IRStats::Update::Filter::Institution;
use IRStats::Update::Filter::NegateHandler;
use IRStats::Update::Filter::SelfReferrerFilter;
use IRStats::Update::Filter::SearchParser;
use IRStats::Update::Filter::RepeatsFilter;

our %PARSERS = (
	eprints2 => 'Accesslog',
	eprints3 => 'Access',
	dspace => 'ApacheDSpace',
	apacheeprints => 'ApacheEPrints',
);

sub execute
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;

	my $lock_file_name =  $conf->get_path('update_lock_filename');

	my $sql;
	my $query;

	my $repository_type = $conf->repository_type;

	unless( exists $PARSERS{$repository_type} )
	{
		die "I don't know how to harvest from a repository of type '$repository_type' (did you set repository_type correctly?): must be one of ".join(', ', keys %PARSERS)."\n";
	}

	if (-e $lock_file_name) {
		die "$lock_file_name exists.  Perhaps the database is currently being updated. If you're sure it isn't, feel free to delete it.\n";
	}

	open LOCKFILE, ">$lock_file_name" or die "Error writing Lock File $lock_file_name: $!\n";

	$session->log("Using repository type [$repository_type]", 2);

	#Check existance of source tables (create if non-existant)
	$database->check_tables();

	# Check existant of set tables (not actually used here, but the user might forget to run import_metadata and wonder why it doesn't work)
	$database->check_set_tables();

	my $parser_class = "IRStats::Update::Parser::".$PARSERS{$repository_type};
	eval "use $parser_class"; Carp::confess $@ if $@;

	my $parser = $parser_class->new(
				session => $session,
			handler=>Logfile::EPrints::Filter::Session->new(
			handler=>IRStats::Update::Filter::FulltextOnly->new(
				session => $session,
			handler=>IRStats::Update::Filter::Institution->new(
				session => $session,
			handler=>IRStats::Update::Filter::NegateHandler->new(
				session => $session,
			handler=>IRStats::Update::Filter::SelfReferrerFilter->new(
				session => $session,
			handler=>Logfile::EPrints::Filter::MaxPerSession->new(
				fulltext => 20,
			handler=>Logfile::EPrints::RobotsFilter->new(
			handler=>IRStats::Update::Filter::RepeatsFilter->new(
				session => $session,
#			handler=>Logfile::EPrints::Filter::Debug->new(
			handler=>IRStats::Update::Filter::SearchParser->new(
				session => $session,
			handler=>IRStats::Update::Handler::MyHandler->new(
				session => $session,
	)))))))))));

	$parser->parse;

	$session->log("Successfully Updated the Database");

	IRStats::Cache::cleanup( $session );

	close LOCKFILE;
	unlink $lock_file_name;
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
