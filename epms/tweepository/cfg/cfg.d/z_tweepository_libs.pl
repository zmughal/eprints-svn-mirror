$c->{plugins}{"Export::TweetStream::JSON"}{params}{disable} = 0;
$c->{plugins}{"Export::TweetStream::CSV"}{params}{disable} = 0;
$c->{plugins}{"Export::TweetStream::HTML"}{params}{disable} = 0;
$c->{plugins}{"Event::UpdateTweetStreams"}{params}{disable} = 0;
$c->{plugins}{"Event::EnrichTweets"}{params}{disable} = 0;
$c->{plugins}{"Screen::EPMC::tweepository"}{params}{disable} = 0;

#set up the datasets
$c->{datasets}->{tweet} = {
	class => "EPrints::DataObj::Tweet",
	sqlname => "tweet",
	sql_counter => "tweetid",
	import => 1,
	index => 1,
};

$c->{datasets}->{tweetstream} = {
	class => "EPrints::DataObj::TweetStream",
	sqlname => "tweetstream",
	sql_counter => "tweetstreamid",
	import => 1,
	index => 1,
};

#base metadata
$c->add_dataset_field( 'tweet', { name=>"tweetid", type=>"counter", required=>1, import=>0, can_clone=>1, sql_counter=>"tweetid" }, );
$c->add_dataset_field( 'tweet', { name=>"twitterid", type=>"bigint", required=>1 }, );
$c->add_dataset_field( 'tweet', { name=>"json_source", type=>"storable", required=>1, render_value => 'EPrints::DataObj::Tweet::render_json_source' }, ); #full source kept for futureproofing

#extracted tweet metadata
$c->add_dataset_field( 'tweet', { name=>"text", type=>"text" }, );
$c->add_dataset_field( 'tweet', { name=>"from_user", type=>"text", render_value => 'EPrints::DataObj::Tweet::render_from_user' }, );
$c->add_dataset_field( 'tweet', { name=>"from_user_id", type=>"bigint" }, );
$c->add_dataset_field( 'tweet', { name=>"profile_image_url", type=>"url", render_value => 'EPrints::DataObj::Tweet::render_profile_image_url' }, );
$c->add_dataset_field( 'tweet', { name=>"iso_language_code", type=>"text" }, );
$c->add_dataset_field( 'tweet', { name=>"source", type=>"text" }, );
$c->add_dataset_field( 'tweet', { name=>"created_at", type=>"time"}, );

#value added extraction and enrichment
$c->add_dataset_field( 'tweet', { name=>"text_is_enriched", type=>"boolean" }, );
$c->add_dataset_field( 'tweet', { name=>"text_enriched", type=>"longtext", render_value => 'EPrints::DataObj::Tweet::render_text_enriched' }, );
$c->add_dataset_field( 'tweet', { name=>"tweetees", type=>"text", multiple=>1 }, );
$c->add_dataset_field( 'tweet', { name=>"hashtags", type=>"text", multiple=>1 }, );
$c->add_dataset_field( 'tweet', { name=>"target_urls", type=>"url", multiple => 1 }, );
$c->add_dataset_field( 'tweet', { 
	name=>"url_redirects",
	type=>"compound",
	multiple=>1,
	fields=>[
		{
			sub_name=>"url",
			type=>"url",
		},
		{
			sub_name=>"redirects_to",
			type=>"url",
		},
	]
}, );
#a list of tweetstreams to which this tweet belongs
$c->add_dataset_field( 'tweet', { name=>"tweetstreams", type=>"itemref", datasetid=> 'tweetstream', required => 1, multiple => 1 }, );

#the tweetstreams in which this has a directly following tweet
#useful for (at least) detecting missing tweets in the feed.
$c->add_dataset_field( 'tweet', { name=>"has_next_in_tweetstreams", type=>"itemref", datasetid=> 'tweetstream', required => 1, multiple => 1 }, );
#a flag to prevent enrichment being done more than once on commit
$c->add_dataset_field( 'tweet', { name=>"newborn", type=>"boolean"}, );




