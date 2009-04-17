package IRStats::CLI::setup;

=head1 NAME

IRStats::CLI::setup - creates necessary directories and database tables

=cut

our @ISA = qw( IRStats::CLI );

use Data::Dumper;
use File::Path;
require LWP::UserAgent;

our $USER_AGENT = LWP::UserAgent->new;

use strict;

sub execute
{
	my( $self ) = @_;
	
	my $session = $self->{session};

	foreach (qw/cache_path static_path data_path/)
	{
		mkpath $session->get_conf->$_ unless (-d $session->get_conf->$_);
	}


}


1;
