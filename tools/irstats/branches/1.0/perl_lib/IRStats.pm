package IRStats;

our $VERSION = 1.0;

=head1 NAME

IRStats - analyse web usage logs from document repositories

=head1 DESCRIPTION

IRStats is a collection of modules that support the processing and analysis of Web usage logs from repositories of documents. It is aimed at the users and administrators of Institutional Repositories.

=head2 This Module

This module represents a session that consists of an L<IRStats::Configuration> and an L<IRStats::DatabaseInterface> objects. This module also provides some utility methods as well as the main entry point into the program.

=head1 METHODS

=head2 Class Methods

=over 4

=cut

use strict;

use CGI;
use DBI;
use Data::Dumper;

use IRStats::Configuration;

use IRStats::CLI;
use IRStats::GUI;

use IRStats::Cache;
use IRStats::Params;
use IRStats::DatabaseInterface;
use IRStats::UserInterface;
use IRStats::UserInterface::Controls;
use IRStats::Date;

use Logfile::EPrints 1.19;

use EPrints;

=item IRStats::handler( ARGS )

IRStats may be executed from Mod_Perl as a startup script, from CGI as a CGI script or from the command-line. This method determines how the script was executed and calls the appropriate handler.

ARGS are passed to the handler.

See L<IRStats::GUI> and L<IRStats::CLI>.

=cut

sub handler
{
	# mod_perl startup
	if( exists $ENV{'MOD_PERL'} )
	{
		#return undef;
		return IRStats::GUI::handler( @_ );
	}
	# CGI
	elsif( exists $ENV{'REQUEST_METHOD'} )
	{
		return IRStats::GUI::handler( @_ );
	}
	# command-line
	else
	{
		return IRStats::CLI::handler( @_ );
	}
}

=item IRStats->new( eprints_session => EPRINTS_SESSION, [request => REQUEST] )

Create a new session object optionally with a Mod_Perl request object, REQUEST.

Must receive an EPrints session object.

=cut

sub new
{
	my( $class, %self ) = @_;
	
	my $self = bless \%self, $class;

	die "Cannot create IRStats Session without EPrints Session\n" unless defined $self->{eprints_session};

	if( exists $self->{request} )
	{
		eval "use CGI::Carp qw(warningsToBrowser fatalsToBrowser)";
		die $@ if $@;
	}
	
#depricated	if( defined($self->{request}) and
#		defined(my $conf_file = $self->{request}->dir_config( "IRStats_Config_File" )) )
#	{
#		$self->{conf} = IRStats::Configuration->new(file => $conf_file);
#	}
#	else
	{
		$self->{conf} = IRStats::Configuration->new($self);
	}
	$self->{views} = [];

	my $driver = $self->{conf}->database_driver;

	my $database_class = "IRStats::DatabaseInterface::$driver";

	eval "use $database_class;";
	die "Unable to use '$driver' as a database driver: $@" if $@;

	$self->{database} = $database_class->new(session => $self);

	return $self;
}

=pod

=back

=head2 Session Methods

=over 4

=cut

=item $s->cgi

Returns the current L<CGI> object.

=cut

sub cgi
{
	$_[0]->{cgi} ||= new CGI;
}

=item $s->verbose

Returns the current level of verbosity (0+).

=cut

sub verbose
{
	$_[0]->{verbose} || 0;
}

=item $s->force

Returns true if we should be forceful (command line option).

=cut

sub force
{
	$_[0]->{force} || 0;
}

=item $s->log( MESSAGE [, VERBOSITY ] )

Logs MESSAGE if current verbosity is greater than or equal to VERBOSITY.

=cut

sub log
{
	my( $self, $msg, $level ) = @_;
	$level ||= 1;
	return if $level > $self->verbose;
	print STDERR "$msg\n";
}

=item $s->get_eprints_session

Returns the current L<EPrints::Session> object.

=cut

sub get_eprints_session
{
	$_[0]->{eprints_session};
}

=item $s->get_conf

Returns the current L<IRStats::Configuration> object.

=cut

sub get_conf
{
	$_[0]->{conf};
}

=item $s->get_database

Returns the current L<IRStats::DatabaseInterface> object.

=cut

sub get_database
{
	$_[0]->{database};
}

=item $s->get_views

Returns a list of the currently available views. Prefix 'IRStats::View::' to get the class name.

See also L<IRStats::View>.

=cut

sub get_views
{
	my( $self ) = @_;

	return @{$self->{views}} if scalar @{$self->{views}};

	my $view_dir = $self->get_conf->get_path( "view_path" );
	opendir(my $dir, $view_dir)
		or Carp::confess "Unable to open $view_dir: $!";
	my @view_files = grep { /\.pm$/ } readdir( $dir );
	closedir($dir);

	for(@view_files)
	{
		eval "require '$view_dir/$_'";
		Carp::confess "Failed to load view $view_dir/$_: $@\n" if $@;
		push @{$self->{views}}, substr($_,0,-3);
	}

	return @{$self->{views}};
}

=item $s->get_phrase( PHRASE_ID )

Returns the phrase identified by PHRASE_ID from the database.

=cut

sub get_phrase
{
	my( $self, $phrase ) = @_;

	return $self->get_database->get_phrase( $phrase );
}

1;

__END__

=back

=head1 SEE ALSO

=head1 COPYRIGHT

Please see the LICENSE file included with the distribution.

Developed by the Interoperable Repository Statistics project http://irs.eprints.org/, funded as part of the JISC Digital Repositories programme, see http://www.jisc.ac.uk/.

=head1 AUTHOR

Copyright 2007 University of Southampton, UK.

Timothy D Brody, Christopher Gutteridge, Leslie Carr, Adam Field.