$c->add_dataset_field( 'tweetstream', { name=>"tweetstreamid", type=>"counter", required=>1, import=>0, can_clone=>1, sql_counter=>"tweetstreamid" }, );
$c->add_dataset_field( 'tweetstream', { name=>"userid", type=>"itemref", datasetid=>"user", required=>1 }, );
$c->add_dataset_field( 'tweetstream', { name=>"search_string", type=>"text", required=>"yes" }, );
$c->add_dataset_field( 'tweetstream', { name=>"expiry_date", type=>"date", required=>"yes" }, );
$c->add_dataset_field( 'tweetstream', { name=>"tweet_count", type=>'bigint', volatile=>1}, );
$c->add_dataset_field( 'tweetstream', { name=>"oldest_tweets", type=>"itemref", datasetid=>'tweet', multiple => 1, render_value => 'EPrints::DataObj::TweetStream::render_tweet_field' }, );
$c->add_dataset_field( 'tweetstream', { name=>"newest_tweets", type=>"itemref", datasetid=>'tweet', multiple => 1, render_value => 'EPrints::DataObj::TweetStream::render_tweet_field' }, );
$c->add_dataset_field( 'tweetstream', { name=>"rendered_tweetlist", virtual=> 1, type=>"int", render_value => 'EPrints::DataObj::TweetStream::render_tweet_list' }, );
#digest information store anything that appears more than once.
$c->add_dataset_field( 'tweetstream', { 
	name => "top_hashtags", type=>"compound", multiple=>1,
	'fields' => [
	{
		'sub_name' => 'hashtag',
		'type' => 'text',
	},
	{
		'sub_name' => 'count',
		'type' => 'int',
	}],
	render_value => 'EPrints::DataObj::TweetStream::render_top_field',
},);
$c->add_dataset_field('tweetstream',  {
	name => "top_from_users", type=>"compound", multiple=>1,
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
	}],
	render_value => 'EPrints::DataObj::TweetStream::render_top_field',
},);
$c->add_dataset_field('tweetstream',  { name => "top_tweetees", type=>"compound", multiple=>1,
	'fields' => [
	{
		'sub_name' => 'tweetee',
		'type' => 'text',
	},
	{
		'sub_name' => 'count',
		'type' => 'int',
	}
	],
	render_value => 'EPrints::DataObj::TweetStream::render_top_field',
},);
$c->add_dataset_field('tweetstream',  { name => "top_target_urls", type=>"compound", multiple=>1,
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
	render_value => 'EPrints::DataObj::TweetStream::render_top_field',
},);

#for creation of the bar chart
$c->add_dataset_field( 'tweetstream', { name => "frequency_period", type => 'set', options => [ 'daily', 'weekly', 'monthly', 'yearly' ] }, );
$c->add_dataset_field( 'tweetstream', { name => "frequency_values", type => 'compound', multiple=>1,
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
	render_value => 'EPrints::DataObj::TweetStream::render_top_frequency_values',
},);

#for generating CSV, these store the highest count of each of the multiple fields
$c->add_dataset_field( 'tweetstream', { name => "hashtags_ncols", type=>'int', volatile => '1' }, );
$c->add_dataset_field( 'tweetstream', { name => "tweetees_ncols", type=>'int', volatile => '1' }, );
$c->add_dataset_field( 'tweetstream', { name => "target_urls_ncols", type=>'int', volatile => '1' }, );







{
package EPrints::DataObj::Tweet;

our @ISA = ( 'EPrints::DataObj' );

use EPrints;
use EPrints::Search;
use JSON;
use Date::Parse;
use URI::Find;
use HTML::Entities;

use strict;


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
		$session->get_repository->get_dataset( "tweet" ),
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
			$session->get_repository->get_dataset( "tweet" ) );
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

	my $new_tweet = $class->SUPER::create_from_data( $session, $data, $dataset );

	$new_tweet->update_triggers();
	
	if( scalar( keys %{$new_tweet->{changed}} ) > 0 )
	{
		# Remove empty slots in multiple fields
		$new_tweet->tidy;

		# Write the data to the database
		$session->get_database->update(
			$new_tweet->{dataset},
			$new_tweet->{data},
			$new_tweet->{changed} );
	}

	$session->get_database->counter_minimum( "tweetid", $new_tweet->get_id );

	return $new_tweet;
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::Tweet->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "tweet";
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

=item $tweet = EPrints::DataObj::Tweet::tweet_with_twitterid( $session, $twitterid )

Return the EPrints::tweet with the specified $twitterid, or undef if they
are not found.

=cut
######################################################################

