package EPrints::Feed::Twitter;

use LWP::UserAgent;
use URI::Find;

my $MAINFILENAME = 'index.html';

#regexps for recognising filetypes (excluding main file, which is a constant)
my $file_types =
{
	update => {
		'isa' => sub
		{
			my ($file) = @_; return 1 if $file->get_value('filename') =~ m/^update_[0-9]+_to_[0-9]+\.xml$/; return 0;
		},
		filename => sub
		{
			my ($low_id, $high_id) = @_; return 'update_' . $low_id . '_to_' . $high_id . '.xml';
		},
	},
	rendered_html_index => {
		'isa' => sub
		{
			my ($file) = @_; return 1 if $file->get_value('filename') eq $MAINFILENAME; return undef;
		},
		filename => sub { return $MAINFILENAME },
		template => 'tweet_html',
		page => sub
		{
			my ($xml, $feed) = @_;

			my $ol = $xml->create_element('ol');

			foreach my $file ( reverse sort _most_recent_first @{$feed->{document}->get_value('files')})
			{
				next unless $feed->is_file_a($file, 'rendered_html');
				my $a = $xml->create_element('a', href => $file->get_value('filename'));
				$a->appendChild($xml->create_text_node($file->get_value('filename')));
				my $li = $xml->create_element('li');
				$li->appendChild($a);
				$ol->appendChild($li);
			}
			return $ol;
		},
		title => sub
		{
			my ($xml, $feed) = @_;
			return $xml->create_text_node(
				'Results for Twitter search for ' . $feed->{document}->get_value('twitter_hashtag')
			);
		}
	},
	rendered_html => {
		'isa' => sub
		{
			my ($file) = @_; return 1 if $file->get_value('filename') =~ m/^rendered_[0-9]+_to_[0-9]+\.html$/; return undef;
		},
		filename => sub
		{
			my ($low_id, $high_id) = @_; return 'rendered_' . $low_id . '_to_' . $high_id . '.html';
		},
		template => 'tweet_html',
		page => sub
		{
			my ($xml, $feed, $tweets_dom_arrayref) = @_; #tweets_dom contains tweets for this page

			my $ul = $xml->create_element('ul');

			#make sure they're written to the file oldest first
			foreach my $tweet (sort 
				{ $xml->to_string(@{$a->findnodes("id/text()")}[0]) <=> $xml->to_string(@{$b->findnodes("id/text()")}[0]) }
				@{$tweets_dom_arrayref})
			{
				my $bits = {};

				my $html_tweet = $xml->create_element('li');
				$html_tweet->appendChild( @{$tweet->findnodes("text/text()")}[0] );

				$ul->appendChild($html_tweet);
				
			}
			return $ul;
		},
		title => sub
		{
			my ($xml, $feed) = @_;

			return $xml->create_text_node(
				'Results for Twitter search for ' . $feed->{document}->get_value('twitter_hashtag')
			);
		},
		max_per_file => 200,
	},

};

sub is_file_a
{
	my ($self, $file, $type) = @_;

	if ($file_types->{$type})
	{
		return &{$file_types->{$type}->{'isa'}}($file);
	}

	return 0;
}

sub make_file_name
{
	my ($self, $low_id, $high_id, $type) = @_;

	if ($file_types->{$type})
	{
		return &{$file_types->{$type}->{name_constructor}}($low_id, $high_id);
	}

	return undef;
}






sub new
{
	my ($class, $document) = @_;

	return bless { 
		document => $document,
		write_buffer => [],
		uri_cache => {}, #for URL redirect lookups 
	}, $class;
}




#the plan:

#name the update files with the oldest (last) twitter ID contained therein.
#Human readable HTLM will start at oldest and run X to a page.  HTML files will be named with the ID of the oldest tweet.
#when updating is done, only the top index file and the most recent (+new) tweet list page will need to be generated
#xml files with IDs lower than the latest page won't need to be looked at.



