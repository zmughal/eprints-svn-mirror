######################################################################
#
# EPrints::DataObj::Subscription
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

B<EPrints::DataObj::Subscription> - Single saved search.

=head1 DESCRIPTION

A subscription is a sub class of EPrints::DataObj.

Each on belongs to one and only one user, although one user may own
multiple subscriptions.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::DataObj::Subscription;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;


######################################################################
=pod

=item $subscription = EPrints::DataObj::Subscription->get_system_field_info

Return an array describing the system metadata of the Subscription
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"subid", type=>"int", required=>1 },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

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

=item $subscription = EPrints::DataObj::Subscription->new( $session, $id )

Return new subscription object, created by loading the subscription
with id $id from the database.

=cut
######################################################################

sub new
{
	my( $class, $session, $id ) = @_;

	return $session->get_db()->get_single( 	
		$session->get_repository->get_dataset( "subscription" ),
		$id );
}

######################################################################
=pod

=item $subscription = EPrints::DataObj::Subscription->new_from_data( $session, $data )

Construct a new EPrints::DataObj::Subscription object based on the $data hash 
reference of metadata.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{data} = $data;
	$self->{dataset} = $session->get_repository->get_dataset( 
		"subscription" );
	$self->{session} = $session;
	
	return $self;
}

######################################################################
=pod

=item $subscription = EPrints::DataObj::Subscription->create( $session, $userid )

Create a new Subsciption entry in the database, belonging to user
with id $userid.

=cut
######################################################################

sub create
{
	my( $class, $session, $userid ) = @_;


	return EPrints::DataObj::Subscription->create_from_data( 
		$session, 
		{ userid=>$userid },
		$session->get_repository->get_dataset( "subscription" ) );
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::Subscription->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	my $id = $session->get_db->counter_next( "subscriptionid" );

	$data->{subid} = $id;
	$data->{frequency} = 'never';
	$data->{mailempty} = "TRUE";
	$data->{spec} = '';
	$data->{rev_number} = 1;

	$session->get_repository->call(
		"set_subscription_defaults",
		$data,
		$session );

	return $data;
}	


######################################################################
=pod

=item $success = $subscription->remove

Remove the subscription.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

	my $subs_ds = $self->{session}->get_repository->get_dataset( 
		"subscription" );
	
	my $success = $self->{session}->get_db()->remove(
		$subs_ds,
		$self->get_value( "subid" ) );

	return $success;
}


######################################################################
=pod

=item $success = $subscription->commit( [$force] )

Write this object to the database.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;
	
	$self->{session}->get_repository->call( 
		"set_subscription_automatic_fields", 
		$self );

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	

	my $subs_ds = $self->{session}->get_repository->get_dataset( 
		"subscription" );
	my $success = $self->{session}->get_db()->update(
		$subs_ds,
		$self->{data} );

	$self->queue_changes;

	return $success;
}


######################################################################
=pod

=item $user = $subscription->get_user

Return the EPrints::User which owns this subscription.

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

=item $searchexp = $subscription->make_searchexp

Return a EPrints::SearchExpression describing how to find the eprints
which are in the scope of this subscription.

=cut
######################################################################

sub make_searchexp
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset( 
		"subscription" );
	
	return $ds->get_field( 'spec' )->make_searchexp( 
		$self->{session},
		$self->get_value( 'spec' ) );
}


######################################################################
=pod

=item $subscription->send_out_subscription

Send out an email for this subcription. If there are no matching new
items then an email is only sent if the subscription has mailempty
set to true.

=cut
######################################################################

sub send_out_subscription
{
	my( $self ) = @_;

	my $freq = $self->get_value( "frequency" );

	if( $freq eq "never" )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out a subscription for a\n".
			"which has frequency 'never'\n" );
		return;
	}
		
	my $user = $self->get_user;

	if( !defined $user )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out a subscription for a\n".
			"non-existant user. Subid#".$self->get_id."\n" );
		return;
	}

	my $origlangid = $self->{session}->get_langid;
	
	$self->{session}->change_lang( $user->get_value( "lang" ) );

	my $searchexp = $self->make_searchexp;
	# get the description before we fiddle with searchexp
 	my $searchdesc = $searchexp->render_description,

	my $datestamp_field = $self->{session}->get_repository->get_dataset( 
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

	my $url = $self->{session}->get_repository->get_conf( "perl_url" ).
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

=item EPrints::DataObj::Subscription::process_set( $session, $frequency );

Static method. Calls send_out_subscriptions on every subscription 
with a frequency matching $frequency.

Also saves a file logging that the subscription for this frequency
was sent out at the current time.

=cut
######################################################################

sub process_set
{
	my( $session, $frequency ) = @_;

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		$session->get_repository->log( "EPrints::DataObj::Subscription::process_set called with unknown frequency: ".$frequency );
		return;
	}

	my $subs_ds = $session->get_repository->get_dataset( "subscription" );

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

	my $statusfile = $session->get_repository->get_conf( "variables_path" ).
		"/subscription-".$frequency.".timestamp";

	unless( open( TIMESTAMP, ">$statusfile" ) )
	{
		$session->get_repository->log( "EPrints::DataObj::Subscription::process_set failed to open\n$statusfile\nfor writing." );
	}
	else
	{
		print TIMESTAMP <<END;
# This file is automatically generated to indicate the last time
# this repository successfully completed sending the *$frequency* 
# subscriptions. It should not be edited.
END
		print TIMESTAMP EPrints::Utils::get_timestamp()."\n";
		close TIMESTAMP;
	}
}


######################################################################
=pod

=item $timestamp = EPrints::DataObj::Subscription::get_last_timestamp( $session, $frequency );

Static method. Return the timestamp of the last time this frequency 
of subscription was sent.

=cut
######################################################################

sub get_last_timestamp
{
	my( $session, $frequency ) = @_;

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		$session->get_repository->log( "EPrints::DataObj::Subscription::get_last_timestamp called with unknown\nfrequency: ".$frequency );
		return;
	}

	my $statusfile = $session->get_repository->get_conf( "variables_path" ).
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