sub tweet_with_twitterid
{
	my( $repo, $twitterid ) = @_;

	my $dataset = $repo->dataset( "tweet" );

	my $results = $dataset->search(
		filters => [
			{
				meta_fields => [qw( twitterid )],
				value => $twitterid, match => "EX"
			}
		]);

	return $results->item( 0 );
}


######################################################################
=pod

=item $tweet->commit( [$force] )

Write this object to the database.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

If this item is not in any tweetstreams, then remove it.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	$self->set_value('newborn', 'TRUE') if !$self->is_set('newborn');

	$self->update_triggers();

	if ($self->get_value('newborn') eq 'TRUE')
	{
		if ($self->is_set('json_source')) #should always be true, but just in case....
		{
			$self->process_json;
		}
		$self->set_value('tweetees', $self->tweetees);
		$self->set_value('hashtags', $self->hashtags);
		$self->set_value('newborn', 'FALSE');
		$self->set_value('text_is_enriched', 'FALSE');
	}

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

=item $success = $tweet->remove

Remove this tweet from the database.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	my $success = 1;

	# remove tweet record
	my $tweet_ds = $self->{session}->get_repository->get_dataset( "tweet" );
	$success = $success && $self->{session}->get_database->remove(
		$tweet_ds,
		$self->get_value( "tweetid" ) );
	
	return( $success );
}

sub add_to_tweetstream
{
	my ($self, $tweetstream) = @_;
	$self->add_to_tweeetstreamid($tweetstream->id);
}

#takes a scalar or hashref
sub add_to_tweetstreamid
{
	my ($self, $tweetstreamid) = @_;

	$self->set_value('tweetstreams', $self->dedup_add($self->value('tweetstreams'),$tweetstreamid));
}

#is there a break in the stream?
sub has_next_in_tweetstream
{
	my ($self, $tweetstreamid) = @_;

	return 0 unless $self->is_set('has_next_in_tweetstreams');

	foreach my $id (@{$self->value('has_next_in_tweetstreams')})
	{
		return 1 if $tweetstreamid == $id;
	}

	return 0;
}


#takes a scalar or arrayref of tweetstream ids and sets them to show there is no break in the tweetstream between this and the next
sub set_next_in_tweetstream
{
	my ($self, $tweetstreamid) = @_;

	$self->set_value('has_next_in_tweetstreams', $self->dedup_add($self->value('has_next_in_tweetstreams'),$tweetstreamid));
}

#takes an array ref and a (scalar or array ref) and returs an arrayref containing only one of each value
sub dedup_add
{
	my ($self, $arr_ref, $val) = @_;

	if (not ref $val)
	{
		$val = [$val];
	}

	push @{$arr_ref}, @{$val};

	my %dedup;
	foreach (@{$arr_ref})
	{
		$dedup{$_} = 1;
	}

	my @deduped = keys %dedup;

	return \@deduped;
}


#remove from the passed tweetstream

sub remove_from_tweetstream
{
	my ($self, $tweetstream) = @_;

	my $new_tweetstreams = [];

	foreach my $id (@{$self->get_value('tweetstreams')})
	{
		push @{$new_tweetstreams}, $id unless ( $id == $tweetstream->id );
	}

	if (scalar @{$new_tweetstreams})
	{
		$self->set_value('tweetstreams', $new_tweetstreams);
		$self->commit;
	}
	else
	{
		$self->remove;
	}
}


######################################################################
=pod

=item $success = $tweet->process_json

Extract tweet metadata from the source json

=cut
######################################################################

sub process_json
{
	my ( $self ) = @_;

	return 0 unless $self->is_set('json_source');

	my $tweet_data = $self->get_value('json_source');

	#pull the data out and stick it in metafields
	foreach my $fieldname (qw/ text from_user from_user_id profile_image_url iso_language_code source /)
	{
		if ($tweet_data->{$fieldname})
		{
			$self->set_value($fieldname, $tweet_data->{$fieldname});
		}

	}
	#convert created at to eprints timestame
	my $time = str2time($tweet_data->{created_at});
	$self->set_value('created_at',EPrints::Time::get_iso_timestamp($time));



	return 1;
}

sub tweetees
{
	my ($self) = @_;

	my $message = $self->get_value('text');
	return [] unless $message;

	my @tweetees = ($message =~ m/\@[A-Za-z0-9-_]+/g);
	return \@tweetees;
}

