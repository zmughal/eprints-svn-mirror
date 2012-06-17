#tidier screens achieved by having n divisible by cols
# n -> how many to store
# cols -> how many columns to render them
# max_len -> the maximum length of any rendered value before it gets truncated (currently doesn't apply to users)
# case_insensitive -> convert to lowercase
$c->{tweetstream_tops} = 
{
  top_from_users => {
    n => 30,
    cols => 3,
    case_insensitive => 1,
  },
  top_tweetees => {
    n => 32,
    cols => 4,
    case_insensitive => 1,
  },
  top_urls_from_text => {
    n => 30,
    cols => 1,
    max_len => 150,
  },
  top_hashtags => {
    n => 80,
    cols => 4,
    max_len => 15,
    case_insensitive => 1,
  }
};


#n_ parameters define how many appear before and after the ... in the middle
$c->{tweetstream_tweet_renderopts} = 
{
  n_oldest => 15,
  n_newest => 25,
};

$c->{roles}->{"tweetstream-admin"} = [
  "datasets",
  "tweetstream/view",
  "tweetstream/details",
  "tweetstream/edit",
  "tweetstream/create",
  "tweetstream/destroy",
  "tweetstream/export",
];
$c->{roles}->{"tweetstream-editor"} = [
  "datasets",
  "tweetstream/view",
  "tweetstream/details:owner",
  "tweetstream/edit:owner",
  "tweetstream/create",
  "tweetstream/destroy:owner",
  "tweetstream/export",
];
$c->{roles}->{"tweetstream-viewer"} = [
  "tweetstream/view",
  "tweetstream/export",  
];
push @{$c->{user_roles}->{admin}}, 'tweetstream-admin';
push @{$c->{user_roles}->{editor}}, 'tweetstream-editor';
push @{$c->{user_roles}->{user}}, 'tweetstream-viewer';

push @{$c->{browse_views}},
{
                id => "tweetstream_project",
                dataset => 'tweetstream',
                menus => [
                        {
                                fields => [ "project_title"],
                                new_column_at => [10,10],
                        }
                ],
		order => "title",
		allow_null => 1,
		include => 1,
                variations => ["DEFAULT"],

};


$c->{search}->{tweetstream} = 
{
	search_fields => [
		{ meta_fields => [ "title" ] },
		{ meta_fields => [ "project_title" ] },
		{ meta_fields => [ "abstract" ] },
		{ meta_fields => [ "tweet_count" ] },
	],
	preamble_phrase => "tweetsearch:preamble",
	title_phrase => "tweetsearch:title",
	citation => "default",
	page_size => 20,
	order_methods => {
		"bytitle" 	 => "title",
		"bysize" 	 => "tweet_count",
		"bysizedesc" 	 => "-tweet_count",
	},
	default_order => "bytitle",
	show_zero_results => 1,
};

