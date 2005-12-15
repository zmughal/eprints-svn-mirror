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
#cjg use EPrints::MetaField;
#cjg use EPrints::SearchExpression;
#cjg use EPrints::Session;
#cjg use EPrints::User;

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

		{ name=>"rev_number", type=>"int", required=>1 },

		{ name=>"userid", type=>"itemref", 
			datasetid=>"user", required=>1 },

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

=item EPrints::Subscription->new( $session, $id )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $session, $id ) = @_;

	return $session->get_db()->get_single( 	
		$session->get_archive()->get_dataset( "subscription" ),
		$id );
}

######################################################################
=pod

=item $thing = EPrints::Subscription->new_from_data( $session, $data )

undocumented

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{data} = $data;
	$self->{dataset} = $session->get_archive()->get_dataset( 
		"subscription" );
	$self->{session} = $session;
	
	return $self;
}

######################################################################
=pod

=item $thing = EPrints::Subscription->create( $session, $userid )

undocumented

=cut
######################################################################

sub create
{
	my( $class, $session, $userid ) = @_;

	my $subs_ds = $session->get_archive()->get_dataset( "subscription" );
	my $id = $session->get_db()->counter_next( "subscriptionid" );

	my $data = {
		subid => $id,
		userid => $userid,
		frequency => 'never',
		mailempty => "TRUE",
		spec => ''
	};

	$session->get_archive()->call(
		"set_subscription_defaults",
		$data,
		$session );

	# Add the subscription to the database
	$session->get_db()->add_record( $subs_ds, $data );

	my $subs = EPrints::Subscription->new( $session, $id );
	$subs->queue_all;
	# And return it as an object
	return $subs;
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

	my $subs_ds = $self->{session}->get_archive()->get_dataset( 
		"subscription" );
	
	my $success = $self->{session}->get_db()->remove(
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
	my( $self, $force ) = @_;
	
	$self->{session}->get_archive()->call( 
		"set_subscription_automatic_fields", 
		$self );

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	

	my $subs_ds = $self->{session}->get_archive()->get_dataset( 
		"subscription" );
	my $success = $self->{session}->get_db()->update(
		$subs_ds,
		$self->{data} );

	$self->queue_changes;

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

	return EPrints::User->new( 
		$self->{session},
		$self->get_value( "userid" ) );
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

	my $ds = $self->{session}->get_archive()->get_dataset( 
		"subscription" );
	
	return $ds->get_field( 'spec' )->make_searchexp( 
		$self->{session},
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
		$self->{session}->get_archive->log( 
			"Attempt to send out a subscription for a\n".
			"which has frequency 'never'\n" );
		return;
	}
		
	my $user = $self->get_user;

	if( !defined $user )
	{
		$self->{session}->get_archive->log( 
			"Attempt to send out a subscription for a\n".
			"non-existant user. Subid#".$self->get_id."\n" );
		return;
	}

	my $origlangid = $self->{session}->get_langid;
	
	$self->{session}->change_lang( $user->get_value( "lang" ) );

	my $searchexp = $self->make_searchexp;
	# get the description before we fiddle with searchexp
 	my $searchdesc = $searchexp->render_description,

	my $datestamp_field = $self->{session}->get_archive()->get_dataset( 
		"archive" )->get_field( "datestamp" );

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

	my $url = $self->{session}->get_archive->get_conf( "perl_url" ).
		"/users/subscribe";
	my $freqphrase = $self->{session}->html_phrase(
		"lib/subscription:".$freq );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		my $p = $session->make_element( "p" );
		$p->appendChild( $item->render_citation );
		$info->{matches}->appendChild( $p );
		$info->{matches}->appendChild( $session->make_text( $item->get_url ) );
		$info->{matches}->appendChild( $session->make_element( "br" ) );
	};


	$searchexp->perform_search;
	my $mempty = $self->get_value( "mailempty" );
	$mempty = 0 unless defined $mempty;

	if( $searchexp->count > 0 || $mempty eq 'TRUE' )
	{
		my $info = {};
		$info->{matches} = $self->{session}->make_doc_fragment;
		$searchexp->map( $fn, $info );

		my $mail = $self->{session}->html_phrase( 
				"lib/subscription:mail",
				howoften => $freqphrase,
				n => $self->{session}->make_text( $searchexp->count ),
				search => $searchdesc,
				matches => $info->{matches},
				url => $self->{session}->make_text( $url ) );
		if( $self->{session}->get_noise >= 2 )
		{
			print "Sending out subscription #".$self->get_id." to ".$user->get_value( "email" )."\n";
		}
		$user->mail( 
			"lib/subscription:sub_subj",
			$mail );
		EPrints::XML::dispose( $mail );
	}
	$searchexp->dispose;

	$self->{session}->change_lang( $origlangid );
}


######################################################################
=pod

=item EPrints::Subscription::process_set( $session, $frequency );

undocumented

=cut
######################################################################

sub process_set
{
	my( $session, $frequency ) = @_;

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		$session->get_archive->log( "EPrints::Subscription::process_set called with unknown frequency: ".$frequency );
		return;
	}

	my $subs_ds = $session->get_archive->get_dataset( "subscription" );

	my $searchexp = EPrints::SearchExpression->new(
		session => $session,
		dataset => $subs_ds );

	$searchexp->add_field(
		$subs_ds->get_field( "frequency" ),
		$frequency );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		$item->send_out_subscription;
	};

	$searchexp->perform_search;
	$searchexp->map( $fn, {} );
	$searchexp->dispose;

	my $statusfile = $session->get_archive->get_conf( "variables_path" ).
		"/subscription-".$frequency.".timestamp";

	unless( open( TIMESTAMP, ">$statusfile" ) )
	{
		$session->get_archive->log( "EPrints::Subscription::process_set failed to open\n$statusfile\nfor writing." );
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

=item $timestamp = EPrints::Subscription::get_last_timestamp( $session, $frequency );

Return the timestamp of the last time this frequency of subscription was sent.

=cut
######################################################################

sub get_last_timestamp
{
	my( $session, $frequency ) = @_;

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		$session->get_archive->log( "EPrints::Subscription::get_last_timestamp called with unknown\nfrequency: ".$frequency );
		return;
	}

	my $statusfile = $session->get_archive->get_conf( "variables_path" ).
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
