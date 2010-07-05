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
		template => 'default',
		page => sub
		{
			my ($xml, $feed) = @_;

			my $ol = $xml->create_element('ol');

			my $i = 0;
			foreach my $file ( sort { $feed->file_high_id($a) <=> $feed->file_high_id($b)} @{$feed->{document}->get_value('files')})
			{
				next unless $feed->is_file_a($file, 'rendered_html');

				my ($low_id, $high_id) = $feed->file_id_range($file);
				$i++;

				my $li = $xml->create_element('li');
				my $a = $xml->create_element('a', href => $file->get_value('filename'));
				$a->appendChild($xml->create_text_node("Page $i"));
				$li->appendChild($a);
	 			$li->appendChild($xml->create_text_node(": Tweets $low_id to $high_id"));
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
		template => 'default',
		page => sub
		{
#structure taken from Twitter:
#
#<ol id="timeline" class="statuses">
#<li class="hentry status search_result u-roi_vargas" id="status_17813071298">
#        <span class="status-body">
#                <span class="thumb vcard author">
#                        <a class="tweet-url profile-pic" href="http://twitter.com/roi_vargas"><img alt="Image_normal" src="http://a1.twimg.com/profile_images/969420202/image_normal.jpg"></a>
#                </span>
#                <a href="http://twitter.com/roi_vargas" class="username tweet-url screen-name">roi_vargas</a>
#                <span id="msgtxt17813071298" class="msgtxt eo">
#                        RT <a href="http://twitter.com/TAMY_69" class="username tweet-url">@TAMY_69</a>: LA MAMA DEL BABY DE <b>CRISTIANO</b> <b>RONALDO</b> <a class="tweet-url web" href="http://twitpic.com/22qp90">http://twitpic.com/22qp90</a>
#                </span>
#                <span class="meta entry-meta">
#                        <a href="http://twitter.com/roi_vargas/statuses/17813071298"> less than 20 seconds ago </a>
#                        <span class="source">
#                                via <a href="http://twitpic.com" rel="nofollow">Twitpic</a>
#                        </span>
#                </span>
#        </span>
#</li>

			my ($xml, $feed, $tweets_dom_arrayref) = @_; #tweets_dom contains tweets for this page
			my $frag = $xml->create_document_fragment();

			my $ol = $xml->create_element('ol', class => 'tweets');
			$frag->appendChild($ol);

			#make sure they're written to the file oldest first
			foreach my $tweet (@{$tweets_dom_arrayref})
			{
				my $bits = {};
				foreach my $fieldname (qw/ text text_expanded profile_image_url from_user id iso_language_code source created_at /)
				{
					my $n = @{$tweet->findnodes("$fieldname/text()")}[0];

					$bits->{$fieldname} = $xml->to_string( $n ) if $n;
				}

				my $html_tweet = $xml->create_element('li', class=>'tweet', id=>'tweet-'.$feed->value_or_filler($bits->{id}));
				my $tweet_body = $xml->create_element('span', class=>'tweet-body');
				$html_tweet->appendChild($tweet_body);

				my $thumbnail = $xml->create_element('span', class=>'author-thumb');
				my $a = $xml->create_element('a', href=>'http://twitter.com/' . $feed->value_or_filler($bits->{from_user}));
				$a->appendChild($xml->create_element('img', class=>'author-thumb', src=>$bits->{'profile_image_url'}));
				$thumbnail->appendChild($a);
				$tweet_body->appendChild($thumbnail);

				my $text_part = $xml->create_element('span', class=>'tweet-text-part');
				$tweet_body->appendChild($text_part);

				$a = $xml->create_element('a', href=>'http://twitter.com/' . $feed->value_or_filler($bits->{from_user}));
				$a->appendChild($xml->create_text_node($feed->value_or_filler($bits->{from_user})));
				$text_part->appendChild($a);

				$text_part->appendChild($xml->create_text_node(' '));

				my $text_span = $xml->create_element('span', class=>'text', id=>'tweet-'.$feed->value_or_filler($bits->{id}));
				#I'm not sure I'm doing this right, but I've found a way that works.  What's the EPrints way of doing this?
				use HTML::Entities;
				my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".decode_entities($bits->{'text_expanded'})."</fragment>" ); };
				if( $@ or not $bits->{'text_expanded'})
				{
					my $text = $xml->create_text_node($feed->value_or_filler($bits->{text}));
					$text_span->appendChild($text) if $text;
				}
				else
				{
					my $top = ($doc->getElementsByTagName( "fragment" ))[0];
					foreach my $node ( $top->getChildNodes )
					{
						$text_span->appendChild(
								$feed->{document}->repository->clone_for_me( $node, 1 ) );
					}
					EPrints::XML::dispose( $doc );
				}
				$text_part->appendChild($text_span);

				$text_part->appendChild($xml->create_text_node(' '));

				my $meta_span = $xml->create_element('span', class=>'meta');
				$meta_span->appendChild($xml->create_text_node($feed->value_or_filler($bits->{created_at})));
				$text_part->appendChild($meta_span);

				$ol->appendChild($html_tweet);
				
			}
			my $p = $xml->create_element('p', class=>'tweet-count');
			$p->appendChild($xml->create_text_node(scalar @{$tweets_dom_arrayref} . ' tweets'));
			$frag->appendChild($p);

			my $a = $xml->create_element('a', href => $MAINFILENAME );
			$a->appendChild($xml->create_text_node('back'));
			$frag->appendChild($a);

			return $frag;
		},
		title => sub
		{
			my ($xml, $feed) = @_;

			return $xml->create_text_node(
				'Results for Twitter search for ' . $feed->{document}->get_value('twitter_hashtag')
			);
		},
		max_per_file => 1000,
	},

};


