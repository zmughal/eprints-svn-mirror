package EPrints::Plugin::Screen::Shelf::EPrint::MoveUp;

our @ISA = ( 'EPrints::Plugin::Screen::Shelf::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{action_icon} = { move_up => "multi_up.png", spacer => "noicon.png" };

	$self->{appears} = [
		{
			place => "shelf_items_eprint_actions",
			position => 200,
			action => 'move_up',
		},
		{
			place => "shelf_items_eprint_actions",
			position => 200,
			action => 'spacer',
		},
	];
	
	$self->{actions} = [qw/ move_up spacer /];

	return $self;
}


sub allow_spacer
{
	my ( $self ) = @_;

	return !$self->allow_move_up;
}

sub action_spacer
{
	my ($self) = @_;
	$self->{processor}->{screenid} =  "Shelf::EditItems";
}

sub allow_move_up
{
	my( $self ) = @_;

	my $shelf = $self->{processor}->{shelf};

	return 0 if ($shelf->get_value('items')->[0] == $self->{processor}->{eprintid}); #we don't want to see it if it's the top item

	return $shelf->has_editor($self->{processor}->{user});
}

sub action_move_up
{
	my( $self ) = @_;

        my $eprintid = $self->{session}->param('eprintid');
	my $shelf = $self->{processor}->{shelf};

	my $items = EPrints::Utils::clone( $shelf->get_value('items') );

	my $h = -1;
	for (my $i = 0; $i <= $#{$items}; $i++)
	{
		if ($items->[$i] == $eprintid)
		{
			my $temp = $items->[$i];
			$items->[$i] = $items->[$h];
			$items->[$h] = $temp;
			last;
		}
		$h = $i;
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
