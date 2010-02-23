package EPrints::Plugin::Screen::Shelf::EPrint::MoveDown;

our @ISA = ( 'EPrints::Plugin::Screen::Shelf::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{action_icon} = { move_down => "multi_down.png", spacer => "noicon.png" };

	$self->{appears} = [
		{
			place => "shelf_items_eprint_actions",
			position => 100,
			action => 'move_down',
		},
		{
			place => "shelf_items_eprint_actions",
			position => 100,
			action => 'spacer',
		},
	];
	
	$self->{actions} = [qw/ move_down spacer /];

	return $self;
}

sub allow_spacer
{
        my ( $self ) = @_;

        return !$self->allow_move_down;
}

sub action_spacer
{
        my ($self) = @_;
        $self->{processor}->{screenid} =  "Shelf::EditItems";
}

sub allow_move_down
{
	my( $self ) = @_;

	my $shelf = $self->{processor}->{shelf};
	my $items = $shelf->get_value('items');

	return 0 if ($items->[$#{$items}] == $self->{processor}->{eprintid}); #we don't want to see it if it's the bottom

	return $shelf->has_editor($self->{processor}->{user});
}

sub action_move_down
{
	my( $self ) = @_;

        my $eprintid = $self->{session}->param('eprintid');
	my $shelf = $self->{processor}->{shelf};

	my $items = EPrints::Utils::clone( $shelf->get_value('items') );

	for (my $i = 0; $i < $#{$items}; $i++)
	{
		my $j = $i+1;
		if ($items->[$i] == $eprintid)
		{
			my $temp = $items->[$i];
			$items->[$i] = $items->[$j];
			$items->[$j] = $temp;
			last;
		}
	}

	$shelf->set_value('items', $items);
	$shelf->commit();

#redirect so that refresh won't keep moving things.
        my $plugin_for_redirect = $self->{session}->plugin( 'Screen::Shelf::EditItems', processor=>$self->{processor} );
        $self->{processor}->{screenid} = "Shelf::EditItems";
        $self->{session}->redirect($plugin_for_redirect->redirect_to_me_url);

#	$self->{processor}->add_message( "message", $self->html_phrase( "item_moved" ) );
}


1;