sub value_or_filler
{
	my ($self, $value) = @_;
	return $value if defined $value;
	return 'UNDEFINED';
}

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

	foreach my $update_file (sort { $self->file_high_id($a) <=> $self->file_high_id($b) } @{$self->{document}->get_value('files')})
	{
		next unless $self->is_file_a($update_file, 'update'); #skip non-update_files

		next if ($self->file_high_id($update_file) < $lowest_id_to_render);

		my $tweets_dom = $self->_updatefile_to_dom($update_file);
		next unless $tweets_dom;

		foreach my $tweet ($tweets_dom->findnodes('//tweets/tweet'))
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
	$self->{document}->set_value('format', 'text/html');
	$self->{document}->commit;

}

sub write_rendered_html_page
{
	my ($self, $tweets) = @_;

	return unless scalar @{$tweets}; #do nothing if we have no tweets.

	my $xml = $self->{document}->repository->xml;

	#make sure they're lowest ID first
	my @tweets_for_page = sort
	{
		$xml->to_string(@{$a->findnodes("id/text()")}[0]) <=> $xml->to_string(@{$b->findnodes("id/text()")}[0])
	} @{$tweets};


	my $low_id = $xml->to_string(@{$tweets_for_page[0]->findnodes('id/text()')}[0]);
	my $high_id = $xml->to_string(@{$tweets_for_page[$#tweets_for_page]->findnodes('id/text()')}[0]);

	my $page_content = &{$file_types->{rendered_html}->{page}}($xml, $self, \@tweets_for_page);
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


sub file_high_id
{
	my ($self, $file) = @_;
	my ($low_id, $high_id) = $self->file_id_range($file);
	return $high_id;
}

sub file_low_id
{
	my ($self, $file) = @_;
	my ($low_id, $high_id) = $self->file_id_range($file);
	return $low_id;
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

	my $expanded_message = $message;

	my %URLs;
	my $ua = LWP::UserAgent->new(timeout => 5); 

	my $finder = URI::Find->new(sub{
		my($uri, $orig_uri) = @_;

		$URLs{$orig_uri}++;

		my $target_uri = $orig_uri;
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

				my $target_uri = $response->request->uri->as_string;

				foreach my $i (0 .. $#uri_chain-1)
				{
					$self->{uri_cache}->{$uri_chain[$i]} = $uri_chain[$i+1];
				}
			}
		}

		#escape HASH and AT symbols in the urls so that regexp for user and hashtag insertion don't change them
		$target_uri =~ s/#/ESCAPED_HASH/g;
		$target_uri =~ s/\@/ESCAPED_AT/g;
		$orig_uri =~ s/#/ESCAPED_HASH/g;
		$orig_uri =~ s/\@/ESCAPED_AT/g;


		return '<a href="'.$target_uri.'">'.$orig_uri.'</a>';
	});
        $finder->find(\$expanded_message);

	#now insert links to hashtags and usernames - how do we stop this from modifying text inside a long URL
	$expanded_message =~ s|\@([A-Za-z0-9-_]+)|<a href="http://twitter.com/$1">$&</a>|g;
	$expanded_message =~ s|#([A-Za-z0-9-_]+)|<a href="http://search.twitter.com/search?q=$1">$&</a>|g;

	#now unescape HASH and AT
	$expanded_message =~ s/ESCAPED_HASH/#/g;
	$expanded_message =~ s/ESCAPED_AT/\@/g;

	$tweet->{text_expanded} = "$expanded_message"; #should have all the links expanded out now.

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

sub file_header
{
	my ($self) = @_;

	return "Tweets Matching " . $self->{document}->get_value('twitter_hashtag') . "\n";
}

1;
