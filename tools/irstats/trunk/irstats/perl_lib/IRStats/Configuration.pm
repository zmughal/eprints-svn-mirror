package IRStats::Configuration;

our $FILE = '/opt/irstats/cfg/irstats.cfg';

use strict;

use vars qw( $AUTOLOAD );

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
	Carp::croak "You need to define '$AUTOLOAD' in the configuration file $FILE"
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

=item $conf = IRStats::Configuration->new( [ file => FILE_NAME ] )

Create a new configuration object. If file is specified will attempt to read from FILE_NAME otherwise reads from $IRStats::Configuration::FILE.

=cut

sub new
{
	my ($class, %self) = @_;

	my $conf_file = $self{file} || $FILE;

	open my $fh, $conf_file or
		die "Couldn't open $conf_file: $!\n";

	my $lineno = 0;
	while (defined(my $config_line = <$fh>))
	{
		$lineno++;
		chomp $config_line;
		next if $config_line =~ /^\s*(?:#|$)/s;

		my( $variable, $value ) = split(/\s*=\s*/,$config_line,2);

		if( !defined $value )
		{
			die "Error in $conf_file near line $lineno: I don't know what to do with '$config_line'";
		}
		
		my @values = split /\s*,\s*/, $value;

		$self{$variable} = scalar(@values) > 1 ? \@values : $value;
	}

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
