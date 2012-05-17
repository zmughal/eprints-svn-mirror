{
no warnings;

require EPrints::DataObj::BitTorrent;

sub EPrints::Script::Compiled::run_search_related
{
	my( $self, $state, $object, @required ) = @_;

	my $list = $object->[0]->search_related( map { $_->[0] } @required );

	return [ $list->slice, 'ARRAY' ];
}
}

$c->{datasets}->{bittorrent} = {
		sqlname => "bittorrent",
		class => "EPrints::DataObj::BitTorrent",
	};

$c->{plugins}{'Convert::BitTorrent'}{params}{disable} = 0;

$c->add_dataset_trigger( "document", EPrints::Const::EP_TRIGGER_FILES_MODIFIED, sub {
	my( %params ) = @_;

	my $repo = $params{repository};
	my $doc = $params{dataobj};

	$repo->dataset( "bittorrent" )->search(filters => [
			{ meta_fields => [qw( document )], value => $doc->id }
	])->map(sub {
		$_[2]->remove;
	});
	$doc->search_related( "isBitTorrentVersionOf" )->map(sub {
		(undef, undef, my $rdoc) = @_;

		$rdoc->remove;
	});

	my $plugin = $repo->plugin( "Convert::BitTorrent" );
	my $ndoc = $plugin->convert( $doc->parent, $doc, "application/x-bittorrent" );
	$ndoc->add_relation( $doc, "isBitTorrentVersionOf" );
	$ndoc->commit;

	my $info_hash = $ndoc->stored_file( "info_hash" );
	my $buffer = '';
	$info_hash->get_file(sub { $buffer .= $_[0]; 1 });
	$repo->dataset( "bittorrent" )->create_dataobj({
			bittorrentid => (unpack("H*", $buffer))[0],
			document => $doc->id,
		});

	return EPrints::Const::EP_TRIGGER_OK;
});