sub hashtags
{
	my ($self) = @_;

	my $message = $self->get_value('text');
	return [] unless $message;

	my @tags = ($message =~ m/#[A-Za-z0-9-_]+/g);
	return \@tags;
}

sub enrich_text
{
        my ($self, $uri_cache, $log_data) = @_;

        my $message = $self->get_value('text');
        return unless $message;

        my $expanded_message = $message;

	my @URLs;
        my %redirects;
        my $ua = LWP::UserAgent->new(timeout => 5);

        my $finder = URI::Find->new(sub{
                my($uri, $orig_uri) = @_;

                my $target_uri = $orig_uri;

		my @redirects;
		my $response;

		if ($uri_cache->{$uri})
		{
			@redirects = @{$uri_cache->{$uri}->{redirects}};
			$response = $uri_cache->{$uri}->{response};

			$log_data->{url_cache_lookups}++ if $log_data;
		}
		else
		{
			$response = $ua->head($uri);
			@redirects = $response->redirects;

			$uri_cache->{$uri}->{redirects} = \@redirects;
			$uri_cache->{$uri}->{response} = $response;

			$log_data->{url_follows}++ if $log_data;
		}

		if (scalar @redirects)
		{
			my @uri_chain;
			foreach my $redirect (@redirects)
			{
				push @uri_chain, $redirect->request->uri->as_string;
			}
			push @uri_chain, $response->request->uri->as_string;

			$target_uri = $response->request->uri->as_string;

			foreach my $i (0 .. $#uri_chain-1)
			{
				$redirects{$uri_chain[$i]} = $uri_chain[$i+1];
			}
		}

		push @URLs, $target_uri; 

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

        $self->set_value('text_enriched', "$expanded_message"); #should have all the links expanded out now.

        my $redirects = [];
        foreach my $url (keys %redirects)
        {
		push @{$redirects}, {url => $url, redirects_to => $redirects{$url}};
        }
	$self->set_value('url_redirects', $redirects);
	$self->set_value('target_urls', \@URLs);

	$self->set_value('text_is_enriched', 'TRUE');
}

sub render_li
{
	my ($self) = @_;

	my $xml = $self->{session}->xml;
	my $twitterid = $self->get_value('twitterid');

	my $li = $xml->create_element('li', class=>'tweet', id=>'tweet-' . $twitterid);
	$li->appendChild($self->render_span);
	return $li;
}


sub render_span
{
	my ( $self ) = @_;

	my $xml = $self->{session}->xml;

	my $twitterid = $self->get_value('twitterid');

	my $span = $xml->create_element('span', class=>'tweet-body');

	my $anchor = $xml->create_element('a', name => $twitterid);
	$span->appendChild($anchor);

	$span->appendChild($self->render_value('profile_image_url'));

	my $text_part = $xml->create_element('span', class=>'tweet-text-part');
	$span->appendChild($text_part);

	$text_part->appendChild($self->render_value('from_user'));

	$text_part->appendChild($xml->create_text_node(' '));

	my $text_span = $xml->create_element('span', class=>'text', id=>'tweet-'.$self->get_value('twitterid'));
	$text_part->appendChild($self->render_value('text_enriched'));

	$text_part->appendChild($xml->create_text_node(' '));

	my $meta_span = $xml->create_element('span', class=>'meta');
	$meta_span->appendChild($self->render_value('created_at'));
	$meta_span->appendChild($xml->create_element('br'));
	$meta_span->appendChild($xml->create_text_node('Tweet ID: ' . $self->get_value('twitterid')));
	$text_part->appendChild($meta_span);

	return $span;
}

sub render_json_source
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

	my $json = JSON->new->allow_nonref;
	my $json_data = $json->pretty->encode($value);
	return EPrints::Extras::render_preformatted_field($session, $field, $json_data, $alllangs , $nolink , $object);
}


sub render_profile_image_url
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

	my $xml = $session->xml;

	my $span = $xml->create_element('span', class=>'author-thumb');
	my $a = $xml->create_element('a', href=>'http://twitter.com/' . $object->get_value('from_user'));
	$a->appendChild($xml->create_element('img', height=>"48", width=>"48", class=>'author-thumb', src=>$value));
	$span->appendChild($a);

	return $span;
}

sub render_from_user
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

	my $xml = $session->xml;

	my $a = $xml->create_element('a', href=>'http://twitter.com/' . $value);
	$a->appendChild($xml->create_text_node($value));
	return $a;
}

sub render_text_enriched
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

	return $object->render_value('text') unless $value; #enrich_text may not have been called

	my $xml = $session->xml;

	my $text_span = $xml->create_element('span', class=>'text', id=>'tweet-'.$object->get_value('twitterid'));
#I'm not sure I'm doing this right, but I've found a way that works.  What's the EPrints way of doing this?

	my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".$value."</fragment>" ); };
#	my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".decode_entities($value)."</fragment>" ); };

	if( $@ )
	{
		$session->get_repository->log( "Error rendering text_enriched on tweet " . $object->get_id . " for text:\n\t$value\nError:\n\t$@" );

		return $object->render_value('text'); #fall back to the simple text value #fall back to the simple text value #fall back to the simple text value 
	}
	else
	{
		my $top = ($doc->getElementsByTagName( "fragment" ))[0];
		foreach my $node ( $top->getChildNodes )
		{
			$text_span->appendChild(
			$session->clone_for_me( $node, 1 ) );
		}
		EPrints::XML::dispose( $doc );
	}
	return $text_span;

}


