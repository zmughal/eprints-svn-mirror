package EPrints::Plugin::Screen::AddToShelf;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ add /];

	# is linked to by the BatchEdit export plugin
	$self->{appears} = [];

	return $self;
}

sub allow_add
{
	$_[0]->can_be_viewed
}

sub can_add
{
	$_[0]->can_be_viewed
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 1;

#	return $self->allow( "eprint/archive/edit" );
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $cacheid = $self->{processor}->{session}->param( "cache" );

	return $self->SUPER::redirect_to_me_url."&cache=$cacheid";
}

sub get_cache
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $cacheid = $session->param( "cache" );

	my $dataset = $session->get_repository->get_dataset( "cachemap" );
	my $cache = $dataset->get_object( $session, $cacheid );

	return $cache;
}

sub get_searchexp
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $cacheid = $session->param( "cache" );

	my $cache = $self->get_cache();

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $session->get_repository->get_dataset( "eprint" ),
		keep_cache => 1,
	);

	if( $searchexp )
	{
		$searchexp->from_string_raw( $cache->get_value( "searchexp" ) );
		$searchexp->{"cache_id"} = $cacheid;
	}

	return $searchexp;
}

sub action_add
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $shelfid = $session->param('shelfid');
	my $shelf;
	if ($shelfid eq '__new_shelf')
	{
		my $userid = $self->{processor}->{userid};
		$shelf = EPrints::DataObj::Shelf->create( $session, $userid );
	}
	else
	{
		$shelf = EPrints::DataObj::Shelf->new( $session, $shelfid );
	}
	if (not defined $shelf)
	{
		return;
	}


	my $searchexp = $self->get_searchexp;
	if( !$searchexp )
	{
		return;
	}

	my $list = $searchexp->perform_search;

	if( $list->count == 0 )
	{
		return;
	}

	my $eprintids = $list->get_ids;

	if ($shelf->is_set('items'))
	{
		my $items = $shelf->get_value('items');

		my $combined_items = [];
		my $items_added = {};

		#deduplicate items if we're adding to an existing shelf.
		foreach my $eprintid (@{$items},@{$eprintids})
		{
			next if ($items_added->{$eprintid});
			push @{$combined_items}, $eprintid;
			$items_added->{$eprintid} = 1;
		}

		$shelf->set_value('items', $combined_items)
	}
	else
	{
		$shelf->set_value('items', $eprintids);
	}
	$shelf->commit;


        $self->{processor}->{shelf} = $shelf;
        $self->{processor}->{shelfid} = $shelf->get_id;
        $self->{processor}->{screenid} = "Shelf::Edit";
}

sub render
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	my $searchexp = $self->get_searchexp;

	if( !defined $searchexp )
	{
		$processor->add_message( "error", $self->html_phrase( "invalid_cache" ) );
		return $page;
	}

	my $list = $searchexp->perform_search;

	if( $list->count == 0 )
	{
		$processor->add_message( "error", $session->html_phrase( "lib/searchexpression:noresults" ) );
		return $page;
	}

	$p = $session->make_element( "p" );
	$page->appendChild( $p );
	$p->appendChild( $searchexp->render_description );

	$p = $session->make_element( "p" );
	$page->appendChild( $p );
	$p->appendChild( $session->make_text(
		"Add " . $list->count . " items to a shelf (first 5 shown):"
	) );

	my $ul = $session->make_element( "ul" );
	$p->appendChild( $ul );

	my @eprints = $list->get_records( 0, 5 );
	foreach my $eprint (@eprints)
	{
		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );
		$li->appendChild( $eprint->render_citation_link( ) );
	}

	$page->appendChild( $self->render_shelf_choice_form($searchexp) );


	return $page;
}

sub render_shelf_choice_form
{
	my( $self, $searchexp ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};
	my $user = $processor->{user};

	my $chunk = $session->make_doc_fragment;

	my $dataset = $searchexp->get_dataset;
        my $div = $session->make_element( "div");

        my $form = $session->render_form( "post" );
        $form->appendChild( $session->render_hidden_field( "screen", $processor->{screenid} ) );
        $form->appendChild( $session->render_hidden_field( "cache",  $searchexp->get_cache_id, ) );

	my $shelfids = [ '__new_shelf' ];
	my $shelf_labels = { '__new_shelf' => 'New Shelf...' };


        ### Get the items the current user has rights to
        my $ds = $session->get_repository->get_dataset( "shelf" );

        my $searchexp = EPrints::Search->new(
                session => $self->{session},
                dataset => $ds,
                satisfy_all => 0, );

        foreach my $accesslevelfield (qw/ editorids adminids /)
        {
                $searchexp->add_field ($ds->get_field ($accesslevelfield), $session->current_user->get_id);
        }

        my $list = $searchexp->perform_search;

	#initial assumption - a user won't have a huge number of shelves, so get_records may be sufficient.
	my @shelves = $list->get_records;
	foreach my $shelf (@shelves)
	{
		push @{$shelfids}, $shelf->get_id;
		$shelf_labels->{$shelf->get_id} =  EPrints::Utils::tree_to_utf8($shelf->render_description);
	}

	
        $form->appendChild( $session->render_option_list(
                name => 'shelfid',
                height => 1,
                multiple => 0,
                'values' => $shelfids,
                labels => $shelf_labels ) );

        $form->appendChild(
                        $session->render_button(
                                class=>"ep_form_action_button",
                                name=>"_action_add",
                                value => $self->phrase( "add" ) ) );

        $div->appendChild( $form );


        $chunk->appendChild( $div );
        return $chunk;
}


1;
