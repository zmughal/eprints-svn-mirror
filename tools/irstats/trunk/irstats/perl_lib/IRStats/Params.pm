package IRStats::Params;

use Data::Dumper;
use UNIVERSAL qw( isa );
use IRStats::Date;
use Digest::MD5 qw(md5_base64);

use strict;
use warnings;


my $defaults = 
{
	eprints         =>    'all',
	view            =>    'MonthlyDownloadsGraph',
};

sub new
{
	my ($class, $conf, $input_params) = @_;

	my $params = 
	{
		conf => $conf
	};

	foreach my $param (keys %{$defaults})  # load from defaults
	{
		$params->{$param} = $defaults->{$param};
	}

	#handle a cgi object
	if (ref ($input_params) eq 'CGI')
	{
		foreach my $param ($input_params->param())  # load from cgi (overwriting defaults)
		{
			$params->{$param} = $input_params->param($param);
		}
	}
	#handle a hash
	elsif (ref($input_params) eq 'HASH')
	{
		foreach my $param (keys %{$input_params})
		{
			$params->{$param} = $input_params->{$param};
		}
	}
	if (defined $params->{'end_date'})
	{
		$params->{'end_date'} =~ /([0-9]{4})([0-9]{2})([0-9]{2})/;
		$params->{'end_date'} = IRStats::Date->new({year => $1, month => $2, day => $3});
	}
	else
	{
#create default dates, then load parts that are set
		$params->{end_date} = IRStats::Date->new(); #defaults to yesterday;
		foreach my $part (qw( year month day ))
		{
			if (defined $params->{ 'end_' . $part })
			{
				$params->{'end_date'}->set($part, $params->{ 'end_' . $part });
			}
		}
	}
	$params->{'end_date'}->validate();


	if (defined $params->{'start_date'})
	{
                $params->{'start_date'} =~ /([0-9]{4})([0-9]{2})([0-9]{2})/;
		$params->{'start_date'} = IRStats::Date->new({year => $1, month => $2, day => $3});
	}
	else
	{
		#default is a one year period
		$params->{start_date} = $params->{end_date}->clone();
		$params->{start_date}->decrement('year');
		$params->{start_date}->increment('day');
		foreach my $part (qw( year month day ))
		{
			if (defined $params->{ 'start_' . $part })
			{
				$params->{'start_date'}->set($part, $params->{ 'start_' . $part });
			}
		}
	}
	$params->{'start_date'}->validate();

	#now write back to date parts params, to make sure they contain values
	foreach my $start_end ( qw( start_ end_ ) )
	{
		foreach my $part ( qw( year month day ) )
		{
			$params->{$start_end . $part} = $params->{$start_end . 'date'}->part($part);			
		}
	}


#depricated
#	if ( $params->{eprints} =~ /^top[0-9][0-9]*$/ )
#	{
#		$params->{eprints} .= '_' . $params->{start_date}->render('numerical') . '_' . $params->{end_date}->render('numerical');
#	}

	my $self = bless $params, $class;

	return $self;
}

sub mask
{
    my ($self, $params) = @_;

    my $originals = {};

    foreach my $param (keys %{$params})
    {
	{
	    $originals->{$param} = $self->{$param};
	    $self->{$param} = $params->{$param};
	}

    }
    push @{$self->{originals}}, $originals;
}

sub unmask
{
    my ($self) = @_;
    my $originals = pop @{$self->{originals}};
    foreach my $param (keys %{$originals})
    {
	$self->{$param} = $originals->{$param};
    }
}

sub get
{
	my ($self, $param_name) = @_;

	if ($param_name eq 'id') {
		return $self->create_id();
	}

	return $self->{$param_name};

}

sub create_id
{
	my ($self) = @_;
	my $hash_contents = "";
	foreach my $param (@{$self->{conf}->get_value('id_parameters')})
	{
		if( not defined $self->{$param} )
		{
			Carp::confess "Attempt to use undefined parameter: $param";
		}
		if ( ($param eq 'start_date') or ($param eq 'end_date') )
		{
			$hash_contents .= $self->{$param}->render('numerical');
		}
		else
		{
			$hash_contents .= $self->{$param};
		}
	}
        my $MD5_hash = md5_base64($hash_contents);
        $MD5_hash =~ s/[^0-9a-zA-Z]/_/g;  #this needs improving.
	return $MD5_hash;
}







1;