sub data_for_export
{
	my ($self) = @_;

	my $data;

	if ($self->is_set('json_source'))
	{
		$data = $self->value('json_source');
	}
	else #should never be true, but let's have something to fall back to/
	{
		foreach my $fieldname (qw/ from_user text created_at /) 
		{
			$data->{$fieldname} = $self->value($fieldname) if $self->is_set($fieldname);
		}
	}
	foreach my $fieldname (qw/ text_enriched target_urls url_redirects /)
	{
		$data->{eprints_value_added}->{$fieldname} = $self->value($fieldname) if ($self->is_set($fieldname));
	}

	return $data;
}


1;


}


{
package EPrints::DataObj::TweetStream;

our @ISA = ( 'EPrints::DataObj' );

use EPrints;
use EPrints::Search;
use Date::Calc qw/ Week_of_Year Delta_Days Add_Delta_Days /;

use strict;

sub render_top_frequency_values
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

	#first find the highest to scale all others
	my $highest = 0;
	foreach (@{$value})
	{
		$highest = $_->{value} if $_->{value} > $highest;
	}

	my $table = $session->make_element('table', class=>"tweetstream_graph");

	foreach my $pair (@{$value})
	{
		my $tr = $session->make_element('tr');
		$table->appendChild($tr);
		my $th = $session->make_element('th');
		$tr->appendChild($th);
		$th->appendChild($session->make_text($pair->{label}));
		my $td = $session->make_element('td', class => "tweetstream_bar");

		my $width = int (($pair->{value} / $highest) * 100);
		my $div = $session->make_element('div', style => "width: $width%");
		$td->appendChild($div);
		$tr->appendChild($td);

		$td = $session->make_element('td');
		$td->appendChild($session->make_text($pair->{value}));
		$tr->appendChild($td);
	}
	return $table;
}


sub render_top_field
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

	my $rows;
	my $fieldname = $field->name;

	foreach my $single_value (@{$value})
	{
		my $tr = $session->make_element('tr');
		my $td = $session->make_element('td');
		$tr->appendChild($td);
		$td->appendChild(render_top_lhs($session, $fieldname, $single_value));
		$td = $session->make_element('td');
		$td->appendChild(render_top_rhs($session, $fieldname, $single_value));
		$tr->appendChild($td);

		push @{$rows}, $tr;
	}

	return columned_table($session, $rows, $session->config('tweetstream_tops',$fieldname,'cols'));
}


