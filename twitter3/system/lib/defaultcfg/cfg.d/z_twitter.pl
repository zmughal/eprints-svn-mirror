
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
		n => 30,
		cols => 4,
		case_insensitive => 1,
	},
	top_target_urls => {
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
	n_oldest => 10,
	n_newest => 10,
};


$c->{roles}->{"tweetstream-editor"} = [
	"datasets",
	"tweet/view",
	"tweet/details",
	"tweetstream/view",
	"tweetstream/details:owner",
	"tweetstream/edit:owner",
	"tweetstream/create",
	"tweetstream/destroy:owner",
	"tweetstream/export",
];
push @{$c->{user_roles}->{admin}}, 'tweetstream-editor';
push @{$c->{user_roles}->{editor}}, 'tweetstream-editor';
push @{$c->{user_roles}->{user}}, 'tweetstream-editor';


$c->{datasets}->{tweet} =
{ 
	sqlname => "tweet",      
	class => "EPrints::DataObj::Tweet", 
	import => 1, 
	index => 1, 
};
$c->{datasets}->{tweetstream} =
{ 
	sqlname => "tweetstream",        
	class => "EPrints::DataObj::TweetStream", 
	import => 1, 
	index => 1, 
}, 

