package EPrints::Plugin::Screen::EPrint::Move;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	#	$self->{priv} = # no specific priv - one per action

	$self->{actions} = [qw/ move_inbox move_buffer move_archive move_deletion /];

	$self->{appears} = [
{ place => "eprint_actions", 	action => "move_archive", 	position => 400, },
{ place => "eprint_actions", 	action => "move_buffer", 	position => 500, },
{ place => "eprint_actions", 	action => "move_inbox", 	position => 600, },
{ place => "eprint_actions", 	action => "move_deletion", 	position => 700, },
{ place => "eprint_actions_editor_inbox", action => "move_buffer", position => 100, },
{ place => "eprint_actions_editor_buffer", action => "move_archive", position => 100, },
{ place => "eprint_actions_editor_archive", action => "move_buffer", position => 100, },
{ place => "eprint_actions_editor_archive", action => "move_deletion", position => 100, },
{ place => "eprint_actions_editor_deletion", action => "move_archive", position => 100, },
	];

	return $self;
}

sub about_to_render 
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}

sub allow_move_buffer
{
	my( $self ) = @_;

	return $self->allow( "eprint/move_buffer" );
}

sub action_move_buffer
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_buffer;

	$self->add_result_message( $ok );
}

sub allow_move_inbox
{
	my( $self ) = @_;

	return $self->allow( "eprint/move_inbox" );
}
sub action_move_inbox
{
	my( $self ) = @_;

	my $user = $self->{processor}->{eprint}->get_user();
	# We can't bounce it if there's no user associated 

	if( !defined $user )
	{
		$self->{session}->render_error( 
			$self->{session}->html_phrase( 
				"cgi/users/edit_eprint:no_user" ),
			"error" );
		return;
	}

	my $ok = $self->{processor}->{eprint}->move_to_inbox;

	$self->add_result_message( $ok );
}


sub allow_move_archive
{
	my( $self ) = @_;

	return $self->allow( "eprint/move_archive" );
}
sub action_move_archive
{
	my( $self ) = @_;

	my $ok = $self->{processor}->{eprint}->move_to_archive;

	$self->add_result_message( $ok );
}


sub allow_move_deletion
{
	my( $self ) = @_;

	return $self->allow( "eprint/move_deletion" );
}
sub action_move_deletion
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