package EPrints::Plugin::Screen::Coversheet::Deprecate;

our @ISA = ( 'EPrints::Plugin::Screen::Coversheet' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_deprecate.png";

	$self->{appears} = [
		{
			place => "coversheet_manager_actions",
			position => 200,
		},
	];
	
	$self->{actions} = [qw/ deprecate cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	if ($self->{processor}->{coversheet}->get_value('status') ne 'active')
	{
		return 0;
	}

	return $self->allow( "coversheet/deprecate" );
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );

	$div->appendChild( $self->html_phrase("sure_deprecate",
		title=>$self->{processor}->{coversheet}->render_value('name') ) );

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		deprecate => $self->{session}->phrase(
				"lib/submissionform:action_deprecate" ),
		_order => [ "deprecate", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $div );
}	

sub allow_deprecate
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

	$self->{processor}->{screenid} = "Admin::CoversheetManager";
}

sub action_deprecate
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::CoversheetManager";

	$self->{processor}->{coversheet}->set_value('status', 'deprecated');
	$self->{processor}->{coversheet}->commit();

	$self->{processor}->add_message( "message", $self->html_phrase( "item_deprecated" ) );
}


1;
