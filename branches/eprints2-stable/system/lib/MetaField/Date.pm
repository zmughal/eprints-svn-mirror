######################################################################
#
# EPrints::MetaField::Date;
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

B<EPrints::MetaField::Date> - no description

=head1 DESCRIPTION

not done

=over 4

=cut


package EPrints::MetaField::Date;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Basic );
}

use EPrints::MetaField::Basic;

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return $self->get_sql_name()." DATE".($notnull?" NOT NULL":"");
}

sub render_single_value
{
	my( $self, $session, $value, $dont_link ) = @_;

	my $res = $self->get_property( "render_opts" )->{res};
	my $l = 10;
	$l = 7 if( defined $res && $res eq "M" );
	$l = 4 if( defined $res && $res eq "Y" );

	return EPrints::Utils::render_date( $session, substr( $value,0,$l ) );
}
	
my @monthkeys = ( 
	"00", "01", "02", "03", "04", "05", "06",
	"07", "08", "09", "10", "11", "12" );

sub _month_names
{
	my( $self , $session ) = @_;
	
	my $months = {};

	my $month;
	foreach $month ( @monthkeys )
	{
		$months->{$month} = EPrints::Utils::get_month_label( 
			$session, 
			$month );
	}

	return $months;
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $suffix, $staff ) = @_;

	my( $frag, $div, $yearid, $monthid, $dayid );

	$frag = $session->make_doc_fragment;
		
	my $min_res = $self->get_property( "min_resolution" );
	
	if( $min_res eq "M" || $min_res eq "Y" )
	{	
		my( %r ) = ( D=>"d", M=>"m", Y=>"y" );
		$div = $session->make_element( "div", class=>"formfieldhelp" );	
		$div->appendChild( $session->html_phrase( 
			"lib/metafield:date_res_".$r{$min_res} ) );
		$frag->appendChild( $div );
	}

	$div = $session->make_element( "div" );
	my( $year, $month, $day ) = ("", "", "");
	if( defined $value && $value ne "" )
	{
		($year, $month, $day) = split /-/, $value;
		$month = "00" if( !defined $month || $month == 0 );
		$day = "00" if( !defined $day || $day == 0 );
		$year = "" if( !defined $year || $year == 0 );
	}
 	$dayid = $self->{name}.$suffix."_day";
 	$monthid = $self->{name}.$suffix."_month";
 	$yearid = $self->{name}.$suffix."_year";

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

	$div->appendChild( $session->make_text(" ") );

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:month" ) );
	$div->appendChild( $session->make_text(" ") );
	$div->appendChild( $session->render_option_list(
		name => $monthid,
		values => \@monthkeys,
		default => $month,
		labels => $self->_month_names( $session ) ) );

	$div->appendChild( $session->make_text(" ") );

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:day" ) );
	$div->appendChild( $session->make_text(" ") );
#	$div->appendChild( $session->make_element(
#		"input",
#		"accept-charset" => "utf-8",
#		name => $dayid,
#		value => $day,
#		size => 2,
#		maxlength => 2 ) );
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

	$frag->appendChild( $div );
	
	return [ [ { el=>$frag } ] ];
}

