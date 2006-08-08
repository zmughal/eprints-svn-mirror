package EPrints::Plugin::Screen::EPrint::Move;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	#	$self->{priv} = # no specific priv - one per action

	$self->{actions} = {
		"move_inbox_buffer" => "action/eprint/move_inbox_buffer",
		"move_buffer_inbox" => "action/eprint/move_buffer_inbox",
		"move_buffer_archive" => "action/eprint/move_buffer_archive",
		"move_archive_buffer" => "action/eprint/move_archive_buffer",
		"move_archive_deletion" => "action/eprint/move_archive_deletion",
		"move_deletion_archive" => "action/eprint/move_deletion_archive",
		"move_inbox_archive" => "action/eprint/move_inbox_archive",
		"move_archive_inbox" => "action/eprint/move_archive_inbox",
	};

	$self->{appears} = [
		{
			place => "eprint_actions",
			action => "move_inbox_buffer",
			position => 400,
		},
		{
			place => "eprint_actions",
			action => "move_buffer_inbox",
			position => 500,
		},
		{
			place => "eprint_actions",
			action => "move_buffer_archive",
			position => 600,
		},
		{
			place => "eprint_actions",
			action => "move_archive_buffer",
			position => 700,
		},
		{
			place => "eprint_actions",
			action => "move_archive_deletion",
			position => 800,
		},
		{
			place => "eprint_actions",
			action => "move_deletion_archive",
			position => 900,
		},
		{
			place => "eprint_actions",
			action => "move_inbox_archive",
			position => 1000,
		},
		{
			place => "eprint_actions",
			action => "move_archive_inbox" ,
			position => 1100,
		},
	];

	return $self;
}

sub about_to_render 
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}

sub action_move_inbox_buffer
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_buffer;

	$self->add_result_message( $ok );
}

sub action_move_archive_buffer
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_buffer;

	$self->add_result_message( $ok );
}


sub action_move_buffer_inbox
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_inbox;

	$self->add_result_message( $ok );
}

sub action_move_archive_inbox
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_inbox;

	$self->add_result_message( $ok );
}


sub action_move_deletion_archive
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_archive;

	$self->add_result_message( $ok );
}

sub action_move_buffer_archive
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_archive;

	$self->add_result_message( $ok );
}

sub action_move_inbox_archive
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_archive;

	$self->add_result_message( $ok );
}


sub action_move_archive_deletion
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_deletion;

	$self->add_result_message( $ok );
}



sub add_result_message
{
	my( $self, $ok ) = @_;

	if( $ok )
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "status_changed",
				status=>$self->{processor}->{eprint}->render_value( "eprint_status" ) ) );
	}
	else
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( 
				"cant_move",
				id => $self->{session}->make_text( 
					$self->{processor}->{eprintid} ) ) );
	}

	$self->{processor}->{screenid} = "EPrint::View";
}

1;
