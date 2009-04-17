package IRStats::CLI;

use strict;

our @COMMANDS = qw(
convert_ip_to_host
update_metadata
setup
update_table
);

use Getopt::Long;
use Pod::Usage;

sub new
{
	my( $class, %self ) = @_;
	bless \%self, $class;
}

sub handler
{
	my( $opt_repository_id, $opt_help, $opt_man, $opt_verbose, $opt_command, $opt_config, $opt_force );

	$opt_verbose = 0;

	GetOptions(
			"help" => \$opt_help,
			"man" => \$opt_man,
			"verbose+" => \$opt_verbose,
			"config=s" => \$opt_config,
			"force" => \$opt_force,
	) or pod2usage(1);

	pod2usage(-verbose => 1) if $opt_help;
	pod2usage(-verbose => 2) if $opt_man;

	$opt_repository_id = shift @ARGV or pod2usage("Missing required argument (need repository id and command)");
	$opt_command = shift @ARGV or pod2usage("Missing required argument (need repository id and command)");

#depricated	$IRStats::Configuration::FILE = $opt_config if defined $opt_config;
	my $eprints_session = EPrints::Session->new(1, $opt_repository_id);
	die "Couldn't create repository with id of $opt_repository_id\n" unless defined $eprints_session;

	my $session = IRStats->new(
		eprints_session => $eprints_session,
		verbose => $opt_verbose,
		force => $opt_force,
	);

	unless(grep { $_ eq $opt_command } @COMMANDS)
	{
		pod2usage("Invalid command [$opt_command]: available commands are\n\t".join(', ',@COMMANDS));
	}

	my $class = __PACKAGE__."::$opt_command";
	eval "use $class";
	Carp::croak $@ if $@;
	my $handler = $class->new( session => $session );
	$handler->execute;
}

1;