sub create_main_file
{
	my ($self, $force) = @_;

return unless $self->{document}->get_parent->get_id == 3;

	my $repository = $self->{document}->repository;
	my $xml = $repository->xml;

	my $lowest_id_to_render;

	if ($force)
	{
		foreach my $file (@{$self->{document}->get_value('files')})
		{
			$file->remove if ($self->is_file_a($file, 'rendered_html'));
			$file->remove if ($self->is_file_a($file, 'rendered_html_index'));
		}
		$lowest_id_to_render = 0; #render all of them
	}
	else
	{
		my $mainfile = $self->{document}->get_stored_file(&{$file_types->{rendered_html_index}->{filename}});

		my $most_recent_rendered_html = $self->most_recent_file('rendered_html');
		my ($html_highest_low_id, $html_highest_high_id) = (0,0);
		($html_highest_low_id, $html_highest_high_id) = $self->file_id_range($most_recent_rendered_html) if $most_recent_rendered_html;

		my $most_recent_update = $self->most_recent_file('update');
		my ($xml_highest_low_id, $xml_highest_high_id) = (0,0);
		($xml_highest_low_id, $xml_highest_high_id) = $self->file_id_range($most_recent_update) if $most_recent_update;

		if ( $mainfile and $html_highest_id and $xml_highest_id)
		{
			return if ($html_highest_id == $xml_highest_id);  #no need to update, html is up-to-date
		}

		$most_recent_rendered_html->remove if $most_recent_rendered_html; #we'll be 'appending' this one
		$mainfile->remove if $mainfile; #we're going to regenerate it.

		$lowest_id_to_render = $html_highest_low_id; #the lowest ID in the file we just removed
	}

	my $tweets_for_page = [];

	foreach my $update_file (reverse sort _most_recent_first @{$self->{document}->get_value('files')})
	{
		next unless $self->is_file_a($update_file, 'update'); #skip non-update_files

		my ($low_id, $high_id) = $self->file_id_range($update_file);
		next if ($high_id < $lowest_id_to_render);

		my $tweets_dom = $self->_updatefile_to_dom($update_file);
		next unless $tweets_dom;

		foreach my $tweet (reverse $tweets_dom->findnodes('//tweets/tweet'))
		{
		        my $id = $xml->to_string(@{$tweet->findnodes('id/text()')}[0]);

		        next if ($id < $lowest_id_to_render); #skip the ones in this update_file but already in an html file
			
		        push @{$tweets_for_page}, $tweet;

			if (scalar @{$tweets_for_page} >= $file_types->{rendered_html}->{max_per_file})
			{
				$self->write_rendered_html_page($tweets_for_page);

				$tweets_for_page = [];
			}
		}

	}
	$self->write_rendered_html_page($tweets_for_page);


	my $rendered_html_filenames;
	foreach my $file ( reverse sort _most_recent_first @{$self->{document}->get_value('files')})
	{
		next unless $self->is_file_a($file,'rendered_html');
		push @{$rendered_html_filenames},$file->get_value('filename');
	}

	my $page = $self->{document}->repository->xhtml->page(
			{
				title => &{$file_types->{rendered_html_index}->{title}}($xml,$self),
				page => &{$file_types->{rendered_html_index}->{page}}($xml,$self),
			},
			template => $file_types->{rendered_html_index}->{template},
			);
	my $tmp = File::Temp->new;
	$page->write_to_file($tmp);
	my $filename = &{$file_types->{rendered_html_index}->{filename}};

	$self->{document}->add_file($tmp,$filename); 

	$self->{document}->set_main($filename);
	$self->{document}->commit;

}

