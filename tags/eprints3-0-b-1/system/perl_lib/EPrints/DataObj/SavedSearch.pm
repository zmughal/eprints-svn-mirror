######################################################################
#
# EPrints::DataObj::SavedSearch
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

B<EPrints::DataObj::SavedSearch> - Single saved search.

=head1 DESCRIPTION

A saved search is a sub class of EPrints::DataObj.

Each one belongs to one and only one user, although one user may own
multiple saved searches.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::DataObj::SavedSearch;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;


######################################################################
=pod

=item $field_config = EPrints::DataObj::SavedSearch->get_system_field_info

Return an array describing the system metadata of the saved search.
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"id", type=>"int", required=>1, import=>0 },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

		{ name=>"userid", type=>"itemref", 
			datasetid=>"user", required=>1 },

		{ name=>"pos", type=>"int", required=>1 },

		{ 
			name => "spec",
			type => "search",
			datasetid => "eprint",
		},

		{ name=>"frequency", type=>"set", required=>1,
			options=>["never","daily","weekly","monthly"] },

		{ name=>"mailempty", type=>"boolean", input_style=>"radio" },
	);
}

######################################################################
=pod

=item $saved_search = EPrints::DataObj::SavedSearch->new( $session, $id )

Return new Saved Search object, created by loading the Saved Search
with id $id from the database.

=cut
######################################################################

sub new
{
	my( $class, $session, $id ) = @_;

	return $session->get_database->get_single( 	
		$session->get_repository->get_dataset( "saved_search" ),
		$id );
}

######################################################################
=pod

=item $saved_search = EPrints::DataObj::SavedSearch->new_from_data( $session, $data )

Construct a new EPrints::DataObj::SavedSearch object based on the $data hash 
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
		"saved_search" );
	$self->{session} = $session;
	
	return $self;
}

######################################################################
# =pod
# 
# =item $saved_search = EPrints::DataObj::SavedSearch->create( $session, $userid )
# 
# Create a new saved search. entry in the database, belonging to user
# with id $userid.
# 
# =cut
######################################################################

sub create
{
	my( $class, $session, $userid ) = @_;

	return EPrints::DataObj::SavedSearch->create_from_data( 
		$session, 
		{ userid=>$userid },
		$session->get_repository->get_dataset( "saved_search" ) );
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::SavedSearch->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	my $id = $session->get_database->counter_next( "saved_search_id" );

	$data->{id} = $id;
	$data->{frequency} = 'never';
	$data->{mailempty} = "TRUE";
	$data->{spec} = '';
	$data->{rev_number} = 1;

	$session->get_repository->call(
		"set_saved_search_defaults",
		$data,
		$session );

	return $data;
}	


######################################################################
=pod

=item $success = $saved_search->remove

Remove the saved search.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

	my $subs_ds = $self->{session}->get_repository->get_dataset( 
		"saved_search" );
	
	my $success = $self->{session}->get_database->remove(
		$subs_ds,
		$self->get_value( "id" ) );

	return $success;
}


######################################################################
=pod

=item $success = $saved_search->commit( [$force] )

Write this object to the database.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;
	
	$self->{session}->get_repository->call( 
		"set_saved_search_automatic_fields", 
		$self );

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	

	my $subs_ds = $self->{session}->get_repository->get_dataset( 
		"saved_search" );
	my $success = $self->{session}->get_database->update(
		$subs_ds,
		$self->{data} );

	$self->queue_changes;

	return $success;
}


######################################################################
=pod

=item $user = $saved_search->get_user

Return the EPrints::User which owns this saved search.

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

=item $searchexp = $saved_search->make_searchexp

Return a EPrints::Search describing how to find the eprints
which are in the scope of this saved search.

=cut
######################################################################

sub make_searchexp
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset( 
		"saved_search" );
	
	return $ds->get_field( 'spec' )->make_searchexp( 
		$self->{session},
		$self->get_value( 'spec' ) );
}


######################################################################
=pod

=item $saved_search->send_out_alert

Send out an email for this subcription. If there are no matching new
items then an email is only sent if the saved search has mailempty
set to true.

