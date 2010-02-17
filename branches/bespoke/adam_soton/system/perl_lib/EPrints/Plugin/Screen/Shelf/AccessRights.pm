package EPrints::Plugin::Screen::Shelf::AccessRights;

use EPrints::Plugin::Screen::Shelf::EditMetadata;

@ISA = ( 'EPrints::Plugin::Screen::Shelf::EditMetadata' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{icon} = "action_edit.png";

	$self->{appears} = [
		{
			place => "shelf_item_actions",
			position => 150,
		},
		{
			place => "shelf_view_actions",
			position => 150,
		},
	];

	

	return $self;
}

sub workflow_id
{
	return 'admin';
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->{processor}->{shelf}->has_admin($self->{processor}->{user});
}


1;
