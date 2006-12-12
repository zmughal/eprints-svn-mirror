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

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	# ignoring notnull.

	return 
		$self->get_sql_name()."_year SMALLINT, ".
		$self->get_sql_name()."_month SMALLINT, ".
		$self->get_sql_name()."_day SMALLINT";
}

sub get_sql_index
{
	my( $self ) = @_;

	return undef unless( $self->get_property( "sql_index" ) );

	return "INDEX( ".
		$self->get_sql_name()."_year, ".
		$self->get_sql_name()."_month, ".
		$self->get_sql_name()."_day )";
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	my $res = $self->{render_res};
	my $l = 10;
	$l = 7 if( defined $res && $res eq "month" );
	$l = 4 if( defined $res && $res eq "year" );

	if( $self->{render_style} eq "short" )
	{
		return EPrints::Time::render_short_date( $session, substr( $value,0,$l ) );
	}
	return EPrints::Time::render_date( $session, substr( $value,0,$l ) );
}
	
@EPrints::MetaField::Date::MONTHKEYS = ( 
	"00", "01", "02", "03", "04", "05", "06",
	"07", "08", "09", "10", "11", "12" );

sub _month_names
{
	my( $self , $session ) = @_;
	
	my $months = {};

	my $month;
	foreach $month ( @EPrints::MetaField::Date::MONTHKEYS )
	{
		$months->{$month} = EPrints::Time::get_month_label( 
			$session, 
			$month );
	}

	return $months;
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	my( $frag, $div, $yearid, $monthid, $dayid );

	$frag = $session->make_doc_fragment;
		
	my $min_res = $self->get_property( "min_resolution" );
	
	if( $min_res eq "month" || $min_res eq "year" )
	{	
		$div = $session->make_element( "div", class=>"ep_form_field_help" );	
		$div->appendChild( $session->html_phrase( 
			"lib/metafield:date_res_".$min_res ) );
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
 	$dayid = $basename."_day";
 	$monthid = $basename."_month";
 	$yearid = $basename."_year";

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:year" ) );
	$div->appendChild( $session->make_text(" ") );

	$div->appendChild( $session->render_noenter_input_field(
		class=>"ep_form_text",
		name => $yearid,
		id => $yearid,
		value => $year,
		size => 4,
		maxlength => 4 ) );

	$div->appendChild( $session->make_text(" ") );

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:month" ) );
	$div->appendChild( $session->make_text(" ") );
	$div->appendChild( $session->render_option_list(
		name => $monthid,
		id => $monthid,
		values => \@EPrints::MetaField::Date::MONTHKEYS,
		default => $month,
		labels => $self->_month_names( $session ) ) );

	$div->appendChild( $session->make_text(" ") );

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
		id => $dayid,
		values => \@daykeys,
		default => $day,
		labels => \%daylabels ) );

	$frag->appendChild( $div );
	
	return [ [ { el=>$frag } ] ];
}

sub get_basic_input_ids
{
	my( $self, $session, $basename, $staff, $obj ) = @_;

	return( $basename."_day", $basename."_month", $basename."_year" );
}

sub form_value_basic
{
	my( $self, $session, $basename ) = @_;
	
	my $day = $session->param( $basename."_day" );
	my $month = $session->param( 
				$basename."_month" );
	my $year = $session->param( $basename."_year" );
	$month = undef if( !EPrints::Utils::is_set($month) || $month == 0 );
	$year = undef if( !EPrints::Utils::is_set($year) || $year == 0 );
	$day = undef if( !EPrints::Utils::is_set($day) || $day == 0 );
	my $r = undef;
	return $r if( !defined $year );
	$r .= sprintf( "%04d", $year );
	return $r if( !defined $month );
	$r .= sprintf( "-%02d", $month );
	return $r if( !defined $day );
	$r .= sprintf( "-%02d", $day );
	return $r;
}


