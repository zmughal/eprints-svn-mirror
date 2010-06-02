package EPrints::Feed::Twitter;

use Text::CSV;
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
		fields => [ 'id', 'from_user', 'from_user_id', 'created_at', 'iso_language_code', 'text' ],
		write_bufer => [],
	}, $class;
}

sub get_local_filepath
{
	my ($self) = @_;

	my $fileobj = $self->{document}->get_stored_file( $self->{document}->get_main );
	my $file = $fileobj->get_local_copy;
	return $file;
}

sub get_last
{
	my ($self) = @_;

	open FILE, $self->get_local_filepath or return;
	my $last;
	while (<FILE>)
	{
		$last = $_;
	}

use Data::Dumper;
print STDERR $last;

	if ($last)
	{
		my $tweet = $self->_hashref_from_string($last);
print STDERR Dumper $tweet;
exit;
		return $tweet if $tweet->{id} ne 'id'; #it's the heading
	}
}

# my $tweet = EPrints::Feed:Twitter->new_from_service($data);
# takes a hasref returned from the twitter api call
sub add_from_service
{
	my ($self, $data) = @_;

	my $tweet = {};

	foreach my $heading (@{$self->{fields}})
	{
		$tweet->{$heading} =  $data->{$heading};
	}

	#important = prepend to array so most recent is at the end -- this makes writing to the file easier
	unshift @{$self->{write_buffer}}, $tweet;

}


#writes back to file
sub commit
{
	my ($self) = @_;
	open (FILE, '>>', $self->get_local_filepath);
	foreach my $tweet (@{$self->{write_buffer}})
	{
		print FILE $self->_string_from_hashref($tweet);
	}
	close FILE;
}

sub _string_from_hashref
{
	my ($self, $hashref) = @_;

	$self->_start_parser;

	my @line;
	foreach my $field (@{$self->{fields}})
	{
		push @line, $hashref->{$field};
	}
	if ($self->{csv}->combine(@line))
	{
		return $self->{csv}->string . "\n";
	}
	return "ERROR\n";
}

sub _hashref_from_string
{
	my ($self, $string) = @_;

	chomp $string;

	$self->_start_parser;

	my @fields;
	my $tweet;
	if ($self->{csv}->parse($file_line))
	{
print 'HAHAHA';
		@fields = $self->{csv}->fields;

		for (my $i = 0; $i <= @{$self->{fields}}; $i++)
		{
			$tweet->{$self->{fields}->[$i]} = $fields->[$i];
		}
	}
	else
	{
		print STDERR "CSV Parse Failed : " . $self->{csv}->error_input();
	}

	return $tweet;
}



sub _start_parser
{
	my ($self) = @_;

	return if defined $self->{csv};
	$self->{csv} = Text::CSV->new;
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

		my $newest_id = 0;
		my $newest_tweet = $feed_obj->get_last;
		$newest_id = $newest_tweet->{id} if defined $newest_tweet;

		push @queue, {
			search_params => {
				q => $doc->get_value('twitter_hashtag'),
				rpp => 100,
			},
			feed_obj => $feed_obj,
			since_id => $newest_id,
			orderval => $newest_id,
		}
	}

	my $nt = Net::Twitter->new(traits => [qw/API::Search/]);

	while ( scalar @queue ) #test API limits too
	{
		@queue = sort {$b->{orderval} <=> $a->{orderval}} @queue;

		my $current_item = shift @queue;

		my $tweets = $nt->search($current_item->{search_params});

		my $update_complete = 0;

		foreach my $tweet (@{$tweets->{results}})
		{
			if ($tweet->{id} == $current_item->{since_id})
			{
				$update_complete = 1;
				last;
			}
			else
			{
				$current_item->{feed_obj}->add_from_service($tweet);
			}
		}
		##!!!!!!
		$update_complete = 1;

		if ($update_complete)
		{
			$current_item->{feed_obj}->commit;
		}
		else
		{
			#add next page to queue
		}

	}




}


sub file_header
{
	my ($self) = @_;

	$self->_start_parser;
	if ($self->{csv}->combine(@{$self->{fields}}))
	{
		return $self->{csv}->string;
	}
	return "ERROR\n";
}

1;
