package EPrints::Plugin::Screen::EPMC::tweepository;

use EPrints::Plugin::Screen::EPMC;
@ISA = ( 'EPrints::Plugin::Screen::EPMC' );

use strict;
# Make the plug-in
sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{actions} = [qw( enable disable )];
	$self->{disable} = 0; # always enabled, even in lib/plugins

	$self->{package_name} = "tweepository";

	return $self;
}

=item $screen->action_enable( [ SKIP_RELOAD ] )

Enable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_enable
{
	my( $self, $skip_reload ) = @_;

	$self->SUPER::action_enable( $skip_reload );

	my $repo = $self->{repository};

	EPrints::DataObj::EventQueue->create_unique( $repo, {
		pluginid => "Event",
		action => "cron",
		params => [
			"32 * * * *",
			"Event::UpdateTweetStreams",
			"action_update_tweetstreams",
		],
	});

	$self->reload_config if !$skip_reload;
}

=item $screen->action_disable( [ SKIP_RELOAD ] )

Disable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_disable
{
	my( $self, $skip_reload ) = @_;

	$self->SUPER::action_disable( $skip_reload );
	my $repo = $self->{repository};

	my $event = EPrints::DataObj::EventQueue->new_from_hash( $repo, {
		pluginid => "Event",
		action => "cron",
		params => [
			"32 * * * *",
			"Event::UpdateTweetStreams",
			"action_update_tweetstreams",
		],
	});
	$event->delete if (defined $event);


	$self->reload_config if !$skip_reload;
}

1;

