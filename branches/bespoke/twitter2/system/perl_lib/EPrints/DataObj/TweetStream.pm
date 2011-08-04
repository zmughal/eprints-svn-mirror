package EPrints::DataObj::TweetStream;

@ISA = ( 'EPrints::DataObj' );

use EPrints;
use EPrints::Search;
use Date::Calc qw/ Week_of_Year Delta_Days Add_Delta_Days /;

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

		{ name=>"items", type=>"itemref", datasetid=>"tweet", required => 1, multiple => 1, render_value => 'EPrints::DataObj::TweetStream::render_items' },

		{ name=>"highest_twitterid", type=>'bigint', volatile=>1},

		#digest information store anything that appears more than once.
		{ name => "top_hashtags", type=>"compound", multiple=>1,
			'fields' => [
				{
					'sub_name' => 'hashtag',
					'type' => 'text',
				},
				{
					'sub_name' => 'count',
					'type' => 'int',
				}
			],
		},
		{ name => "top_from_users", type=>"compound", multiple=>1,
			'fields' => [
				{
					'sub_name' => 'from_user',
					'type' => 'text',
				},
				{
					'sub_name' => 'profile_image_url',
					'type' => 'url',
				},
				{
					'sub_name' => 'count',
					'type' => 'int',
				}
			],
		},
		{ name => "top_target_urls", type=>"compound", multiple=>1,
			'fields' => [
				{
					'sub_name' => 'target_url',
					'type' => 'url',
				},
				{
					'sub_name' => 'count',
					'type' => 'int',
				}
			],
		},
		{ name => "frequency_period", type => 'set', options => [ 'daily', 'weekly', 'monthly', 'yearly' ] },
		{ name => "frequency_values", type => 'compound', multiple=>1,
			'fields' => [
				{
					'sub_name' => 'label',
					'type' => 'text',
				},
				{
					'sub_name' => 'value',
					'type' => 'int',
				}
			],
		},
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

print STDERR "Committing Stream\n";

	$self->update_triggers();

	#grab the counts and anything else we need
	my $counter = {};
	my $extra_data = {};

	#enrich twitterfeed
	my $highest_id = 0;
	foreach my $tweetid (@{$self->get_value('items')})
	{
		my $tweet = EPrints::DataObj::Tweet->new($self->{session}, $tweetid);
		next unless $tweet;

		my $twitterid = $tweet->get_value('twitterid');
		$highest_id = $twitterid if $twitterid > $highest_id;

		foreach my $top_val_name (qw/ from_users hashtags target_urls /)
		{
			my $val;
			if ($top_val_name eq 'hashtags')
			{
				$val = $tweet->get_hashtags;
			}
			elsif ($top_val_name eq 'from_users')
			{
				$val = $tweet->get_value('from_user');
			}
			else
			{
				$val = $tweet->get_value($top_val_name);
			}

			if (ref $val eq 'ARRAY')
			{
				foreach my $thing (@{$val})
				{
					if ($top_val_name eq 'hashtags')
					{
						$thing = lc($thing);
					}

					$counter->{$top_val_name}->{$thing}++;
				}
			}
			else
			{
					$counter->{$top_val_name}->{$val}++;
			}

		}
		$extra_data->{'profile_image_url'}->{$tweet->get_value('from_user')} = $tweet->get_value('profile_image_url');
	}

	$self->set_value('highest_twitterid', $highest_id);

	foreach my $top_val_name (qw/ from_user hashtag target_url /)
	{
		my $n = 50; #perhaps pull this from config
		my $counts = [];
		foreach my $thing (
			sort
			{$counter->{$top_val_name.'s'}->{$b} <=> $counter->{$top_val_name.'s'}->{$a}}
			keys %{$counter->{$top_val_name.'s'}}
		)
		{
			last unless $n;
			$n--;
			my $count = { $top_val_name => $thing, count => $counter->{$top_val_name.'s'}->{$thing} };
			if ($top_val_name eq 'from_user')
			{
				$count->{'profile_image_url'} = $extra_data->{'profile_image_url'}->{$thing};
			}
			push @{$counts}, $count;
		}

		$self->set_value('top_' . $top_val_name . 's', $counts);
	}

	#create the time graph values
	my $times = [];
	foreach my $tweetid (@{$self->get_value('items')})
	{
		my $tweet = EPrints::DataObj::Tweet->new($self->{session}, $tweetid);
		next unless $tweet;
		push @{$times}, $tweet->get_value('created_at');
	}
	my ($period, $pairs) = $self->periodise_dates($times);

	$self->set_value('frequency_period',$period);
	$self->set_value('frequency_values',$pairs);

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}

	my $success = $self->SUPER::commit( $force );
	
	return( $success );
}


