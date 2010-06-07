package EPrints::Feed::Twitter;

use Net::Twitter;

# Tweet data from service.
# {
# 	'source' => '&lt;a href=&quot;http://www.tweetdeck.com/&quot; rel=&quot;nofollow&quot;&gt;TweetDeck&lt;/a&gt;',
# 	'to_user_id' => undef,
# 	'geo' => undef,
# 	'profile_image_url' => 'http://s.twimg.com/a/1274899949/images/default_profile_4_normal.png',
# 	'from_user_id' => 114298298,
# 	'iso_language_code' => 'en',
# 	'created_at' => 'Mon, 31 May 2010 13:25:48 +0000',
# 	'text' => 'RT @AmSciForum: Peer Review and Open Access http://bit.ly/OApeer-rev #amsci #oa #openaccess #repositories #universities #research',
# 	'metadata' => {
# 		'result_type' => 'recent'
# 	},
# 	'id' => '15107186072',
# 	'from_user' => 'digiwis'
# },


sub new
{
	my ($class, $document) = @_;

	return bless { 
		document => $document,
		write_buffer => [],
		feeds_in_parallel => 3,
	}, $class;
}


sub create_main_file
{
	my ($self) = @_;

	my $file = $self->{document}->get_main;

	if ( $file and  ($file =~ m/twiter\.txt$/) )
	{
		#remove previously generated file
		$file->remove();
	}


	my $filename = File::Temp->new;
	open FILE,">$filename" or print STDERR "Couldn't open $filename\n";
	print FILE $self->file_header;

	my $files = $self->{document}->get_value('files');
	foreach my $file ( sort _most_recent_first @{$files})
	{
		next unless ($file->get_value('filename') =~ m/^[0-9]*\.xml/); # quick check
		#get tweets from update files and sore in human-readable one
		my $filename = $file->get_local_copy;
		my $xml = $self->{document}->repository->xml;
		my $tweets_dom = $xml->parse_file($filename);

		my @ids;
		foreach my $id_text_node ( $tweets_dom->findnodes('//tweets/tweet/id/text()') )
		{
			push @ids, $xml->to_string($id_text_node);
		}


		foreach my $id (sort {$b <=> $a} @ids)
		{
			my $values;
			foreach my $fieldname ( qw/ created_at from_user text / )
			{
				my @nodes = $tweets_dom->findnodes("//tweets/tweet[id/text()='$id']/$fieldname/text()");
				$values->{$fieldname} = $xml->to_string($nodes[0]) if $nodes[0];
				$values->{$fieldname} =~ s/[\r\n]/ /g;
			}

			print FILE $values->{created_at}, ', ', $values->{from_user}, ':  ', $values->{text}, "\n";
		}
		$xml->dispose($tweets_dom);
	}
	close FILE;

	$self->{document}->add_file($filename,'twitter.txt');
	$self->{document}->set_main('twitter.txt');
	$self->{document}->commit;

}

sub _most_recent_first
{
	my $a_filename = $a->get_value('filename');
	$a_filename =~ m/^([0-9]*)\.xml/;
	my $a_sortvalue = $1 ? $1 : 0;

	my $b_filename = $b->get_value('filename');
	$b_filename =~ m/^([0-9]*)\.xml/;
	my $b_sortvalue = $1 ? $1 : 0;

	return $b_sortvalue <=> $a_sortvalue;
}

sub highest_id
{
	my ($self) = @_;

	#get all XML files and parse them.  Return highest ID
        my $files = $self->{document}->get_value('files');
        my @sorted_files = sort _most_recent_first @{$files};

	my $last_tweet;
	if ($sorted_files[0] and $sorted_files[0]->get_value('filename') =~ m/^[0-9]*\.xml$/)
	{
        	my $filename = $sorted_files[0]->get_local_copy;
		my $xml = $self->{document}->repository->xml;
		my $tweets_dom = $xml->parse_file($filename);

		my @ids;
		foreach my $id_text_node ( $tweets_dom->findnodes('//tweets/tweet/id/text()') )
		{
			push @ids, $xml->to_string($id_text_node);
		}
		@ids = sort {$b <=> $a} @ids;

		my $highest_id = $ids[0];
	}

	return $last_tweet;	
}


sub add_to_buffer
{
	my ($self, $tweet) = @_;

	my $buffer;

	foreach my $k (keys %{$tweet})
	{
		$buffer->{$k} = $tweet->{$k} if $tweet->{$k};
	}

	push @{$self->{write_buffer}}, $buffer;
}

#call if we didn't find the id we were looking for
sub commit_incomplete
{
	my ($self) = @_;

	if (scalar @{$self->{write_buffer}})
	{
		my $oldest = pop @{$self->{write_buffer}};
		push @{$self->{write_buffer}}, $oldest;

		my $warning = {
			id => $oldest->{id} - 1,
			from_user => 'EPRINTS',
			text => 'WARNING: SOME TWEETS MAY NOT HAVE BEEN MISSED!',
			created_at => $oldest->{created_at},
		};
		$self->add_to_buffer($warning);
		$self->commit;
	}

}

