package EPrints::Plugin::Screen::Admin::FormatsRisks_enact_plan;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new {
	my( $class, %params ) = @_;
 	
	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ enact_plan /];

	return $self;
}

sub action_enact_plan {
	my ( $self ) = @_;

	my $session = $self->{session};

	my $plan_id = $self->{session}->param( "plan_id" );

	my $format = $self->{session}->param( "format" );
	
	$session->dataset( "event_queue" )->create_dataobj({
		pluginid => "Event::Migration",
		action => "migrate",
		params => [$format, $plan_id],
		userid => $session->current_user(),
	});

	$self->{processor}->add_message(
			"message",
			$self->html_phrase( "success" )
			);

	$self->{processor}->{screenid} = "Admin::FormatsRisks";
	
}

sub allow_enact_plan
{
	my( $self ) = @_;
	return 1;
}

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

1;