sub periodise_dates
{
	my ($self, $dates) = @_;

	my $first = $dates->[0];
	my $last = $dates->[$#{$dates}];

	return (undef,undef) unless ($first && $last); #we won't bother generating graphs based on hours or minutes

	my $delta_days = Delta_Days(parse_datestring($first),parse_datestring($last));

	return (undef,undef) unless $delta_days; #we won't bother generating graphs based on hours or minutes

	#maximum day delta in each period class
	my $thresholds = {
		daily => (30*1),
		weekly => (52*7),
		monthly => (48*30),
	};

	my $period = 'yearly';
	foreach my $period_candidate (qw/ daily weekly monthly /)
	{
		$period = $period_candidate if $delta_days > $thresholds->{$period_candidate};
	}

	my $label_values = {};
	my $pairs = [];

	initialise_date_structures($label_values, $pairs, $first, $last, $period);

	foreach my $date (@{$dates})
	{
		my $label = YMD_to_label(parse_datestring($date), $period);
		$label_values->{$label}->{value}++;
	}

	return ($period, $pairs);
}

sub initialise_date_structures
{
	my ($label_values, $pairs, $first_date, $last_date, $period) = @_;

	my $current_date = $first_date;
	my $current_label = YMD_to_label(parse_datestring($current_date),$period);
	my $last_label = YMD_to_label(parse_datestring($last_date),$period);

	my ($year, $month, $day) = parse_datestring($first_date);

	while ($current_label ne $last_label)
	{
		$label_values->{$current_label}->{label} = $current_label;
		$label_values->{$current_label}->{value} = 0;
		push @{$pairs}, $label_values->{$current_label};

		($year, $month, $day, $current_label) = next_YMD_and_label($year, $month, $day, $current_label, $period);
print STDERR "$current_label moving toward $last_label\n";
die if $year > 2011;
	}

	$label_values->{$last_label}->{label} = $last_label;
	$label_values->{$last_label}->{value} = 0;
	push @{$pairs}, $label_values->{$last_label};
}

sub next_YMD_and_label
{
	my ($year, $month, $day, $label, $period) = @_;

	my $new_label = $label;

	while ($new_label eq $label)
	{
		($year, $month, $day) = Add_Delta_Days ($year, $month, $day, 1);
		$new_label = YMD_to_label($year, $month, $day, $period);

print STDERR '.';
	}
	return ($year, $month, $day, $new_label);
}

sub YMD_to_label
{
	my ($year, $month, $day, $period) = @_;

	return $year if $period eq 'yearly';
	return join('-',(sprintf("%04d",$year), sprintf("%02d",$month))) if $period eq 'monthly';
	return join('-',(sprintf("%04d",$year), sprintf("%02d",$month),sprintf("%02d",$day))) if $period eq 'daily';

	if ($period eq 'weekly')
	{
		my ($week, $wyear) = Week_of_Year($year, $month, $day);
		return "Week $week, $wyear";
	}

	return undef;
}

sub parse_datestring
{
	my ($date) = @_;

	my ($year,$month,$day) = split(/[- ]/,$date);
	return ($year,$month,$day);
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

sub number_of_tweets
{
	my ($self) = @_;

	return 0 unless $self->is_set('items');

	return scalar @{$self->get_value('items')};
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

sub render
{
	my ($self) = @_;

	my $session = $self->{session};

	my $dom = $session->make_doc_fragment;
	my $h1 = $session->make_element('h1');
	$h1->appendChild($session->make_text('HELLO'));
	$dom->appendChild($h1);

	my $title = $session->make_doc_fragment;
	$title->appendChild($session->make_text('Hello Title'));

	return ($dom, $title);
}


sub render_items
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

	my $items_to_display = 10;

        my $xml = $session->xml;
	my $tweet_ds = $session->dataset('tweet');

	my $ol = $xml->create_element('ol', class => 'tweets');

	if ($object->number_of_tweets <= $items_to_display)
	{
		foreach my $tweetid (@{$value})
		{
			my $tweet = $tweet_ds->dataobj($tweetid);
			$ol->appendChild($tweet->render_li);
		}
	}
	else
	{
		my $flag = 1;
		foreach my $range ( [0, int($items_to_display/2)], [$#{$value}-(int($items_to_display/2)),$#{$value}] )
		{
			foreach my $tweetid ( @{$value}[$range->[0]..$range->[1]] )
			{
				my $tweet = $tweet_ds->dataobj($tweetid);
				$ol->appendChild($tweet->render_li);
			}
			if ($flag)
			{
				$flag = 0;
				my $li = $xml->create_element('li');
				$li->appendChild($session->html_phrase('DataObj::Tweet/unshown_items', n=>$xml->create_text_node(($object->number_of_tweets - $items_to_display))));
				$ol->appendChild($li);
			}

		}
	}

	return $ol;
}

sub has_owner
{
	my( $self, $possible_owner ) = @_;

	if( $possible_owner->get_value( "userid" ) == $self->get_value( "userid" ) )
	{
		return 1;
	}

	return 0;
}



1;
