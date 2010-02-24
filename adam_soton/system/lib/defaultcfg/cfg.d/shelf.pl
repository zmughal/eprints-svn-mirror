
#used to set global administration rights of shelves beyond the user list stored in the shelf metadata
$c->{'is_shelf_administrator'} = sub
{
	my ($shelf, $user) = @_;

	return 1 if $user->get_value('usertype') eq 'admin';
};

#eprint fields that a shelf can be reordered by
$c->{shelf_order_fields} = [ 'title', 'creators_name', 'date' ];

$c->{search}->{shelf} =
{
        search_fields => [
                { meta_fields => [ "title", ] },
                { meta_fields => [ "description", ] },
                { meta_fields => [ "shelfid", ] },
                { meta_fields => [ "userid", ] },
                { meta_fields => [ "public", ] },
                { meta_fields => [ "datestamp", ] },
        ],
        citation => "result",
        page_size => 20,
        order_methods => {
                "bytitle"         =>  "title",
                "bydate"         =>  "datestamp",
                "byrevdate"      =>  "-datestamp",
        },
        default_order => "byname",
        show_zero_results => 1,
};



