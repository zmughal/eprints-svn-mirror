package EPrints::Plugin::Screen::Shelf::EPrint::MoveUp;

our @ISA = ( 'EPrints::Plugin::Screen::Shelf::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{action_icon} = { move_up => "multi_up.png" };

	$self->{appears} = [
		{
			place => "shelf_items_eprint_actions",
			position => 200,
			action => 'move_up',
		},
	];
	
	$self->{actions} = [qw/ move_up /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	my $shelf = $self->{processor}->{shelf};

	return 0 if ($shelf->get_value('items')->[0] == $self->{processor}->{eprintid}); #we don't want to see it if it's the top item

	return $shelf->has_editor($self->{processor}->{user});
}


sub allow_move_up
{
	my( $self ) = @_;

	return $self->can_be_viewed;
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

	$self->{processor}->{screenid} = "Shelf::EditItems";
	$self->{processor}->add_message( "message", $self->html_phrase( "item_moved" ) );
}


1;
