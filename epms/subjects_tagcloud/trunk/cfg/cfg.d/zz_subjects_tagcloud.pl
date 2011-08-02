push @{$c->{fields}{document}}, {
	name => "tags",
	type => "text",
	multiple => 1,
};
push @{$c->{fields}{eprint}}, {
	name => "document_tags",
	type => "subject",
	multiple => 1,
	top => "document_tags",
	browse_link => "document_tags",
};
push @{$c->{browse_views}}, {
	id => "document_tags",
	menus => [
	   {
		   fields => [ "document_tags" ],
		   hideempty => 1,
	   }
	],
	order => "creators_name/title",
	include => 1,
	variations => [
		"creators_name;first_letter",
		"type",
	],
};
$c->add_dataset_trigger( "eprint", EP_TRIGGER_BEFORE_COMMIT, sub {
	my %params = @_;

	my $eprint = $params{dataobj};

	my @tags;
	foreach my $doc ($eprint->get_all_documents)
	{
		foreach my $tag (@{$doc->value( "tags" )})
		{
			push @tags, $tag;
			$tags[$#tags] =~ s/^.*;\s*//; # only get the leaf part
		}
	}
	@tags = sort @tags; # order doesn't matter

	$eprint->set_value( "document_tags", \@tags );
});

# don't remove the following line
$c->{plugins}{"Event::AutoSubjects"}{params}{disable} = 0;
