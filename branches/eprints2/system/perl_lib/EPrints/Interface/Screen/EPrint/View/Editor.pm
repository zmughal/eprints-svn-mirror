
package EPrints::Interface::Screen::EPrint::View::Editor;

use EPrints::Interface::Screen::EPrint::View;

@ISA = ( 'EPrints::Interface::Screen::EPrint::View' );

use strict;

sub new
{
	my( $class, $processor ) = @_;

	$class->SUPER::new( $processor );
}


sub set_title
{
	my( $self ) = @_;

	$self->{processor}->{title} = $self->{session}->make_text("Editor View of Item");
}

sub render_status
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	my $status_fragment = $self->{session}->make_doc_fragment;
	$status_fragment->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:item_is_in_".$status ) );

	my @staff_actions = ();
	foreach my $action (
		"reject_with_email",
		"move_inbox_buffer", 
		"move_buffer_archive",
		"move_archive_buffer", 
		"move_archive_deletion",
		"move_deletion_archive",
	) 
	{
		push @staff_actions, $action if( $self->allow( "action/eprint/$action" ) );
	}
	if( scalar @staff_actions )
	{
		my %buttons = ( _order=>[] );
		foreach my $action ( @staff_actions )
		{
			push @{$buttons{_order}}, $action;
			$buttons{$action} = $self->{session}->phrase( "priv:action/eprint/".$action );
		}
		my $form = $self->render_form;
		$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );
		$status_fragment->appendChild( $form );
	} 

	return $status_fragment;
#	return $self->{session}->render_toolbox( 
#			$self->{session}->make_text( "Status" ),
#			$status_fragment );
}

sub allow
{
	my( $self, $priv ) = @_;

	# Special case for the action tab when there is no possible actions

	if( $priv eq "view/eprint/actions" )
	{
		my @a = $self->get_allowed_actions;
		return 0 if( scalar @a == 0 );
	}

	my $allow_code = $self->{processor}->allow( $priv );

	# if we only have this because we're the owner then
	# don't allow this option.
	return 0 if( !( $allow_code & 8 ) );

	return $allow_code;
}


sub about_to_render 
{
	my( $self ) = @_;
}

sub can_be_viewed
{
	my( $self ) = @_;

	my $r = $self->{processor}->allow( "view/eprint/view/editor" );
	return 0 unless $r;

	return $self->SUPER::can_be_viewed;
}

1;

