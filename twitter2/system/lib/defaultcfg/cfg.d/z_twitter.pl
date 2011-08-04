
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


