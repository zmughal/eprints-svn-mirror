package IRStats::Configuration;


use strict;
use warnings;

use vars qw( $AUTOLOAD );

our %DEFAULTS = (
	data_path => '/tmp',
	geo_ip_country_file => '/usr/local/share/GeoIP/GeoIP.dat',
	geo_ip_org_file => '/usr/local/share/GeoIP/GeoIPOrg.dat',
);

=head1 NAME

IRStats::Configuration - read a configuration file

=head1 SYNOPSIS

	my $conf = $session->get_conf;

	my $opt = $conf->foo; # read a scalar value
	my @opts = $conf->foo; # read a list value
	my $path = $conf->get_path( 'foo' ); # read a path value

	# if value 'foo' is set and is != ''
	if( $conf->is_set( 'foo' ) )
	{
		my $opt = $conf->foo;
	}

=head1 METHODS

=over 4

=cut

=item AUTOLOAD

Calling any non-defined method on $conf will attempt to get the same-named value from the configuration. In scalar context this will return the first value given in a list.

If the requested value is not defined an error will be thrown.

=cut

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /[A-Z]$/;
	$AUTOLOAD =~ s/^.*:://;
	my $value = $_[0]->{$AUTOLOAD};
	Carp::croak "You need to define '$AUTOLOAD' in the configuration file"
		unless defined $value;
	my @values = ref($value) eq 'ARRAY' ? @$value : ($value);
	if( wantarray )
	{
		if( @values == 1 and $values[0] eq '' )
		{
			return ();
		}
		else
		{
			return @values;
		}
	}
	else
	{
		return $values[0];
	}
}

=item $conf = IRStats::Configuration->new($session, [ file => FILE_NAME ] )

Create a new configuration object. If file is specified will attempt to read from FILE_NAME otherwise reads from $IRStats::Configuration::FILE.

=cut

sub new
{
	my ($class, $session, %self) = @_;

	%self = (%DEFAULTS, %self);


	my $conf_file = $session->get_eprints_session->get_repository->get_conf('archiveroot') . '/cfg/irstats.conf';

	open my $fh, $conf_file or
		die "Couldn't open $conf_file: $!\n";

	#BAD , THIS LINE SHOULD NOT BE NEEDED, BUT IT IS SINCE SOMETHING SETS THE RS TO undef.
	local $/ = "\n";

	my $lineno = 0;
	while (defined(my $config_line = <$fh>))
	{
		$lineno++;
		chomp $config_line;
		$config_line =~ s/^\s+//;
		next if length($config_line) == 0;
		next if $config_line =~ /^#/;
#		next if $config_line =~ /^\s*(?:#|$)/s;

		my( $variable, $value ) = split(/\s*=\s*/,$config_line,2);

		if( !defined $value )
		{
			die "Error in $conf_file near line $lineno: I don't know what to do with '$config_line'";
		}
		
		my @values = split /\s*,\s*/, $value;

		$self{$variable} = scalar(@values) > 1 ? \@values : $value;
	}

#Override values from configuration with values from EPrints configuration - use the same database :)

	$self{database_server} = $session->get_eprints_session->get_repository->get_conf('dbhost');
	$self{database_name} = $session->get_eprints_session->get_repository->get_conf('dbname');
	$self{database_user} = $session->get_eprints_session->get_repository->get_conf('dbuser');
	$self{database_password} = $session->get_eprints_session->get_repository->get_conf('dbpass');
	$self{repository_type} = 'eprints3';
	$self{repository} = $session->get_eprints_session->get_repository->get_id;

	$self{root} = $session->get_eprints_session->get_repository->get_conf('archiveroot') . '/var/irstats';
	$self{cache_path} = $session->get_eprints_session->get_repository->get_conf('archiveroot') . '/var/irstats/cache';
	$self{static_path} = $session->get_eprints_session->get_repository->get_conf('archiveroot') . '/cfg/static/irstats';
	$self{view_path} = $session->get_eprints_session->get_repository->get_conf('base_path') . '/perl_lib/IRStats/View/';
	$self{data_path} = $session->get_eprints_session->get_repository->get_conf('archiveroot') . '/var/irstats/data';
	$self{static_url} = '/irstats';

	$self{dns_cache_file} = $session->get_eprints_session->get_repository->get_conf('archiveroot') . '/var/irstats/cache/dns_cache';
	$self{repeats_filter_file} = $session->get_eprints_session->get_repository->get_conf('archiveroot') . '/var/irstats/cache/repeatscache';

	$self{repository_url} = $session->get_eprints_session->get_repository->get_conf('base_url');


	close($fh);

	return bless \%self, $class;
}

=item $conf->get_value

Deprecated - use the AUTOLOAD mechanism.

=cut

sub get_value
{
	$_[0]->{$_[1]};
}

=item $conf->is_set( OPTION )

Tests whether OPTION is set and is != ''.

=cut

sub is_set
{
	exists $_[0]->{$_[1]} and length $_[0]->{$_[1]};
}

=item $conf->get_path( PATH )

Gets the value for PATH and will prefix the IRStats root if the value doesn't start with '/', which allows relative paths to be specified in the configuration file.

=cut

sub get_path
{
	my( $self, $type ) = @_;
	return $self->$type if $self->$type =~ /^\//;
	my( $path ) = $self->root;
	$path .= "/" . $self->$type;
	return $path;
}

=item $conf->to_string

Return the complete configuration as a string.

=cut

sub to_string
{
	my( $self ) = @_;

	my $str = '';
	foreach my $variable (sort keys %$self)
	{
		my @values = $self->$variable;
		$str .= "$variable = ".join(',',@values)."\n";
	}
	$str;
}

1;

__END__

=back