sub render_top_lhs
{
	my ($session, $fieldname, $stuff) = @_;

	if ($fieldname eq 'top_hashtags')
	{
		my $value = $stuff->{hashtag}; 
		
		my $max_render_len = $session->config('tweetstream_tops',$fieldname,'max_len'); 
		
		my $url = 'http://search.twitter.com/search?q=' . URI::Escape::uri_escape($value); 

		my $a = $session->make_element('a', href=>$url, title=>$value); 

		if (length $value > $max_render_len) 
		{ 
			my $chars = $max_render_len - 3; 
			$value = substr($value, 0, $chars) . '...'; 
		} 

		$a->appendChild($session->make_text($value)); 
		return $a;       
	};

	if ($fieldname eq 'top_target_urls')
	{
		my $value = $stuff->{target_url}; 
		
		my $max_render_len = $session->config('tweetstream_tops',$fieldname,'max_len'); 
		
		my $a = $session->make_element('a', href=>$value, title=>$value);

		if (length $value > $max_render_len) 
		{ 
			my $chars = $max_render_len - 3; 
			$value = substr($value, 0, $chars) . '...'; 
		} 

		$a->appendChild($session->make_text($value)); 
		return $a;       
	};

	if ($fieldname eq 'top_from_users')
	{
		my $base_url = 'http://twitter.com/';
		my $img_url = $stuff->{profile_image_url};
		my $user = $stuff->{from_user};

		my $a = $session->make_element('a', href=>$base_url . $user, title=> $user);
		$a->appendChild($session->make_element('img', height=>"48", width=>"48",src=>$img_url));
		return $a;
	}

	if ($fieldname eq 'top_tweetees')
	{
		my $base_url = 'http://twitter.com/';
		my $user = $stuff->{tweetee};

		my $a = $session->make_element('a', href=>$base_url . $user, title=> $user);
		$a->appendChild($session->make_text($user));
		return $a;
	}
	#we should never get here
	return $session->make_text("$fieldname unhandled in render_top_lhs\n");
}

sub render_top_rhs
{
	my ($session, $fieldname, $stuff) = @_;

	if ($fieldname eq 'top_from_users')
	{
		my $frag = $session->make_doc_fragment;

		my $base_url = 'http://twitter.com/';
		my $img_url = $stuff->{profile_image_url};
		my $user = $stuff->{from_user};

		my $a = $session->make_element('a', href=>$base_url . $user, title=> $user);
		$a->appendChild($session->make_text($user));
		$frag->appendChild($a);
		$frag->appendChild($session->make_element('br'));
		$frag->appendChild($session->make_text($stuff->{count} . ' tweets'));
		return $frag;
	}
	else
	{
		return $session->make_text($stuff->{count});
	}
}

sub columned_table
{
	my ($session, $rows, $ncols ) = @_;

	my $nitems = scalar @{$rows};
	my $col_len = POSIX::ceil( $nitems / $ncols );

	my $table = $session->make_element('table');
	my $tr = $session->make_element('tr');
	$table->appendChild($tr);

	my $inside_table;
	for( my $i=0; $i < $nitems; ++$i )
        {

                if( $i % $col_len == 0 )
		{
			my $td = $session->make_element('td', valign => 'top');
			$tr->appendChild($td);

			$inside_table = $session->make_element('table');
			$td->appendChild($inside_table);

		}
		$inside_table->appendChild($rows->[$i]);
	}
	return $table;
}


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

#bugfix
$session->{xhtml} = $session->xhtml;

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

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}

	my $success = $self->SUPER::commit( $force );
	
	return( $success );
}


