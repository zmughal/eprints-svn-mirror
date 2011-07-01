package EPrints::DataObj::TweetStream;

@ISA = ( 'EPrints::DataObj' );

use EPrints;
use EPrints::Search;

use strict;


######################################################################
=pod

=item $field_info = EPrints::DataObj::Tweet->get_system_field_info

Return an array describing the system metadata of the this 
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"tweetstreamid", type=>"counter", required=>1, import=>0, can_clone=>1,
			sql_counter=>"tweetstreamid" },

		{ name=>"userid", type=>"itemref", datasetid=>"user", required=>1 },

		{ name=>"search_string", type=>"text", required=>"yes" },

		{ name=>"expiry_date", type=>"date", required=>"yes" },

		{ name=>"items", type=>"itemref", datasetid=>"tweet", required => 1, multiple => 1 },

		{ name=>"highest_twitterid", type=>'bigint', volatile=>1},

	)
};



######################################################################
=pod

=item $tweet = EPrints::DataObj::Tweet->new( $session, $tweetid )

Load the tweet with the ID of $tweetid from the database and return
it as an EPrints::DataObj::Tweet object.

=cut
######################################################################

sub new
{
	my( $class, $session, $tweetid ) = @_;

	return $session->get_database->get_single( 
		$session->get_repository->get_dataset( "tweetstream" ),
		$tweetid );
}


######################################################################
=pod

=item $tweet = EPrints::DataObj::Tweet->new_from_data( $session, $data )

Construct a new EPrints::DataObj::Tweet object based on the $data hash 
reference of metadata.

Used to create an object from the data retrieved from the database.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "tweetstream" ) );
}


######################################################################
# =pod
# 
# =item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )
# 
# Create a new object of this type in the database. 
# 
# $dataset is the dataset it will belong to. 
# 
# $data is the data structured as with new_from_data.
# 
# =cut
######################################################################

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $new_tweetstream = $class->SUPER::create_from_data( $session, $data, $dataset );

	$new_tweetstream->update_triggers();
	
	if( scalar( keys %{$new_tweetstream->{changed}} ) > 0 )
	{
		# Remove empty slots in multiple fields
		$new_tweetstream->tidy;

		# Write the data to the database
		$session->get_database->update(
			$new_tweetstream->{dataset},
			$new_tweetstream->{data},
			$new_tweetstream->{changed} );
	}

	$session->get_database->counter_minimum( "tweetstreamid", $new_tweetstream->get_id );

	return $new_tweetstream;
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::Tweet->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "tweetstream";
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::Tweet->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

# inherits


######################################################################
=pod

=item $tweet->commit( [$force] )

Write this object to the database.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	$self->update_triggers();
	
	#set highest_twitterid
	my $highest_id = 0;
	foreach my $tweetid (@{$self->get_value('items')})
	{
		my $tweet = EPrints::DataObj::Tweet->new($self->{session}, $tweetid);
		next unless $tweet;

		my $twitterid = $tweet->get_value('twitterid');
		$highest_id = $twitterid if $twitterid > $highest_id;
	}
	$self->set_value('highest_twitterid', $highest_id);

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}


	my $success = $self->SUPER::commit( $force );
	
	return( $success );
}



######################################################################
=pod

=item $success = $tweetstream->remove

Remove this tweetstream from the database. 

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	my $success = 1;

	#remove tweets belonging to this object that don't belong to other objects
	my $tweet_ds = $self->{session}->get_repository->get_dataset( "tweet" );
	foreach my $tweetid ($self->get_value('items'))
	{
		my $tweet = $tweet_ds->dataobj($tweetid);
		next unless $tweet;
		my $parent_tweetstreams = $tweet->tweetstream_list;
		$tweet->remove if $parent_tweetstreams->count == 1; #remove it it's only in one tweetstream (this one)
	}

	# remove tweetstream record
	my $tweetstream_ds = $self->{session}->get_repository->get_dataset( "tweetstream" );
	$success = $success && $self->{session}->get_database->remove(
		$tweetstream_ds,
		$self->get_value( "tweetstreamid" ) );
	
	return( $success );
}


sub highest_twitterid
{
	my ($self) = @_;

	return $self->get_value('highest_twitterid');
}


######################################################################
=pod

=item $success = $tweetstream->add_tweetids( $tweetids )

Add tweets to this tweetstream.

$tweetids is an arrayref containing the tweetids (note: not twitterids)
  of the tweets to be added.

IMPORTANT -- the array must be sorted in newest first order, which is
  the oder that they would have been supplied by twitter.  Note that
  such sorting *must* be done by twitterid (or date), not tweetid.

=cut
######################################################################

sub add_tweetids
{
	my ($self, $tweetids) = @_;

	return 0 unless defined $tweetids;

	my @new_items = reverse @{$tweetids};

	if (not $self->is_set('items'))
	{
		$self->set_value('items', \@new_items);
		$self->commit;
		return;
	}

	my @items;
	push @items, @{$self->get_value('items')};

	#only store up to the most recent in this stream
	my $i = $#new_items;
	while ($i >= 0)
	{
		last if $new_items[$i] == $items[$#items]; 
		$i--;
	}


	if ($i >= 0) #we didn't find a duplicate
	{
		push @items, EPrints::DataObj::Tweet::error_id($self->{session}, -1);
	}
	else
	{
		$i++; # $i was previously the index of the duplicate item
		push @items, @new_items[$i..$#new_items];
	}

	push @items, @new_items;
	$self->set_value('items', \@items);
	$self->commit;
}


1;
