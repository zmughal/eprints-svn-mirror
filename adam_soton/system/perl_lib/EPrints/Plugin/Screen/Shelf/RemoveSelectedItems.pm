package EPrints::Plugin::Screen::Shelf::RemoveSelectedItems;

our @ISA = ( 'EPrints::Plugin::Screen::Shelf' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ remove cancel /];

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

        $self->SUPER::properties_from;


#if there are no items to delete, bounce back to the shelf edit screen.
	unless (scalar @{$self->{processor}->{eprintids}})
	{
		$self->{processor}->{screenid} = "Shelf::EditItems";
		return;
	}
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

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		remove => $self->{session}->phrase(
				"lib/submissionform:action_remove" ),
		_order => [ "remove", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$form->appendChild($self->render_hidden_bits);
	$div->appendChild( $form );

	return( $div );
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
