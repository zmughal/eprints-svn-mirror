package EPrints::Feed::Twitter;

my $MAINFILENAME = 'twitter.txt';

use LWP::UserAgent;
use URI::Find;

sub new
{
	my ($class, $document) = @_;

	return bless { 
		document => $document,
		write_buffer => [],
		tweets_in_main_file => 5000,
		uri_cache => {}, #for URL redirect lookups 
	}, $class;
}

sub create_main_file
{
	my ($self, $force) = @_;

	my $mainfile = $self->{document}->get_stored_file($MAINFILENAME);

	if ( $mainfile and !$force) #don't bother checking the datestamps if we don't have a twitter.txt or we are doing a force create
	{
		my $mainfiletime = 0;
		my $latestfiletime = 0;

		foreach my $file (@{$self->{document}->get_value('files')})
		{
			my $time_int = EPrints::Time::datestring_to_timet($self->{document}->{session}, $file->get_value('mtime'));

			if ($file->get_value('filename') eq $MAINFILENAME)
			{
				$mainfiletime = $time_int;
			}
			else
			{
				$latestfiletime = $time_int if $time_int > $latestfiletime;
			}
		}

		return if ($mainfiletime > $latestfiletime);
	}

	$mainfile->remove if $mainfile; #we're going to regenerate it.

	my $filename = File::Temp->new;
	open FILE,">$filename" or print STDERR "Couldn't open $filename\n";
	binmode FILE, ":utf8"; 
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

	$self->{document}->add_file($filename,$MAINFILENAME);
	$self->{document}->set_main($MAINFILENAME);
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

		if (not $uri_cache->{$orig_uri})
		{
			$uri_cache->{$orig_uri} = 1;
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
		foreach my $tweet (@{$self->{write_buffer}})
		{
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

		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		my $timestamp = sprintf("%04d%02d%02d%02d%02d%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);

		$self->{document}->add_file($filename, $timestamp . '.xml');
		$xml->dispose($tweets_dom);

#only create a main file if we don't have one -- it could be a fairly hefty piece of work.
		if ($self->{document}->get_main ne $MAINFILENAME)
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