sub write_rendered_html_page
{
	my ($self, $tweets_for_page) = @_;

	return unless scalar @{$tweets_for_page}; #do nothing if we have no tweets.

	my $xml = $self->{document}->repository->xml;

	my $low_tweet = $tweets_for_page->[0];
	my $high_tweet = $tweets_for_page->[$#{$tweets_for_page}];
	my $low_id = $xml->to_string(@{$low_tweet->findnodes('id/text()')}[0]);
	my $high_id = $xml->to_string(@{$high_tweet->findnodes('id/text()')}[0]);


	my $page_content = &{$file_types->{rendered_html}->{page}}($xml, $self, $tweets_for_page);
	my $page_title = &{$file_types->{rendered_html}->{title}}($xml, $self);
	my $page = $self->{document}->repository->xhtml->page(
			{title => $page_title,page => $page_content},
			template => $file_types->{rendered_html}->{template},
			);
	my $tmp = File::Temp->new;
	$page->write_to_file($tmp);
	my $filename = &{$file_types->{rendered_html}->{filename}}($low_id, $high_id);

	$self->{document}->add_file($tmp,$filename); 

}

sub _updatefile_to_dom
{
	my ($self, $file) = @_;

	return undef unless ($self->is_file_a($file, 'update')); # quick check

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


#used for sorting a list of files
sub _most_recent_first
{
	my $a_filename = $a->get_value('filename');
	$a_filename =~ m/^_to_([0-9]+)\./;
	my $a_sortvalue = $1 ? $1 : 0;

	my $b_filename = $b->get_value('filename');
	$b_filename =~ m/^_to_([0-9]+)\./;
	my $b_sortvalue = $1 ? $1 : 0;

	return $b_sortvalue <=> $a_sortvalue;
}


sub file_id_range
{
	my ($self, $file) = @_;

	return undef unless defined $file;

	if ($file->get_value('filename') =~ m/([0-9]+)_to_([0-9]+)\./)
	{
                return ($1, $2);
	}
	return undef;
}

#return the highest ID in the most recent parsable XML file
sub most_recent_file 
{
	my ($self, $type) = @_;

        my $files = $self->{document}->get_value('files');
	my $highest_id = 0;
	my $most_recent_file = undef;

	foreach my $file (@{$files})
	{
		next unless $self->is_file_a($file, $type);

		my @id_range = $self->file_id_range($file);
		next unless @id_range;

		my ($low_id, $high_id) = @id_range;

		if ( $high_id > $highest_id )
		{
			$highest_id = $high_id;
			$most_recent_file = $file;
		}

	}

	return $most_recent_file;
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

sub expand_urls
{
	my ($self, $tweet) = @_;

	my $message = $tweet->{text};
	return unless $message;

	my %URLs;
	my $ua = LWP::UserAgent->new(timeout => 5); 

	my $finder = URI::Find->new(sub{
		my($uri, $orig_uri) = @_;

		$URLs{$orig_uri}++;

		if (not $self->{uri_cache}->{$orig_uri})
		{
			$self->{uri_cache}->{$orig_uri} = 1;
			my $response = $ua->head($uri);

			my @redirects = $response->redirects;
			my @uri_chain;

			if (scalar @redirects)
			{
				foreach my $redirect (@redirects)
				{
					push @uri_chain, $redirect->request->uri->as_string;
				}
				push @uri_chain, $response->request->uri->as_string;

				foreach my $i (0 .. $#uri_chain-1)
				{
					$self->{uri_cache}->{$uri_chain[$i]} = $uri_chain[$i+1];
				}
			}
		}
	});
        $finder->find(\$message);

	my $redirects = [];
	my $loop_detector;
	URL: foreach my $url (keys %URLs)
	{
		my $url_tmp = $url;
		my $chain = [ $url_tmp ];
		my $loop_detector;
		REDIRECT: while ($self->{uri_cache}->{$url_tmp})
		{
			push @{$chain}, $self->{uri_cache}->{$url_tmp};

			last REDIRECT if ($loop_detector->{$url_tmp}); #should preserve the loop in the data
			$loop_detector->{$url_tmp} = 1;

			$url_tmp = $self->{uri_cache}->{$url_tmp};
		}
		push @{$redirects}, {redirect_chain =>$chain} if scalar @{$chain} >= 2; #a chain myst have at least two links
	}
	$tweet->{redirects} = $redirects if scalar @{$redirects} >= 1; #only add if there's at least one chain
}

#writes back to file
sub commit
{
	my ($self) = @_;

	if (scalar @{$self->{write_buffer}})
	{

		my $xml = $self->{document}->repository->xml;

		my $tweets_dom = $xml->create_element('tweets');

		my $highest_id = $self->{write_buffer}->[0]->{id};
		my $lowest_id = $self->{write_buffer}->[0]->{id};

		foreach my $tweet (sort { $a->{id} <=> $b->{id} } @{$self->{write_buffer}})
		{
			$highest_id = $tweet->{id} if $tweet->{id} > $highest_id; 
			$lowest_id = $tweet->{id} if $tweet->{id} < $lowest_id; 

			$self->expand_urls($tweet);

			my $tweet_dom = $xml->create_element('tweet');
			$tweets_dom->appendChild($tweet_dom);
			foreach my $k (keys %{$tweet})
			{
				$tweet_dom->appendChild($self->_generate_dom($xml, $k, $tweet->{$k}));
			}
		}

		my $filename = File::Temp->new;
		open FILE,">$filename" or print STDERR "Couldn't open $filename\n";
		binmode FILE, ":utf8"; 
		print FILE '<?xml version="1.0" encoding="utf-8" ?>', "\n";
		print FILE $xml->to_string($tweets_dom);
		close FILE;

		$self->{document}->add_file($filename, &{$file_types->{update}->{filename}}($lowest_id, $highest_id) );
		$xml->dispose($tweets_dom);

#only create a main file if we don't have one -- it could be a fairly hefty piece of work.
		if ($self->{document}->get_main ne &{$file_types->{rendered_html_index}->{filename}})
		{
			$self->create_main_file;
		}
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

sub file_header
{
	my ($self) = @_;

	return "Tweets Matching " . $self->{document}->get_value('twitter_hashtag') . "\n";
}

1;