=cut
######################################################################

sub send_out_alert
{
	my( $self ) = @_;

	my $freq = $self->get_value( "frequency" );

	if( $freq eq "never" )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out an alert for a\n".
			"which has frequency 'never'\n" );
		return;
	}
		
	my $user = $self->get_user;

	if( !defined $user )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out an alert for a\n".
			"non-existant user. ID#".$self->get_id."\n" );
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
		my $yesterday = EPrints::Utils::get_iso_date( 
			time - (24*60*60) );
		# Get from the last day
		$searchexp->add_field( 
			$datestamp_field,
			$yesterday."-" );
	}
	elsif( $freq eq "weekly" )
	{
		# Work out date a week ago
		my $last_week = EPrints::Utils::get_iso_date( 
			time - (7*24*60*60) );

		# Get from the last week
		$searchexp->add_field( 
			$datestamp_field,
			$last_week."-" );
	}
	elsif( $freq eq "monthly" )
	{
		# Get today's date
		my( $year, $month, $day ) = EPrints::Utils::get_iso_date( time );
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
		"/users/home?screenid=SavedSearh::View";
	my $freqphrase = $self->{session}->html_phrase(
		"lib/saved_search:".$freq );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		my $p = $session->make_element( "p" );
		$p->appendChild( $item->render_citation_link );
		$info->{matches}->appendChild( $p );
#		$info->{matches}->appendChild( $session->make_text( $item->get_url ) );
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
				"lib/saved_search:mail",
				howoften => $freqphrase,
				n => $self->{session}->make_text( $searchexp->count ),
				search => $searchdesc,
				matches => $info->{matches},
				url => $self->{session}->render_link( $url ) );
		if( $self->{session}->get_noise >= 2 )
		{
			print "Sending out alert #".$self->get_id." to ".$user->get_value( "email" )."\n";
		}
		$user->mail( 
			"lib/saved_search:sub_subj",
			$mail );
		EPrints::XML::dispose( $mail );
	}
	$searchexp->dispose;

	$self->{session}->change_lang( $origlangid );
}


######################################################################
=pod

=item EPrints::DataObj::SavedSearch::process_set( $session, $frequency );

Static method. Calls send_out_alerts on every saved search 
with a frequency matching $frequency.

Also saves a file logging that the alerts for this frequency
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
		$session->get_repository->log( "EPrints::DataObj::SavedSearch::process_set called with unknown frequency: ".$frequency );
		return;
	}

	my $subs_ds = $session->get_repository->get_dataset( "saved_search" );

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $subs_ds );

	$searchexp->add_field(
		$subs_ds->get_field( "frequency" ),
		$frequency );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		$item->send_out_alerts;
	};

	$searchexp->perform_search;
	$searchexp->map( $fn, {} );
	$searchexp->dispose;

	my $statusfile = $session->get_repository->get_conf( "variables_path" ).
		"/alert-".$frequency.".timestamp";

	unless( open( TIMESTAMP, ">$statusfile" ) )
	{
		$session->get_repository->log( "EPrints::DataObj::SavedSearch::process_set failed to open\n$statusfile\nfor writing." );
	}
	else
	{
		print TIMESTAMP <<END;
# This file is automatically generated to indicate the last time
# this repository successfully completed sending the *$frequency* 
# alerts. It should not be edited.
END
		print TIMESTAMP EPrints::Utils::human_time()."\n";
		close TIMESTAMP;
	}
}


######################################################################
=pod

=item $timestamp = EPrints::DataObj::SavedSearch::get_last_timestamp( $session, $frequency );

Static method. Return the timestamp of the last time this frequency 
of alert was sent.

=cut
######################################################################

sub get_last_timestamp
{
	my( $session, $frequency ) = @_;

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		$session->get_repository->log( "EPrints::DataObj::SavedSearch::get_last_timestamp called with unknown\nfrequency: ".$frequency );
		return;
	}

	my $statusfile = $session->get_repository->get_conf( "variables_path" ).
		"/alert-".$frequency.".timestamp";

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