sub get_unsorted_values
{
	my( $self, $session, $dataset ) = @_;

	my $values = $session->get_database->get_values( $self, $dataset );

	my $res = $self->{render_res};

	if( $res eq "day" )
	{
		return $values;
	}

	my $l = 10;
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

	return EPrints::Time::render_date( $session, $value );
}

sub render_search_input
{
	my( $self, $session, $searchfield ) = @_;
	
	return $session->render_input_field(
				class => "ep_form_text",
				type => "text",
				name => $searchfield->get_form_prefix,
				value => $searchfield->get_value,
				size => 21,
				maxlength => 21 );
}


sub from_search_form
{
	my( $self, $session, $basename ) = @_;

	my $val = $session->param( $basename );
	return unless defined $val;

	my $drange = $val;
	$drange =~ s/-(\d\d\d\d(-\d\d(-\d\d)?)?)$/-/;
	$drange =~ s/^(\d\d\d\d(-\d\d(-\d\d)?)?)(-?)$/$4/;

	if( $drange eq "" || $drange eq "-" )
	{
		return( $val );
	}
			
	return( undef,undef,undef, $session->html_phrase( "lib/searchfield:date_err" ) );
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
			from => EPrints::Time::render_date( 
					$session, 
					$firstdate ),
			to => EPrints::Time::render_date( 
					$session, 
					$lastdate ) );
	}

	if( defined $lastdate )
	{
		return $session->html_phrase(
			"lib/searchfield:desc_date_orless",
			to => EPrints::Time::render_date( 
					$session,
					$lastdate ) );
	}

	if( defined $firstdate && $drange eq "-" )
	{
		return $session->html_phrase(
			"lib/searchfield:desc_date_ormore",
			from => EPrints::Time::render_date( 
					$session,
					$firstdate ) );
	}
	
	return EPrints::Time::render_date( $session, $value );
}

# overridden, date searches being EX means that 2000 won't match 
# 2000-02-21
sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	return $self->get_search_conditions_not_ex(
			$session, 
			$dataset, 
			$search_value, 
			$match, 
			$merge, 
			$search_mode );
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
		return EPrints::Search::Condition->new( 'FALSE' );
	}

	# not a range.
	if( $drange ne "-" )
	{
		return EPrints::Search::Condition->new( 
				'=',
				$dataset,
				$self,
				$firstdate );
	}		

	my @r = ();

	if( defined $firstdate )
	{
		push @r, EPrints::Search::Condition->new( 
				'>=',
				$dataset,
				$self,
				$firstdate);
	}

	if( defined $lastdate )
	{
		push @r, EPrints::Search::Condition->new( 
				'<=',
				$dataset,
				$self,
				$lastdate);
	}

	if( scalar @r == 0 )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}
	if( scalar @r == 1 ) { return $r[0]; }

	return EPrints::Search::Condition->new( "AND", @r );
	# error if @r is empty?
}

sub get_search_group { return 'date'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{min_resolution} = "day";
	$defaults{render_res} = "day";
	$defaults{render_style} = "long";
	$defaults{text_index} = 0;
	return %defaults;
}

sub trim_date
{
	my( $self, $date, $resolution ) = @_;

	return undef unless defined $date;

	return substr( $date, 0, 4  ) if $resolution == 1;
	return substr( $date, 0, 7  ) if $resolution == 2;
	return substr( $date, 0, 10 ) if $resolution == 3;
	return substr( $date, 0, 13 ) if $resolution == 4;
	return substr( $date, 0, 16 ) if $resolution == 5;
	return substr( $date, 0, 19 ) if $resolution == 6;

	return $date;
}

sub get_resolution
{
	my( $self, $date ) = @_;

	return 0 unless defined $date;

	my $l = length( $date );

	return 0 if $l == 0;
	return 1 if $l == 4;
	return 2 if $l == 7;
	return 3 if $l == 10;
	return 4 if $l == 13;
	return 5 if $l == 16;
	return 6;
}

sub should_reverse_order { return 1; }

######################################################################
1;