#writes back to file
sub commit
{
	my ($self) = @_;

	if (scalar @{$self->{write_buffer}})
	{

		my $xml = $self->{document}->repository->xml;

		my $tweets_dom = $xml->create_element('tweets');
		foreach my $tweet (@{$self->{write_buffer}})
		{
			my $tweet_dom = $xml->create_element('tweet');
			$tweets_dom->appendChild($tweet_dom);
			foreach my $k (keys %{$tweet})
			{
				$tweet_dom->appendChild($self->_generate_dom($xml, $k, $tweet->{$k}));
			}
		}

		my $filename = File::Temp->new;
		open FILE,">$filename" or print STDERR "Couldn't open $filename\n";
		print FILE '<?xml version="1.0" encoding="utf-8" ?>', "\n";
		print FILE $xml->to_string($tweets_dom);
		close FILE;
		$self->{document}->add_file($filename, time . '.xml');
		$xml->dispose($tweets_dom);
		$self->create_main_file;
	}
}

sub _generate_dom
{
	my ($self, $xml, $key, $value) = @_;

	if ( ref($value) eq '' )
	{
		my $n = $xml->create_element($key);
		$n->appendChild($xml->create_text_node($value));
		return $n;
	}
        if( ref($value) eq "ARRAY" )
        {
		my $n = $xml->create_element($key);
                foreach( @{$value} )
                {
			$n->appendChild($self->_generate_dom($xml,'item',$_));
                }
                return $n;
        }
        if( ref($value) eq "HASH" )
        {
		my $n = $xml->create_element($key);
                foreach( keys %{$value} )
                {
			$n->appendChild($self->_generate_dom($xml,$_,$value->{$_}));
                }
                return $n;
        }

}


#I'm not sure if this belongs in here
# EPrints::Feed::Twitter::update_all($reps);
# takes a hasref mapping repository ids to repository objects
sub update_all
{
	my ($reps) = @_;

	my @documents;

	foreach my $repository (values %{$reps})
	{
		$ds = $repository->get_dataset( "document" );

		$searchexp = EPrints::Search->new(
				session => $repository,
				dataset => $ds,
				);

		$searchexp->add_field( $ds->get_field( "content" ), 'feed/twitter' );
		my $results = $searchexp->perform_search;

		my @docs = $results->get_records;
		push @documents, @docs;
	}

	my @queue;
	foreach my $doc (@documents)
	{
		my $feed_obj = EPrints::Feed::Twitter->new($doc);

		my $highest_id = $feed_obj->highest_id;
		$highest_id = 0 unless $highest_id;

		push @queue, {
			search_params => {
				q => $doc->get_value('twitter_hashtag'),
				rpp => 100,
			},
			feed_obj => $feed_obj,
			since_id => $highest_id,
			orderval => $highest_id,
		}
	}

	my $nt = Net::Twitter->new(traits => [qw/API::Search/]);

	my $nosort = 0;
	while ( scalar @queue ) #test API limits too
	{
		#prioritise by date, but have some parallelisation.  We'll only get nothing if we have feeds_in_parallel+1 trending topics.
		if (!$nosort)
		{
			@queue = sort { ( $a->{orderval} ? $b->{orderval} : -1 ) <=> ( $b->{orderval} ? $a->{orderval} : -1) } @queue; #if there's no orderval, sort highest
			$nosort = $self->{feeds_in_parallel};
		}
		$nosort--;

		my $current_item = shift @queue;


		my $tweets = eval { $nt->search($current_item->{search_params}); };
		if ($@)
		{
			print STDERR "Exiting Early: $@\n";
			last;
		}

		my $update_complete = 0;

		foreach my $tweet (@{$tweets->{results}})
		{
			if (not $current_item->{search_params}->{max_id})
			{
				$current_item->{search_params}->{max_id} = $tweet->{id}; #highest ID, for paging
			}
			$current_item->{orderval} = $tweet->{id}; #lowest processed so far, for ordering

			if ($tweet->{id} == $current_item->{since_id})
			{
				$update_complete = 1;
				last;
			}
			else
			{
				$current_item->{feed_obj}->add_to_buffer($tweet);
			}
		}

		if (
			$update_complete or 
			not scalar @{$tweets->{results}} or #empty page 
			($tweets->{page} >= 15) #twitter limit 
		)
		{
			$current_item->{feed_obj}->commit;
		}
		else
		{
			$current_item->{search_params}->{page} = $tweets->{page} + 1;
			push @queue, $current_item;
		}

	}

	foreach my $incomplete_item (@queue)
	{
		$incomplete_item->commit_incomplete;
	}





}


sub file_header
{
	my ($self) = @_;

	return "Tweets Matching " . $self->{document}->get_value('twitter_hashtag') . "\n";
}

1;
