package EPrints::DataObj::Tweet;

@ISA = ( 'EPrints::DataObj' );

use EPrints;
use EPrints::Search;
use JSON;
use Date::Parse;
use URI::Find;

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
		{ name=>"tweetid", type=>"counter", required=>1, import=>0, can_clone=>1,
			sql_counter=>"tweetid" },

		{ name=>"twitterid", type=>"bigint", required=>1 },

		{ name=>"json_source", type=>"longtext", required=>1, render_value => 'EPrints::Extras::render_preformatted_field' }, #full source kept for futureproofing

		{ name=>"text", type=>"text" },
		{ name=>"from_user", type=>"text", render_value => 'EPrints::DataObj::Tweet::render_from_user' },
		{ name=>"profile_image_url", type=>"url", render_value => 'EPrints::DataObj::Tweet::render_profile_image_url' },
		{ name=>"iso_language_code", type=>"text" },
		{ name=>"source", type=>"text" },
		{ name=>"created_at", type=>"time"},

		{ name=>"text_enriched", type=>"longtext", render_value => 'EPrints::DataObj::Tweet::render_text_enriched' },

		
		{ name=>"target_urls", type=>"url", multiple => 1 },
		{ 
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
		}
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

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

print STDERR "Committing Tweet\n";

	$self->update_triggers();

	if ($self->is_set('json_source'))
	{
		$self->process_json;
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

Remove this tweet from the database. Also, remove their saved searches,
but do not remove their eprints.

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

	my $json = $self->get_value('json_source');

	my $tweet_data = eval { decode_json($json); };
	if ($@)
	{
		print STDERR "Couldn't decode json: $@\n";
		return 0;
	}

	#pull the data out and stick it in metafields
	foreach my $fieldname (qw/ text from_user profile_image_url iso_language_code source /)
	{
		if ($tweet_data->{$fieldname})
		{
			$self->set_value($fieldname, $tweet_data->{$fieldname});
		}

	}
	#convert created at to eprints timestame
	my $time = str2time($tweet_data->{created_at});
	$self->set_value('created_at',EPrints::Time::get_iso_timestamp($time));

	#enrich text
	$self->enrich_text;


	return 1;
}

sub get_hashtags
{
	my ($self) = @_;

	my $message = $self->get_value('text');
	return [] unless $message;

	my @tags = ($message =~ m/#[A-Za-z0-9-_]+/g);
	return \@tags;
}

sub get_urls
{
        my ($self) = @_;

        my $message = $self->get_value('text');
        return unless $message;


}

sub enrich_text
{
        my ($self) = @_;

        my $message = $self->get_value('text');
        return unless $message;

        my $expanded_message = $message;

	my @URLs;
        my %redirects;
        my $ua = LWP::UserAgent->new(timeout => 5);

        my $finder = URI::Find->new(sub{
                my($uri, $orig_uri) = @_;

                my $target_uri = $orig_uri;

		my $response = $ua->head($uri);
		my @redirects = $response->redirects;

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
}


sub tweetstream_list
{
        my( $self, %opts ) = @_;

        my $dataset = $self->{session}->get_repository->get_dataset( "tweetstream" );

        my $searchexp = EPrints::Search->new(
                session => $self->{session},
                dataset => $dataset,
                %opts );

	$searchexp->add_field( $dataset->get_field( "items" ), $self->get_id );

	return $searchexp->perform_search;
}


######################################################################
=pod

=item $tweetid = EPrints::DataObj::Tweet->error_id( $session, $errorid )

Returns the id of a tweet object that can be rendered in a tweet stream
as an error.  Error codes are stored in the twitter_id field and are
negative.

If a tweet object with a given errorid does not exist, it is created.

Errors:

-1	Tweets missing from stream.

=cut
######################################################################
sub error_id
{
        my ($session, $errorid) = @_;

	$errorid = -1 unless $errorid;


        my $tweet = EPrints::DataObj::Tweet::tweet_with_twitterid($session, $errorid);

        if (not defined $tweet)
	{
		my $data = {
			twitterid => $errorid,
			text => $session->phrase("DataObj::Tweet::error_text_$errorid"),
			from_user => "EPRINTS",
		};

		$tweet = EPrints::DataObj::Tweet::new_from_data(
			$data,
		);
	}

        return $tweet->get_id;
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

sub render_profile_image_url
{
        my( $session , $field , $value , $alllangs , $nolink , $object ) = @_;

	my $xml = $session->xml;

	my $span = $xml->create_element('span', class=>'author-thumb');
	my $a = $xml->create_element('a', href=>'http://twitter.com/' . $object->get_value('from_user'));
	$a->appendChild($xml->create_element('img', class=>'author-thumb', src=>$value));
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

	my $xml = $session->xml;

	my $text_span = $xml->create_element('span', class=>'text', id=>'tweet-'.$object->get_value('twitterid'));
#I'm not sure I'm doing this right, but I've found a way that works.  What's the EPrints way of doing this?
	use HTML::Entities;
	my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".decode_entities($value)."</fragment>" ); };
#	my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".decode_entities($value)."</fragment>" ); };

	if( $@ or not $value)
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


1;

######################################################################
=pod

=back

=cut

