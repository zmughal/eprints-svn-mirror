# By default there are no custom fields in document objects, but this file
# provides you with an example should you wish to (c.f. eprint_fields.pl)

$c->{fields}->{document} = [
#	{
#		name => "application",
#		type => "set",
#		options => [
#			'msword95',
#			'msword2000',
#			'msword2007',
#		],
#	},

	{
		name => 'twitter_hashtag',
		type => 'text',
	},
	{
		name => 'twitter_expiry_date',
		type => 'date',
	}

];
