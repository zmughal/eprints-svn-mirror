######################################################################
#
# EPrints::Subscription
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

B<EPrints::Subscription> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::Subscription;
@ISA = ( 'EPrints::DataObj' );
use EPrints::DataObj;

use EPrints::Database;
use EPrints::Utils;
use EPrints::Session;

### SUBS MUST BE FLAGGED AS BULK cjg

use strict;


######################################################################
=pod

=item $thing = EPrints::Subscription->get_system_field_info

undocumented

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"subid", type=>"int", required=>1 },

		{ name=>"userid", type=>"int", required=>1 },

		{ 
			name => "spec",
			type => "search",
			datasetid => "archive",
			fieldnames => "subscriptionfields"
		},

		{ name=>"frequency", type=>"set", required=>1,
			options=>["never","daily","weekly","monthly"] },

		{ name=>"mailempty", type=>"boolean", input_style=>"radio" },
	);
}

######################################################################
=pod

=item EPrints::Subscription->new( $id )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $id ) = trim_params(@_);

	return &DATABASE->get_single( 	
		&ARCHIVE->get_dataset( "subscription" ),
		$id );
}

######################################################################
=pod

=item $thing = EPrints::Subscription->new_from_data( $data )

undocumented

=cut
######################################################################

sub new_from_data
{
	my( $class, $data ) = trim_params(@_);

	my $self = {};
	bless $self, $class;

	$self->{data} = $data;
	$self->{dataset} = &ARCHIVE->get_dataset( "subscription" );
	
	return $self;
}

######################################################################
=pod

=item $thing = EPrints::Subscription->create( $userid )

undocumented

=cut
######################################################################

sub create
{
	my( $class, $userid ) = trim_params(@_);

	my $subs_ds = &ARCHIVE->get_dataset( "subscription" );
	my $id = &DATABASE->counter_next( "subscriptionid" );

	my $data = {
		subid => $id,
		userid => $userid,
		frequency => 'never',
		mailempty => "TRUE",
		spec => ''
	};

	&ARCHIVE->call( "set_subscription_defaults", $data, &SESSION );
	print STDERR "Plugin please\n";

	# Add the subscription to the database
	&DATABASE->add_record( $subs_ds, $data );

	# And return it as an object
	return EPrints::Subscription->new( $id );
}




######################################################################
=pod

=item $foo = $thing->remove

Remove the subscription.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

	my $subs_ds = &ARCHIVE->get_dataset( "subscription" );
	
	my $success = &DATABASE->remove(
		$subs_ds,
		$self->get_value( "subid" ) );

	return $success;
}


######################################################################
=pod

=item $foo = $thing->commit

undocumented

=cut
######################################################################

sub commit
{
	my( $self ) = @_;
	
	&ARCHIVE->call( "set_subscription_automatic_fields", $self );

	my $subs_ds = &ARCHIVE->get_dataset( "subscription" );
	my $success = &DATABASE->update( $subs_ds, $self->{data} );

	return $success;
}


######################################################################
=pod

=item $foo = $thing->get_user

undocumented

=cut
######################################################################

sub get_user
{
	my( $self ) = @_;

	return EPrints::User->new( $self->get_value( "userid" ) );
}


######################################################################
=pod

=item $searchexp = $thing->make_searchexp

undocumented

=cut
######################################################################

sub make_searchexp
{
	my( $self ) = @_;

	my $ds = &ARCHIVE->get_dataset( "subscription" );
	
	return $ds->get_field( 'spec' )->make_searchexp( 
		$self->get_value( 'spec' ) );
}


######################################################################
=pod

=item $thing->send_out_subscription

undocumented

=cut
######################################################################

