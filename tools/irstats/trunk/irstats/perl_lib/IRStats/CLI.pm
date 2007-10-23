package IRStats::CLI;

use strict;

use Getopt::Long;
use Pod::Usage;

sub new
{
	my( $class, %self ) = @_;
	bless \%self, $class;
}

sub handler
{
	my( $opt_help, $opt_man, $opt_verbose, $opt_command, $opt_config );

	$opt_verbose = 0;

	GetOptions(
			"help" => \$opt_help,
			"man" => \$opt_man,
			"verbose+" => \$opt_verbose,
			"config" => \$opt_config,
	) or pod2usage(1);

	pod2usage(-verbose => 1) if $opt_help;
	pod2usage(-verbose => 2) if $opt_man;

	$opt_command = shift @ARGV or pod2usage("Missing required COMMAND argument");

	$IRStats::Configuration::FILE = $opt_config if defined $opt_config;

	my $session = IRStats->new(
		verbose => $opt_verbose,
	);

	my $class = "IRStats::CLI::$opt_command";

	eval "use $class";
	pod2usage("Invalid command [$opt_command]: $@") if $@;

	my $handler = $class->new( session => $session );
	$handler->execute;
}

1;