#mapping a function on the dataset may not be scalable.  Check how it works with half a million tweets.  We may need to optimise this, as it's done at every update.  Direct MySQL query may be necessary.
sub generate_tweet_digest
{
	my ($self) = @_;

	my $tweets = $self->tweets; 
	my $tweet_count = $tweets->count;

	if ($tweets->count)
	{
		$self->set_value('tweet_count', $tweet_count);
	}

	if ($tweet_count)
	{
		my $n_oldest = $self->repository->config('tweetstream_tweet_renderopts','n_oldest');
		my $n_newest = $self->repository->config('tweetstream_tweet_renderopts','n_newest');

		$n_oldest = 10 unless $n_oldest;
		$n_newest = 10 unless $n_newest;


		if ( $tweet_count < ( $n_oldest + $n_newest ))
		{
			$self->set_value('oldest_tweets', $tweets->get_ids  )
		}
		else
		{
			my $oldest_ids = $tweets->get_ids( 0 , $n_oldest );
			my $newest_ids = $tweets->get_ids( ($tweets->count - 1) - $n_newest, $n_newest);

			$self->set_value('oldest_tweets',$oldest_ids);
			$self->set_value('newest_tweets',$newest_ids);
		}
	}

	#grab the counts and anything else we need
	my $digest_data = {
		'counter' => {},
		'extra_data' => {},
		'muliplicity_counts' => {}, #for CSV export, let's find out how multiple the multiple fields are.
	};

	$tweets->map(\&EPrints::DataObj::TweetStream::_generate_tweet_digest_data, $digest_data);

	#top counts
	foreach my $top_val_name (qw/ from_user hashtag target_url tweetee /)
	{
		my $n = $self->{session}->config('tweetstream_tops', 'top_'.$top_val_name.'s', 'n');

		my $counts = [];
		foreach my $thing (
			sort
			{$digest_data->{counter}->{$top_val_name.'s'}->{$b} <=> $digest_data->{counter}->{$top_val_name.'s'}->{$a}}
			keys %{$digest_data->{counter}->{$top_val_name.'s'}}
		)
		{
			last unless $n;
			$n--;
			my $count = { $top_val_name => $thing, count => $digest_data->{counter}->{$top_val_name.'s'}->{$thing} };
			if ($top_val_name eq 'from_user')
			{
				$count->{'profile_image_url'} = $digest_data->{extra_data}->{'profile_image_url'}->{$thing};
			}
			push @{$counts}, $count;
		}

		$self->set_value('top_' . $top_val_name . 's', $counts);
	}

	#multiplicity (for CSV)
	foreach my $fieldname (qw/ hashtags tweetees target_urls /)
	{
		$self->set_value($fieldname . '_ncols', $digest_data->{multiplicity_counts}->{$fieldname});
	}

	#create the time graph values
	my $times = [];
	#may need optimisation -- if we work out the time periods first, we can fill them up without needing to store a date for each item
	#alternatively, just count the number of tweets per day, that should be a lot more manageable.
	$tweets->map( sub
	{
		my ($repository, $ds, $tweet, $times) = @_;
		push @{$times}, $tweet->get_value('created_at') if $tweet->is_set('created_at');
	}, $times);

	my ($period, $pairs) = $self->periodise_dates($times);

	$self->set_value('frequency_period',$period);
	$self->set_value('frequency_values',$pairs);

}

sub _generate_tweet_digest_data
{
	my ($repository, $ds, $tweet, $digest_data) = @_;


#we should be able to just read this from the database
	my $twitterid = $tweet->get_value('twitterid');

#accumulate data
	foreach my $top_val_name (qw/ from_users hashtags target_urls tweetees /)
	{
		my $val;
		if ($top_val_name eq 'from_users')
		{
			$val = $tweet->get_value('from_user');
		}
		else
		{
			$val = $tweet->get_value($top_val_name);
		}

		next unless defined $val;

		if (ref $val eq 'ARRAY')
		{
			$digest_data->{multiplicity_counts}->{$top_val_name} = 0 unless defined $digest_data->{multiplicity_counts}->{$top_val_name};
			$digest_data->{multiplicity_counts}->{$top_val_name} = (scalar @{$val}) if $digest_data->{multiplicity_counts}->{$top_val_name} < scalar @{$val};

			foreach my $thing (@{$val})
			{
				if ($repository->config('tweetstream_tops',"top_$top_val_name",'case_insensitive'))
				{
					$thing = lc($thing);
				}
				$digest_data->{counter}->{$top_val_name}->{$thing}++;
			}
		}
		else
		{
			if ($repository->config('tweetstream_tops',"top_$top_val_name",'case_insensitive'))
			{
				$val = lc($val);
			}
			$digest_data->{counter}->{$top_val_name}->{$val}++;
		}

	}
	if ($tweet->is_set('from_user'))
	{
		my $username = $tweet->get_value('from_user');
		$username = lc($username) if $repository->config('tweetstream_tops',"top_from_users",'case_insensitive');
		$digest_data->{extra_data}->{'profile_image_url'}->{$username} = $tweet->get_value('profile_image_url');
	}
}


sub tweets
{
	my ($self) = @_;

	my $ds = $self->repository->dataset('tweet');

	my $search = $ds->prepare_search;
	$search->add_field($ds->get_field('tweetstreams'), $self->id);
	$search->set_property('custom_order', 'twitterid');

	return $search->perform_search;
}