sub form_value_basic
{
	my( $self, $session, $suffix ) = @_;
	
	my $day = $session->param( $self->{name}.$suffix."_day" );
	my $month = $session->param( 
				$self->{name}.$suffix."_month" );
	my $year = $session->param( $self->{name}.$suffix."_year" );
	$month = undef if( !defined $month || $month == 0 );
	$year = undef if( !defined $year || $year == 0 );
	$day = undef if( !defined $day || $day == 0 );
	my $res = $self->get_property( "min_resolution" );

	if( defined $year && !defined $month && !defined $day )
	{
		if( $res eq "Y" )
		{
			return sprintf( "%04d", $year );
		}
		return undef;
	}

	if( defined $year && defined $month && !defined $day )
	{
		if( $res eq "Y" || $res eq "M" )
		{
			return sprintf( "%04d-%02d", $year, $month );
		}
		return undef;
	}

	if( defined $year && defined $month && defined $day )
	{
		return sprintf( "%04d-%02d-%02d", $year, $month, $day );
	}
	
	return undef;
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $values = $session->get_db()->get_values( $self, $dataset );

	my $res = $self->get_property( "render_opts" )->{res};
	
	if( $res eq "D" )
	{
		return $values;
	}

	my $l = 10;
	if( $res eq "M" ) { $l = 7; }
	if( $res eq "Y" ) { $l = 4; }
		
	my %ov = ();
	foreach my $value ( @{$values} )
	{
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

sub render_search_input
{
	my( $self, $session, $prefix, $value, $merge ) = @_;
	
	return $session->make_element( "input",
				"accept-charset" => "utf-8",
				type => "text",
				name => $prefix,
				value => $value,
				size => 21,
				maxlength => 21 );
}


sub from_search_form
{
	my( $self, $session, $prefix ) = @_;

	my $val = $session->param( $prefix );
	return unless defined $val;

	my $drange = $val;
	$drange =~ s/-(\d\d\d\d(-\d\d(-\d\d)?)?)$/-/;
	$drange =~ s/^(\d\d\d\d(-\d\d(-\d\d)?)?)(-?)$/$4/;

	if( $drange eq "" || $drange eq "-" )
	{
		return( $val );
	}
			
	return( undef,undef,undef, $session->phrase( "lib/searchfield:date_err" ) );
}


sub render_search_value
{
	my( $self, $session, $value ) = @_;

	# still not very pretty
	my $drange = $value;
	my $lastdate;
	my $firstdate;
	if( $drange =~ s/-(\d\d\d\d(-\d\d(-\d\d)?)?)$/-/ )
	{	
		$lastdate = $1;
	}
	if( $drange =~ s/^(\d\d\d\d(-\d\d(-\d\d)?)?)(-?)$/$4/ )
	{
		$firstdate = $1;
	}

	if( defined $firstdate && defined $lastdate )
	{
		return $session->html_phrase(
			"lib/searchfield:desc_date_between",
			from => EPrints::Utils::render_date( 
					$session, 
					$firstdate ),
			to => EPrints::Utils::render_date( 
					$session, 
					$lastdate ) );
	}

	if( defined $lastdate )
	{
		return $session->html_phrase(
			"lib/searchfield:desc_date_orless",
			to => EPrints::Utils::render_date( 
					$session,
					$lastdate ) );
	}

	if( defined $firstdate && $drange eq "-" )
	{
		return $session->html_phrase(
			"lib/searchfield:desc_date_ormore",
			from => EPrints::Utils::render_date( 
					$session,
					$firstdate ) );
	}
	
	return EPrints::Utils::render_date( $session, $value );
}

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	# YYYY-MM-DD 
	# YYYY-MM-DD-
	# -YYYY-MM-DD
	# YYYY-MM-DD-YYYY-MM-DD

	my $drange = $search_value;
	my $lastdate;
	my $firstdate;
	if( $drange =~ s/-(\d\d\d\d(-\d\d(-\d\d)?)?)$/-/ )
	{	
		$lastdate = $1;
	}
	if( $drange =~ s/^(\d\d\d\d(-\d\d(-\d\d)?)?)(-?)$/$4/ )
	{
		$firstdate = $1;
	}

	if( !defined $firstdate && !defined $lastdate )
	{
		return EPrints::SearchCondition->new( 'FALSE' );
	}

	if( $drange ne "-" )
	{
		$lastdate = $firstdate;
	}		

	my @r = ();

	if( defined $firstdate )
	{
		$firstdate = EPrints::Database::pad_date( $firstdate );
		push @r, EPrints::SearchCondition->new( 
				'>=',
				$dataset,
				$self,
				$firstdate);
	}

	if( defined $lastdate )
	{
		if( length( $lastdate ) == 10 )
		{
			push @r, EPrints::SearchCondition->new( 
					'<=',
					$dataset,
					$self,
					$lastdate);
		}
		else
		{
			$lastdate = EPrints::Database::pad_date( 
					$lastdate, 
					1 );
			push @r, EPrints::SearchCondition->new( 
					'<',
					$dataset,
					$self,
					$lastdate);
		}
	}

	if( scalar @r == 0 )
	{
		return EPrints::SearchCondition->new( 'FALSE' );
	}
	if( scalar @r == 1 ) { return $r[0]; }

	return EPrints::SearchCondition->new( "AND", @r );
	# error if @r is empty?
}

sub get_search_group { return 'date'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{min_resolution} = "D";
	return %defaults;
}

######################################################################
1;
