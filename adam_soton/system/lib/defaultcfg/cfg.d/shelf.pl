
#used to set global administration rights of shelves beyond the user list stored in the shelf metadata
$c->{'is_shelf_administrator'} = sub
{
	my ($shelf, $user) = @_;

	return 1 if $user->get_value('usertype' eq 'admin');
}
