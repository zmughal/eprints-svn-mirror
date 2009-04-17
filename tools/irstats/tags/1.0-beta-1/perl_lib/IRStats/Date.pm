package IRStats::Date;

use strict;
use warnings;
use Time::Local;
use Date::Calc qw(Delta_Days);
use Data::Dumper;

sub new
{
#defaults to yesterday's date
	my ($class, $date_hash) = @_;
	if (not defined $date_hash)
	{
		my  ($second, $minute, $hour, $day, $month, $year ) = localtime();
		my $self = bless {
			day => $day,
			month => $month+1,
			year => ($year + 1900)
		}, $class;
		$self->decrement('day');		
		return $self;
	}

	my $self =  bless {
		day => ( (defined $date_hash->{day}) ? $date_hash->{day} : 01),
		month => ( (defined $date_hash->{month}) ? $date_hash->{month} : 01),
		year => ( (defined $date_hash->{year}) ? $date_hash->{year} : 1900)
	}, $class;
	$self->validate();

	return $self;
}

sub validate
{
	my ($self) = @_;
	return if (Date::Calc::check_date($self->{year}, $self->{month}, $self->{day}));
	#date must be invalid
	if ($self->{year} < 1900)	{ $self->{year} = 1900; }
	if ($self->{month} < 1)		{ $self->{month} = 1; }
	if ($self->{month} > 12) 	{ $self->{month} = 12; }
	if ($self->{day} < 1)		{ $self->{day} = 1; }
	if ($self->{day} > 31)		{ $self->{day} = 31; }

	
	if ($self->{month} == 2)
	{
		if ($self->{day} > 28)	
		{
			if ( ($self->{year} % 4 == 0) and ($self->{year} % 100 != 0 or $self->{year} % 400 == 0) )
			{
				$self->{day} = 29;
			}
			else
			{
				$self->{day} = 28;
			}
		}
	}

	if ( ($self->{month} == 9) or ($self->{month} == 4) or ($self->{month} == 6) or ($self->{month} == 11) ) 
	#thirty days have September, April, June and November.
	{
		if ($self->{day} > 30)  { $self->{day} = 30; }
	}

}

sub set
{
	my ($self, $part, $value) = @_;
	$self->{$part} = $value;
}


sub decrement
{
	my ( $self, $period ) = @_;

        $self->mod_date( $period, -1);
}

sub increment
{
	my( $self, $period ) = @_;

	$self->mod_date( $period, 1);
}

sub part
{
	my ($self, $part, $style) = @_;
	$style = 'numeric' if (not defined $style);

	if ($part eq 'day') 
	{ 
		return $self->{day};
	}
	if ($part eq 'month')
	{ 
		if ($style eq 'text')
		{
			return $self->month_name();
		}
		return $self->{month};
	}
	if ($part eq 'year')
	{
		if ($style eq 'short')
		{
			return substr($self->{year},2,2);
		}
		return $self->{year};
	}
	die "invalid part $part\n";
}

sub mod_date
#date is in format YYYY-MM-DD HH:MM:SS
{
	my ($self, $period, $sign) = @_;
	if ($sign != -1) {$sign = 1;}

	my $t;

	my $second = 1;
	my $minute = 0;
	my $hour = 0;
	$self->{year} -= 1900;
	$self->{month} -= 1;

	if( $period eq "day" )    { $self->{'day'}+=1*$sign; }
	elsif( $period eq "week" )   { $self->{'day'}+=7*$sign; }
	elsif( $period eq "month" )  { $self->{'month'}+=1*$sign; }
	elsif( $period eq "quarter" ){ $self->{'month'}+=3*$sign; }
	elsif( $period eq "year" )   { ($self->{'year'})+=1*$sign; }
	else { $self->{'day'}+=1*$sign; }#default 

	if( $self->{'month'} > 11 ) { $self->{'month'}-=12; $self->{'year'}+=1; }
	if( $self->{'month'} < 0 ) { $self->{'month'}+=12; $self->{'year'}-=1; }

	$t = Time::Local::timelocal_nocheck( $second, $minute, $hour, $self->{'day'}, $self->{'month'}, $self->{'year'} );
	( $second, $minute, $hour, $self->{'day'}, $self->{'month'}, $self->{'year'} ) = localtime( $t );
	$self->{'year'} += 1900;
	$self->{'month'} += 1;
}

sub difference
{
#takes another date and returns the between self and new date
	my ($self, $later) = @_;   # refs to YMD arrays
	return Delta_Days ($self->part('year'),$self->part('month'),$self->part('day'),
				$later->part('year'),$later->part('month'),$later->part('day')); 
}

sub less_than 
{
	my ($self, $date) = @_;
	return ($self->render('numerical') < $date->render('numerical'));
}

sub greater_than {
	my ($self, $date) = @_;
	return ($self->render('numerical') > $date->render('numerical'));
}

sub equal_to {
	my ($self, $date) = @_;
	return ($self->render('numerical') == $date->render('numerical'));
}

sub month_name
{
	my ($self) = @_;
        my $month = 'ERR';
	if ($self->{'month'} == 1){ $month =  'Jan'; }
        elsif ($self->{'month'} == 2){ $month =  'Feb'; }
        elsif ($self->{'month'} == 3){ $month =  'Mar'; }
        elsif ($self->{'month'} == 4){ $month =  'Apr'; }
        elsif ($self->{'month'} == 5){ $month =  'May'; }
        elsif ($self->{'month'} == 6){ $month =  'Jun'; }
        elsif ($self->{'month'} == 7){ $month =  'Jul'; }
        elsif ($self->{'month'} == 8){ $month =  'Aug'; }
        elsif ($self->{'month'} == 9){ $month =  'Sep'; }
        elsif ($self->{'month'} == 10){ $month =  'Oct'; }
        elsif ($self->{'month'} == 11){ $month =  'Nov'; }
        elsif ($self->{'month'} == 12){ $month =  'Dec'; }
	return $month;
}

sub render
{
#render as short, long or numerical.
	my ($self, $format) = @_;
	if (not defined $format) {$format = '.';}
	if ($format eq 'short')
	{
		return $self->render_abbreviated;
	}
	return $self->render_numerical;

}

sub render_numerical
{
	my ($self) = @_;
	return sprintf("%04d%02d%02d",$self->{'year'}, $self->{'month'}, $self->{'day'});
}



sub render_abbreviated
{
	my ($self) = @_;
	$self->{'year'}=~ /^[0-9][0-9]([0-9][0-9])/;
	my $two_digit_year = $1;
	$self->{'day'} += 0;  #convert to int to lose leading 0

	return $self->{day} . '/' .  $self->month_name() . '/' . $two_digit_year;
}

sub clone
{
	my ($self) = @_;
	my $clone = { %{$self} }; # copy keys/values one level deep
	return bless $clone, ref $self; # copy the object class, returning $clone
}



1;

