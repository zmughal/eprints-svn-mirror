######################################################################
#
# EPrints::MetaField::Time;
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Time> - no description

=head1 DESCRIPTION

not done

=over 4

=cut


package EPrints::MetaField::Time;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Date );
}

use EPrints::MetaField::Date;

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return $self->get_sql_name()." DATETIME".($notnull?" NOT NULL":"").", ".$self->get_sql_name()."_resolution INTEGER";
}

sub render_single_value
{
	my( $self, $session, $value, %render_opts ) = @_;

	$self->copy_in_render_opts( \%render_opts );

	my $res = $render_opts{res};

	my $l = 19;
	if( $res eq "minute" ) { $l = 16; }
	if( $res eq "hour" ) { $l = 13; }
	if( $res eq "day" ) { $l = 10; }
	if( $res eq "month" ) { $l = 7; }
	if( $res eq "year" ) { $l = 4; }
		
	return EPrints::Utils::render_date( $session, substr( $value,0,$l ) );
}
	

sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff, $obj ) = @_;

	my $frag = $session->make_doc_fragment;
		
	my $min_res = $self->get_property( "min_resolution" );
	
	my $div;

	if( defined $min_res && $min_res ne "second" )
	{	
		$div = $session->make_element( "div", class=>"formfieldhelp" );	
		$div->appendChild( $session->html_phrase( 
			"lib/metafield:date_res_".$min_res ) );
		$frag->appendChild( $div );
	}

	$div = $session->make_element( "div" );
	my( $hour,$minute,$second,$year, $month, $day ) = ("", "", "","","","");
	if( defined $value && $value ne "" )
	{
		($year, $month, $day, $hour,$minute,$second) = split /[-: ]/, $value;
		$month = "00" if( !defined $month || $month == 0 );
		$day = "00" if( !defined $day || $day == 0 );
		$year = "" if( !defined $year || $year == 0 );
		$hour = "" if( !defined $hour || $hour == 0 );
		$minute = "" if( !defined $minute || $minute == 0 );
		$second = "" if( !defined $second || $second == 0 );
	}
 	my $dayid = $self->{name}.$suffix."_day";
 	my $monthid = $self->{name}.$suffix."_month";
 	my $yearid = $self->{name}.$suffix."_year";
 	my $hourid = $self->{name}.$suffix."_hour";
 	my $minuteid = $self->{name}.$suffix."_minute";
 	my $secondid = $self->{name}.$suffix."_second";

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:year" ) );
	$div->appendChild( $session->make_text(" ") );

	$div->appendChild( $session->make_element(
		"input",
		"accept-charset" => "utf-8",
		name => $yearid,
		value => $year,
		size => 4,
		maxlength => 4 ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:month" ) );
	$div->appendChild( $session->make_text(" ") );
	$div->appendChild( $session->render_option_list(
		name => $monthid,
		values => \@EPrints::MetaField::Date::MONTHKEYS,
		default => $month,
		labels => $self->_month_names( $session ) ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:day" ) );
	$div->appendChild( $session->make_text(" ") );

	my @daykeys = ();
	my %daylabels = ();
	for( 0..31 )
	{
		my $key = sprintf( "%02d", $_ );
		push @daykeys, $key;
		$daylabels{$key} = ($_==0?"?":$key);
	}
	$div->appendChild( $session->render_option_list(
		name => $dayid,
		values => \@daykeys,
		default => $day,
		labels => \%daylabels ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:hour" ) );
	$div->appendChild( $session->make_text(" ") );

	my @hourkeys = ( "" );
	my %hourlabels = ( ""=>"?" );
	for( 0..23 )
	{
		my $key = sprintf( "%02d", $_ );
		push @hourkeys, $key;
		$hourlabels{$key} = $key;
	}
	$div->appendChild( $session->render_option_list(
		name => $hourid,
		values => \@hourkeys,
		default => $hour,
		labels => \%hourlabels ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:minute" ) );
	$div->appendChild( $session->make_text(" ") );

	my @minutekeys = ( "" );
	my %minutelabels = ( ""=>"?" );
	for( 0..59 )
	{
		my $key = sprintf( "%02d", $_ );
		push @minutekeys, $key;
		$minutelabels{$key} = $key;
	}
	$div->appendChild( $session->render_option_list(
		name => $minuteid,
		values => \@minutekeys,
		default => $minute,
		labels => \%minutelabels ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:second" ) );
	$div->appendChild( $session->make_text(" ") );

	my @secondkeys = ( "" );
	my %secondlabels = ( ""=>"?" );
	for( 0..59 )
	{
		my $key = sprintf( "%02d", $_ );
		push @secondkeys, $key;
		$secondlabels{$key} = $key;
	}
	$div->appendChild( $session->render_option_list(
		name => $secondid,
		values => \@secondkeys,
		default => $second,
		labels => \%secondlabels ) );

	##############################################
	##############################################




	$frag->appendChild( $div );
	
	return [ [ { el=>$frag } ] ];
}

sub form_value_basic
{
	my( $self, $session, $suffix ) = @_;
	
	my $day = $session->param( $self->{name}.$suffix."_day" );
	my $month = $session->param( $self->{name}.$suffix."_month" );
	my $year = $session->param( $self->{name}.$suffix."_year" );
	$month = undef if( !EPrints::Utils::is_set($month) || $month == 0 );
	$year = undef if( !EPrints::Utils::is_set($year) || $year == 0 );
	$day = undef if( !EPrints::Utils::is_set($day) || $day == 0 );
	my $second = $session->param( $self->{name}.$suffix."_second" );
	my $minute = $session->param( $self->{name}.$suffix."_minute" );
	my $hour = $session->param( $self->{name}.$suffix."_hour" );
	$second = undef if( !EPrints::Utils::is_set($second) || $second eq "" );
	$minute = undef if( !EPrints::Utils::is_set($minute) || $minute eq "" );
	$hour = undef if( !EPrints::Utils::is_set($hour) || $hour eq "" );

	my $r = undef;
	return $r if( !defined $year );
	$r .= sprintf( "%04d", $year );
	return $r if( !defined $month );
	$r .= sprintf( "-%02d", $month );
	return $r if( !defined $day );
	$r .= sprintf( "-%02d", $day );
	return $r if( !defined $hour );
	$r .= sprintf( " %02d", $hour );
	return $r if( !defined $minute );
	$r .= sprintf( ":%02d", $minute );
	return $r if( !defined $second );
	$r .= sprintf( ":%02d", $second );
	return $r;
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %render_opts ) = @_;

	my $values = $session->get_db()->get_values( $self, $dataset );

	$self->copy_in_render_opts( \%render_opts );

	my $res = $render_opts{res};

	if( $res eq "day" )
	{
		return $values;
	}

	my $l = 19;
	if( $res eq "minute" ) { $l = 16; }
	if( $res eq "hour" ) { $l = 13; }
	if( $res eq "day" ) { $l = 10; }
	if( $res eq "month" ) { $l = 7; }
	if( $res eq "year" ) { $l = 4; }
		
	my %ov = ();
	foreach my $value ( @{$values} )
	{
		if( !defined $value )
		{
			$ov{undef} = 1;
			next;
		}
		$ov{substr($value,0,$l)}=1;
	}
	my @outvalues = keys %ov;
	return \@outvalues;
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	return EPrints::Utils::render_date( $session, $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{min_resolution} = "second";
	$defaults{render_opts}->{res} = "second";
	return %defaults;
}

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	return $value;
}



######################################################################
1;
