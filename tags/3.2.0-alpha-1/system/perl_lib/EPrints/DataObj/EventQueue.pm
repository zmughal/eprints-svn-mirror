package EPrints::DataObj::EventQueue;

=head1 NAME

EPrints::DataObj::EventQueue - Scheduler queue

=head1 FIELDS

=over 4

=item eventqueueid

A unique id for this event.

=item datestamp

The date/time the event was created.

=item hash

A unique hash for this event.

=item unique

If set to true only one event of this type (pluginid/action/params) is allowed to be running.

=item oneshot

If set to true removes this event once it has finished by success or failure.

=item priority

The priority for this event.

=item start_time

The event should not be executed before this time.

=item end_time

The event was completed at this time.

=item due_time

Do not start this event if we have gone beyond due_time.

=item repetition

Repetition number of seconds will be added to start_time until it is greater than now and a new event created, when this event is completed.

=item status

The status of this event.

=item userid

The user (if any) that was responsible for creating this event.

=item description

A human-readable description of this event.

=item pluginid

The L<EPrints::Plugin::Event> plugin id to call to execute this event.

=item action

The name of the action to execute on the plugin (i.e. method name).

=item params

Parameters to pass to the action (a text serialisation).

=back

=cut

@ISA = qw( EPrints::DataObj );

use strict;

sub get_system_field_info
{
	return (
		{ name=>"eventqueueid", type=>"counter", sql_counter=>"eventqueueid", required=>1 },
		{ name=>"datestamp", type=>"timestamp", required=>1, },
		{ name=>"hash", type=>"text", sql_index=>1, },
		{ name=>"unique", type=>"boolean", },
		{ name=>"oneshot", type=>"boolean", },
		{ name=>"priority", type=>"int", },
		{ name=>"start_time", type=>"timestamp", required=>1, },
		{ name=>"end_time", type=>"time", },
		{ name=>"due_time", type=>"time", },
		{ name=>"repetition", type=>"int", sql_index=>0, },
		{ name=>"status", type=>"set", options=>[qw( waiting inprogress success failed )], default_value=>"waiting", },
		{ name=>"userid", type=>"itemref", datasetid=>"user", },
		{ name=>"description", type=>"longtext", },
		{ name=>"pluginid", type=>"text", required=>1, },
		{ name=>"action", type=>"text", required=>1, },
		{ name=>"params", type=>"storable", },
	);
}

sub get_dataset_id { "event_queue" }

sub create_unique
{
	my( $class, $session, $data, $dataset ) = @_;

	$dataset ||= $session->get_repository->get_dataset( $class->get_dataset_id );

	$data->{unique} = "TRUE";

	my $md5 = Digest::MD5->new;
	$md5->add( $data->{pluginid} );
	$md5->add( $data->{action} );
	$md5->add( EPrints::MetaField::Storable->freeze( $session, $data->{params} ) )
		if EPrints::Utils::is_set( $data->{params} );
	$data->{hash} = $md5->hexdigest;

	my $searchexp = EPrints::Search->new(
		dataset => $dataset,
		session => $session,
		filters => [
			{ meta_fields => [qw( hash )], value => $data->{hash} },
			{ meta_fields => [qw( status )], value => "waiting inprogress", match => "EQ", merge => "ANY" },
		]);
	my $count = $searchexp->perform_search->count;
	$searchexp->dispose;

	if( $count > 0 )
	{
		return undef;
	}

	return $class->create_from_data( $session, $data, $dataset );
}

=item $ok = $event->execute()

Execute the action this event describes.

=cut

sub execute
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $plugin = $session->plugin( $self->get_value( "pluginid" ) );
	if( !defined $plugin )
	{
		# no such plugin
		$session->log( "Plugin not available: ".$self->get_value( "pluginid" ) );
		return 0;
	}

	my $action = $self->get_value( "action" );
	if( !$plugin->can( $action ) )
	{
		$session->log( "No such method $action on ".ref($plugin) );
		return 0;
	}

	my $params = $self->get_value( "params" );
	if( !defined $params )
	{
		$params = [];
	}
	my @params = @$params;

	# expand any object identifiers
	foreach my $param (@params)
	{
		if( $param =~ m# ^/id/([^/]+)/(.+)$ #x )
		{
			my $dataset = $session->dataset( $1 );
			if( !defined $dataset )
			{
				$session->log( "Bad parameters: No such dataset '$1'" );
				return 0;
			}
			$param = $dataset->dataobj( $2 );
			if( !defined $param )
			{
				$session->log( "Bad parameters: No such item '$2' in dataset '$1'" );
				return 0;
			}
		}
	}

	$plugin->$action( @params );

	return 1;
}

1;
