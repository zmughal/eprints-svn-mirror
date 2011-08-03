#
# Instructions
# 
# This package doesn't do anything without some configuration. Below is an
# example that adds tags to documents and an eprint browse-view based on the
# aggregate of each eprint's document-tags.
#
# When you've added your fields don't forget to update the database (or use the
# GUI metafield editing tool):
# 
#  ./bin/epadmin update [REPOID]
#
# For each configured field you will need to schedule a subjects-tree update:
#
#  ./tools/schedule --cron "15 12 * * *" [REPOID] AutoSubjects update \
#    [DATASETID] [FIELDID]
#
# Where DATASETID and FIELDID is the field containing the raw (user-entered)
# tags.
#
# The indexer will need to be running, or run an index manually:
#
#  ./bin/indexer --once --notdaemon start


###
# This example allows users to enter hierarchical tags into documents which are
# then used to generate an eprints browse view.
###

# The field users enter tags into
#push @{$c->{fields}{document}}, {
#	name => "tags",
#	type => "text",
#	multiple => 1,
#};
#
# Because the user-entered values are semi-colon separated we require another
# field to copy the leaf-value of each tag into:
#push @{$c->{fields}{eprint}}, {
#	name => "document_tags",
#	type => "subject",
#	multiple => 1,
#	top => "document_tags",
#	browse_link => "document_tags",
#};
#
# Add a browse-view over the leaf-values - similar to any other subject tree:
#push @{$c->{browse_views}}, {
#	id => "document_tags",
#	menus => [
#	   {
#		   fields => [ "document_tags" ],
#		   hideempty => 1,
#	   }
#	],
#	order => "creators_name/title",
#	include => 1,
#	variations => [
#		"creators_name;first_letter",
#		"type",
#	],
#};
#
# Populate the leaf-values on an eprint commit (or add this to your
# eprint_automatic_fields):
#$c->add_dataset_trigger( "eprint", EP_TRIGGER_BEFORE_COMMIT, sub {
#	my %params = @_;
#
#	my $eprint = $params{dataobj};
#
#	my @tags;
#	foreach my $doc ($eprint->get_all_documents)
#	{
#		foreach my $tag (@{$doc->value( "tags" )})
#		{
#			push @tags, $tag;
#			$tags[$#tags] =~ s/^.*;\s*//; # only get the leaf part
#		}
#	}
#	@tags = sort @tags; # order doesn't matter
#
#	$eprint->set_value( "document_tags", \@tags );
#});

# enable the AutoSubjects plugin
$c->{plugins}{"Event::AutoSubjects"}{params}{disable} = 0;