#returns the csv columns of a *Tweet* object, and the max multiplicity for this stream for each field
sub csv_cols
{
	my ($self) = @_;

	return
	[
		{ fieldname => "twitterid", ncols => 1 },
		{ fieldname => "from_user", ncols => 1 },
		{ fieldname => "from_user_id", ncols => 1 },
		{ fieldname => "created_at", ncols => 1 },
		{ fieldname => "text", ncols => 1 },
		{ fieldname => "profile_image_url", ncols => 1 },
		{ fieldname => "iso_language_code", ncols => 1 },
		{ fieldname => "source", ncols => 1 },
		{ fieldname => "text_enriched", ncols => 1 },
		{ fieldname => "tweetees", ncols => ( $self->get_value('tweetees_ncols') ? $self->get_value('tweetees_ncols') : 1 ) },
		{ fieldname => "hashtags", ncols => ( $self->get_value('hashtags_ncols') ? $self->get_value('hashtags_ncols') : 1 ) },
		{ fieldname => "target_urls", ncols => ( $self->get_value('target_urls_ncols') ? $self->get_value('target_urls_ncols') : 1 ) },
	];
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
	foreach my $period_candidate (qw/ monthly weekly daily /)
	{
		$period = $period_candidate if $delta_days <= $thresholds->{$period_candidate};
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

	my $tweets = $self->tweets;
	$tweets->map( sub
	{
		my ($repo, $ds, $tweet, $tweetstream) = @_;
		$tweet->remove_from_tweetstream($self);
	}, $self);

	# remove tweetstream record
	my $tweetstream_ds = $self->{session}->get_repository->get_dataset( "tweetstream" );
	$success = $success && $self->{session}->get_database->remove(
		$tweetstream_ds,
		$self->get_value( "tweetstreamid" ) );
	
	return( $success );
}

#a parallel list of tweet ids (due to a utf8 issue) will be rendered as the number of tweets.
sub render_tweetcount
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

        my $xml = $session->xml;
	my $frag = $xml->create_document_fragment;
	$frag->appendChild($xml->create_text_node(scalar @{$value} . ' tweets'));

	return $frag;
}

sub render_tweet_field
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

        my $xml = $session->xml;
	my $tweet_ds = $session->dataset('tweet');
	my $frag = $xml->create_document_fragment;

	my $ol = $xml->create_element('ol', class => 'tweets');
	$frag->appendChild($ol);

	foreach my $tweetid (@{$value})
	{
		my $tweet = $tweet_ds->dataobj($tweetid);
		$ol->appendChild($tweet->render_li);
	}
	return $frag;
}


sub render_tweet_list
{
        my( $repository , $field , $value , $alllangs , $nolink , $object ) = @_;

        my $xml = $repository->xml;
	my $tweet_ds = $repository->dataset('tweet');
	my $frag = $xml->create_document_fragment;

	$frag->appendChild($object->render_exporters);

	$frag->appendChild($object->render_value('oldest_tweets'));

	if ($object->is_set('newest_tweets')) #will only be set if weh have more than n_oldest + n_newest tweets
	{
		my $n_oldest = $repository->config('tweetstream_tweet_renderopts','n_oldest');
		my $n_newest = $repository->config('tweetstream_tweet_renderopts','n_newest');

		my $span = $xml->create_element('span', style => "margin-top: 1em; margin-bottom: 1em;");
		$span->appendChild($repository->html_phrase('DataObj::Tweet/unshown_items', n=>$xml->create_text_node(($object->value('tweet_count') - ($n_oldest+$n_newest)))));
		$frag->appendChild($span);
		$frag->appendChild($object->render_value('newest_tweets'));
	}

	return $frag;
}


sub render_exporters
{
	my ($self) = @_;

	my $repository = $self->repository;
	my $xml = $repository->xml;

	my $export_ul = $xml->create_element('ul');
	foreach my $pluginid (qw/ Export::TweetStream::JSON Export::TweetStream::CSV Export::TweetStream::HTML /)
	{
		my $plugin = $repository->plugin($pluginid);
		next unless $plugin;

		my $li = $xml->create_element( "li" );
		my $url = $plugin->dataobj_export_url( $self );
		my $a = $repository->render_link( $url );
		$a->appendChild( $plugin->render_name );
		$li->appendChild( $a );
		$export_ul->appendChild( $li );

	}
	return ($repository->html_phrase('TweetStream/export_menu', export_list => $export_ul));

	
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

sub data_for_export
{
	my ($self) = @_;

	my $data;

	foreach my $fieldname (qw/ search_string top_hashtags top_from_users top_tweetees top_target_urls /)
	{
		$data->{$fieldname} = $self->value($fieldname) if $self->is_set($fieldname);
	}

	return $data;
}

1;
}

