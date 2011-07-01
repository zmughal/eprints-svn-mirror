
$c->{roles}->{"tweetstream-editor"} = [
	"tweet/view",
	"tweet/details",
	"tweetstream/view",
	"tweetstream/details",
	"tweetstream/edit",
	"tweetstream/create",
	"tweetstream/destroy",
];
push @{$c->{user_roles}->{admin}}, 'tweetstream-editor';


