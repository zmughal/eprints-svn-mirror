
package EPrints::Plugin::Screen::EPrint::View::Editor;

use EPrints::Plugin::Screen::EPrint::View;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::View' );

use strict;


sub who_filter { return 8; }

sub render_status
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );
	$div->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:staff_item_is_in_".$status ) );

	return $div;
}

sub render_common_action_buttons
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	return $self->render_action_list_bar( "eprint_actions_editor_$status", ['eprintid'] );
}


sub about_to_render 
{
	my( $self ) = @_;
}

1;

