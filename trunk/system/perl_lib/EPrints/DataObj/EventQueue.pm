package EPrints::DataObj::EventQueue;

=head1 NAME

EPrints::DataObj::EventQueue - Scheduler queue

=head1 FIELDS

=over 4

=item eventqueueid

A unique id for this event.

=item hash

A unique hash for this event.

=item cleanup

If set to true removes this event once it has finished by success or failure. Defaults to true.

=item priority

The priority for this event.

=item start_time

The event should not be executed before this time.

=item end_time

The event was last touched at this time.

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
		{ name=>"hash", type=>"id", sql_index=>1, },
		{ name=>"cleanup", type=>"boolean", default_value=>"TRUE", },
		{ name=>"priority", type=>"int", },
		{ name=>"start_time", type=>"timestamp", required=>1, },
		{ name=>"end_time", type=>"time", },
		{ name=>"status", type=>"set", options=>[qw( waiting inprogress success failed )], default_value=>"waiting", },
		{ name=>"userid", type=>"itemref", datasetid=>"user", },
		{ name=>"description", type=>"longtext", },
		{ name=>"pluginid", type=>"id", required=>1, },
		{ name=>"action", type=>"id", required=>1, },
		{ name=>"params", type=>"storable", },
	);
}

sub get_dataset_id { "event_queue" }

sub create_unique
{
	my( $class, $session, $data, $dataset ) = @_;

	$dataset ||= $session->dataset( $class->get_dataset_id );

	my $md5 = Digest::MD5->new;
	$md5->add( $data->{pluginid} );
	$md5->add( $data->{action} );
	$md5->add( EPrints::MetaField::Storable->freeze( $session, $data->{params} ) )
		if EPrints::Utils::is_set( $data->{params} );
	$data->{hash} = $md5->hexdigest;

	my $results = $dataset->search(
		filters => [
			{ meta_fields => [qw( hash )], value => $data->{hash} },
		],
		limit => 1);
	my $count = $results->count;

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

	# commenced at
	$self->set_value( "end_time", EPrints::Time::get_iso_timestamp() );
	$self->commit();

	my $rc = $self->_execute();

	# completed at
	$self->set_value( "end_time", EPrints::Time::get_iso_timestamp() );

	if( $rc == EPrints::Const::HTTP_LOCKED )
	{
		my $start_time = $self->value( "start_time" );
		if( defined $start_time )
		{
			$start_time = EPrints::Time::datetime_utc(
				EPrints::Time::split_value( $start_time )
			);
		}
		$start_time = time() if !defined $start_time;
		$start_time += 10 * 60; # try again in 10 minutes time
		$self->set_value( "start_time",
			EPrints::Time::iso_datetime( $start_time )
		);
		$self->set_value( "status", "waiting" );
		$self->commit;
	}
	elsif( $rc == EPrints::Const::HTTP_RESET_CONTENT )
	{
		$self->set_value( "status", "waiting" );
		$self->commit;
	}
	elsif( $rc == EPrints::Const::HTTP_INTERNAL_SERVER_ERROR )
	{
		$self->set_value( "status", "failed" );
		$self->commit();
	}
	# OK or NOT_FOUND, which is ok
	else
	{
		if(
			$rc != EPrints::Const::HTTP_OK &&
			$rc != EPrints::Const::HTTP_NOT_FOUND
		  )
		{
			$self->message( "warning", $self->{session}->xml->create_text_node( "Unrecognised result code (check your action return): $rc" ) );
		}
		if( !$self->is_set( "cleanup" ) || $self->value( "cleanup" ) eq "TRUE" )
		{
			$self->remove();
		}
		else
		{
			if( $rc == EPrints::Const::HTTP_OK )
			{
				$self->set_value( "status", "success" );
			}
			else # NOT_FOUND
			{
				$self->set_value( "status", "failed" );
			}
			$self->commit;
		}
	}

	return $rc;
}

sub _execute
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $xml = $session->xml;

	my $plugin = $session->plugin( $self->value( "pluginid" ),
		event => $self,
	);
	if( !defined $plugin )
	{
		# no such plugin
		$self->message( "error", $xml->create_text_node( $self->value( "pluginid" )." not available" ) );
		return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
	}

	my $action = $self->value( "action" );
	if( !$plugin->can( $action ) )
	{
		$self->message( "error", $xml->create_text_node( "'$action' not available on ".ref($plugin) ) );
		return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
	}

	my $params = $self->value( "params" );
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
				$self->message( "error", $xml->create_text_node( "Bad parameters: No such dataset '$1'" ) );
				return EPrints::Const::HTTP_NOT_FOUND;
			}
			$param = $dataset->dataobj( $2 );
			if( !defined $param )
			{
				$self->message( "error", $xml->create_text_node( "Bad parameters: No such item '$2' in dataset '$1'" ) );
				return EPrints::Const::HTTP_NOT_FOUND;
			}
			my $locked = 0;
			if( $param->isa( "EPrints::DataObj::EPrint" ) )
			{
				$locked = 1 if( $param->is_locked() );
			}
			if( $param->isa( "EPrints::DataObj::Document" ) )
			{
				my $eprint = $param->get_parent;
				$locked = 1 if( $eprint && $eprint->is_locked() );
			}
			if( $locked )
			{
				$self->message( "warning", $xml->create_text_node( $param->get_dataset->base_id.".".$param->id." is locked" ) );
				return EPrints::Const::HTTP_LOCKED;
			}
		}
	}

	my $rc = eval { $plugin->$action( @params ) };
	if( $@ )
	{
		$self->message( "error", $xml->create_text_node( "Error during execution: $@" ) );
		$self->set_value( "description", $@ );
		return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
	}

	return defined($rc) ? $rc : EPrints::Const::HTTP_OK;
}

=item $event->message( $type, $xhtml )

Register a message.

=cut

sub message
{
	my( $self, $type, $message ) = @_;

	my $msg = "";
	$msg = sprintf( "[%s] %s::%s: %s",
		$self->id,
		$self->value( "pluginid" ),
		$self->value( "action" ),
		$self->{session}->xhtml->to_text_dump( $message ) );
	$self->{session}->xml->dispose( $message );

	$self->{session}->log( $msg );
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

