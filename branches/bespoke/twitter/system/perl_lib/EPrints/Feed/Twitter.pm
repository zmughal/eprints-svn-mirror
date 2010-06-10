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
		tweets_in_main_file => 100,
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
	my $xml = $self->{document}->repository->xml;
	my $files = $self->{document}->get_value('files');

	my $i = 0;
	foreach my $file ( sort _most_recent_first @{$files})
	{
		my $tweets_dom = $self->_xmlfile_to_dom($file);
		next unless $tweets_dom;

		my @ids;
		foreach my $id_text_node ( $tweets_dom->findnodes('//tweets/tweet/id/text()') )
		{
			push @ids, $xml->to_string($id_text_node);
		}


		foreach my $id (sort {$b <=> $a} @ids)
		{
			$i++;
			last if $i >= $self->{tweets_in_main_file};
			my $values;
			foreach my $fieldname ( qw/ created_at from_user text / )
			{
				my @nodes = $tweets_dom->findnodes("//tweets/tweet[id/text()='$id']/$fieldname/text()");
				$values->{$fieldname} = $xml->to_string($nodes[0]) if $nodes[0];
				$values->{$fieldname} =~ s/[\r\n\t]/ /g;
			}

			print FILE $values->{created_at}, "\t", $values->{from_user}, "\t", $values->{text}, "\n";
		}
		$xml->dispose($tweets_dom);
		last if $i >= $self->{tweets_in_main_file};
	}
	close FILE;

	$self->{document}->add_file($filename,'twitter.txt');
	$self->{document}->set_main('twitter.txt');
	$self->{document}->commit;

}

sub _xmlfile_to_dom
{
	my ($self, $file) = @_;

	return undef unless ($file->get_value('filename') =~ m/^[0-9]*\.xml/); # quick check

	my $filename = $file->get_local_copy;
	my $xml = $self->{document}->repository->xml;
	my $tweets_dom = eval { $xml->parse_file($filename); };
	if ($@)
	{
		print STDERR "Couldn't parse $filename: $@\n";
		return undef;
	}
	return $tweets_dom;
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

#return the highest ID in the most recent parsable XML file
sub highest_id
{
	my ($self) = @_;

        my $files = $self->{document}->get_value('files');
	my $xml = $self->{document}->repository->xml;
	my $highest_id;
	foreach my $file (sort _most_recent_first @{$files})
	{
		my $tweets_dom = $self->_xmlfile_to_dom($file);
		next unless $tweets_dom;

		my @ids;
		foreach my $id_text_node ( $tweets_dom->findnodes('//tweets/tweet/id/text()') )
		{
			push @ids, $xml->to_string($id_text_node);
		}
		@ids = sort {$b <=> $a} @ids;

		$highest_id = $ids[0];
		last; #if we successfully got to here then we parsed an XML file, and we only need one.
	}
	return $highest_id;
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
			text => 'WARNING: SOME TWEETS MAY HAVE BEEN MISSED!',
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

		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		my $timestamp = sprintf("%04d%02d%02d%02d%02d%02d",$year+1900,$mon,$mday,$hour,$min,$sec);

		$self->{document}->add_file($filename, $timestamp . '.xml');
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

		#strip out control chars (tdb's code from MetaField::ID)
		$value =~ s/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/\x{fffd}/g;

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
                my $today = EPrints::Time::get_iso_date( time );
                $searchexp->add_field(
                        $ds->get_field( "twitter_expiry_date" ),
                        $today."-" );

		
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
#				max_id => set to first ID we get
#				page => set to current page + 1 when this item is requeued
			},
			feed_obj => $feed_obj,
			since_id => $highest_id,
			orderval => $highest_id,
			first_update => $highest_id ? 1 : 0, #if we have no highest_id, then it's the first time we've searched on this item.
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

		if ($update_complete) #we get all tweets up to the ones we previously stored
		{
			$current_item->{feed_obj}->commit;
		}
		elsif ( #we didn't get all tweets upto the one we last stored, but we exhausted our search
			not scalar @{$tweets->{results}} or #empty page 
			($tweets->{page} >= 15) #twitter limit 
		)
		{
			if ($current_item->{first_updtae})
			{
				$current_item->{feed_obj}->commit;
			}
			else
			{
				$current_item->{feed_obj}->commit_incomplete;
			}
		}
		else #we still have search pages to look at.
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
