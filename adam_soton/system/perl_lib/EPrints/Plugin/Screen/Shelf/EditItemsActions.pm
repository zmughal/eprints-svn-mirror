package EPrints::Plugin::Screen::Shelf::EditItemsActions;

our @ISA = ( 'EPrints::Plugin::Screen::Shelf' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ remove cancel reorder remove_all /];

	return $self;
}

sub properties_from
{
        my( $self ) = @_;

        $self->{processor}->{'_buffer_order'} =  $self->{session}->param( '_buffer_order' );
        $self->{processor}->{'_buffer_offset'} =  $self->{session}->param( '_buffer_offset' );

        $self->{processor}->{eprintid_list} = $self->{session}->param( "eprintid_list" );
	unless ($self->{processor}->{eprintid_list})
	{
		my $eprintids = [];
		foreach my $eprintid ( $self->{session}->param( 'eprintids' ) )
		{
			push @{$eprintids}, $eprintid;
		}
		$self->{processor}->{eprintid_list} = join('+',@{$eprintids});
	}
	my @eprintids = split(/[\+\s]/, $self->{processor}->{eprintid_list});
	$self->{processor}->{eprintids} = \@eprintids;

	$self->{processor}->{order} =  $self->{session}->param( 'order' );

        $self->SUPER::properties_from;
}

sub redirect_to_me_url
{
        my( $self ) = @_;

        return $self->SUPER::redirect_to_me_url .
        "&_buffer_order=" . $self->{processor}->{'_buffer_order'} .
        "&_buffer_offset=" . $self->{processor}->{'_buffer_offset'} .
	"&eprintid_list=" . $self->{processor}->{eprintid_list};
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->{processor}->{shelf}->has_editor($self->{processor}->{user});
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $div = $session->make_element( "div", class=>"ep_block" );

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
	);

	if (scalar @{$self->{processor}->{eprintids}})
	{
		$div->appendChild( $self->html_phrase("sure_delete") );
		my $ol = $session->make_element('ol');
		foreach my $eprintid (@{$self->{processor}->{eprintids}})
		{
			my $li = $session->make_element('li', style => "text-align: left;");
			my $eprint = EPrints::DataObj::EPrint->new($session, $eprintid);
			$li->appendChild($eprint->render_citation_link);
			$ol->appendChild($li);
		}
		$div->appendChild($ol);

		$buttons{remove} =  $self->{session}->phrase("lib/submissionform:action_remove");
		$buttons{_order} = [ "remove", "cancel" ];
	}
	else
	{
		my $message_content = $self->html_phrase('delete_all_warning');
		$div->appendChild($session->render_message('warning', $self->html_phrase('delete_all_warning')));

		$buttons{remove_all} =  $self->{session}->phrase("lib/submissionform:action_remove_all");
		$buttons{_order} = [ "remove_all", "cancel" ];
	}

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$form->appendChild($self->render_hidden_bits);
	$div->appendChild( $form );

	return( $div );
}	

sub allow_reorder
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_reorder
{
	my( $self ) = @_;
	my $session = $self->{session};
	my $shelf = $self->{processor}->{shelf};

	my $ids =  $shelf->get_value('items');

        my $ds = $session->get_repository->get_dataset( "eprint" );
        my $list = EPrints::List->new(
                session => $session,
                dataset => $ds,
                ids => $ids,
        );

	my $reordered_list = $list->reorder($self->{processor}->{order});
	my $reordered_ids = $reordered_list->get_ids;

	if (scalar @{$ids} == scalar @{$reordered_ids})
	{
		$shelf->set_value('items', $reordered_list->get_ids);
		$shelf->commit;
	}
	else
	{
		$self->{processor}->add_message( "warning", $self->html_phrase( "resort_count_mismatch" ) );
	}

	$self->{processor}->{screenid} = "Shelf::EditItems";
}

sub allow_remove_all
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_remove_all
{
	my( $self ) = @_;

	my $shelf = $self->{processor}->{shelf};

	$shelf->set_value('items',[]);
	$shelf->commit;
	$self->{processor}->add_message( "message", $self->html_phrase( "all_items_removed" ) );

	$self->{processor}->{screenid} = "Shelf::EditItems";
}

sub allow_remove
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_cancel
{
	my( $self ) = @_;

	return 1;
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Shelf::EditItems";
}

sub action_remove
{
	my( $self ) = @_;

        my $eprintids = $self->{processor}->{eprintids};

        $self->{processor}->{shelf}->remove_items(@{$eprintids});

	$self->{processor}->{screenid} = "Shelf::EditItems";
	$self->{processor}->add_message( "message", $self->html_phrase( "item_removed" ) );
}

sub render_hidden_bits
{
        my( $self ) = @_;

        my $chunk = $self->{session}->make_doc_fragment;

        $chunk->appendChild( $self->{session}->render_hidden_field( "eprintid_list", $self->{processor}->{eprintid_list} ) );
        $chunk->appendChild( $self->{session}->render_hidden_field( "_buffer_order", $self->{processor}->{_buffer_order} ) );
        $chunk->appendChild( $self->{session}->render_hidden_field( "_buffer_offset", $self->{processor}->{_buffer_offset} ) );

        $chunk->appendChild( $self->SUPER::render_hidden_bits );

        return $chunk;
}


1;