sub send_out_subscription
{
	my( $self ) = @_;


	my $freq = $self->get_value( "frequency" );

	if( $freq eq "never" )
	{
		&ARCHIVE->log( 
			"Attempt to send out a subscription for a\n".
			"which has frequency 'never'\n" );
		return;
	}
		
	my $user = $self->get_user;

	if( !defined $user )
	{
		&ARCHIVE->log( 
			"Attempt to send out a subscription for a\n".
			"non-existant user. Subid#".$self->get_id."\n" );
		return;
	}

	my $origlangid = &SESSION->get_langid;
	
	&SESSION->change_lang( $user->get_value( "lang" ) );

	my $searchexp = $self->make_searchexp;
	# get the description before we fiddle with searchexp
 	my $searchdesc = $searchexp->render_description,

	my $datestamp_field = 
		&ARCHIVE->get_dataset( "archive" )->get_field( "datestamp" );

	if( $freq eq "daily" )
	{
		# Get the date for yesterday
		my $yesterday = EPrints::Utils::get_datestamp( 
			time - (24*60*60) );
		# Get from the last day
		$searchexp->add_field( 
			$datestamp_field,
			$yesterday."-" );
	}
	elsif( $freq eq "weekly" )
	{
		# Work out date a week ago
		my $last_week = EPrints::Utils::get_datestamp( 
			time - (7*24*60*60) );

		# Get from the last week
		$searchexp->add_field( 
			$datestamp_field,
			$last_week."-" );
	}
	elsif( $freq eq "monthly" )
	{
		# Get today's date
		my( $year, $month, $day ) = EPrints::Utils::get_date( time );
		# Substract a month		
		$month--;

		# Check for year "wrap"
		if( $month==0 )
		{
			$month = 12;
			$year--;
		}
		
		# Ensure two digits in month
		while( length $month < 2 )
		{
			$month = "0".$month;
		}
		my $last_month = $year."-".$month."-".$day;
		# Add the field searching for stuff from a month onwards
		$searchexp->add_field( 
			$datestamp_field,
			$last_month."-" );
	}

	my $url = &ARCHIVE->get_conf( "perl_url" ).  "/users/subscribe";
	my $freqphrase = &SESSION->html_phrase( "lib/subscription:".$freq );

	my $fn = sub {
		my( $dataset, $item, $info ) = @_;

		my $p = &SESSION->make_element( "p" );
		$p->appendChild( $item->render_citation );
		$info->{matches}->appendChild( $p );
		$info->{matches}->appendChild( &SESSION->make_text( $item->get_url ) );
		$info->{matches}->appendChild( &SESSION->make_element( "br" ) );
	};


	$searchexp->perform_search;
	my $mempty = $self->get_value( "mailempty" );
	$mempty = 0 unless defined $mempty;

	if( $searchexp->count > 0 || $mempty eq 'TRUE' )
	{
		my $info = {};
		$info->{matches} = &SESSION->make_doc_fragment;
		$searchexp->map( $fn, $info );

		my $mail = &SESSION->html_phrase( 
				"lib/subscription:mail",
				howoften => $freqphrase,
				n => &SESSION->make_text( $searchexp->count ),
				search => $searchdesc,
				matches => $info->{matches},
				url => &SESSION->make_text( $url ) );
		if( &SESSION->get_noise >= 2 )
		{
			print "Sending out subscription #".$self->get_id." to ".$user->get_value( "email" )."\n";
		}
		$user->mail( 
			"lib/subscription:sub_subj",
			$mail );
		EPrints::XML::dispose( $mail );
	}
	$searchexp->dispose;

	&SESSION->change_lang( $origlangid );
}


######################################################################
=pod

=item EPrints::Subscription::process_set( $frequency );

undocumented

=cut
######################################################################

sub process_set
{
	my( $frequency ) = trim_params(@_);

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		&ARCHIVE->log( "EPrints::Subscription::process_set called with unknown frequency: ".$frequency );
		return;
	}

	my $subs_ds = &ARCHIVE->get_dataset( "subscription" );

	my $searchexp = EPrints::SearchExpression->new( dataset => $subs_ds );

	$searchexp->add_field( $subs_ds->get_field( "frequency" ), $frequency );

	my $fn = sub {
		my( $dataset, $item, $info ) = @_;

		$item->send_out_subscription;
	};

	$searchexp->perform_search;
	$searchexp->map( $fn, {} );
	$searchexp->dispose;

	my $statusfile = &ARCHIVE->get_conf( "variables_path" ).
		"/subscription-".$frequency.".timestamp";

	unless( open( TIMESTAMP, ">$statusfile" ) )
	{
		&ARCHIVE->log( "EPrints::Subscription::process_set failed to open\n$statusfile\nfor writing." );
	}
	else
	{
		print TIMESTAMP <<END;
# This file is automatically generated to indicate the last time
# this archive successfully completed sending the *$frequency* 
# subscriptions. It should not be edited.
END
		print TIMESTAMP EPrints::Utils::get_timestamp()."\n";
		close TIMESTAMP;
	}
}


######################################################################
=pod

=item $timestamp = EPrints::Subscription::get_last_timestamp( $frequency );

Return the timestamp of the last time this frequency of subscription was sent.

=cut
######################################################################

sub get_last_timestamp
{
	my( $frequency ) = trim_params(@_);

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		&ARCHIVE->log( "EPrints::Subscription::get_last_timestamp called with unknown\nfrequency: ".$frequency );
		return;
	}

	my $statusfile = &ARCHIVE->get_conf( "variables_path" ).
		"/subscription-".$frequency.".timestamp";

	unless( open( TIMESTAMP, $statusfile ) )
	{
		# can't open file. Either an error or file does not exist
		# either way, return undef.
		return;
	}

	my $timestamp = undef;
	while(<TIMESTAMP>)
	{
		next if m/^\s*#/;	
		next if m/^\s*$/;	
		chomp;
		$timestamp = $_;
		last;
	}
	close TIMESTAMP;

	return $timestamp;
}



=pod

=back

=cut

1;
