######################################################################
#
# EPrints::LogHandler
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

EPrints::LogHandler - Main handler for Apache log events

=head1 CONFIGURATION

To enable the LogHandler add to your ArchiveConfig:

   $c->{loghandler}->{enable} = 1;

=cut

package EPrints::LogHandler;

use strict;
use warnings;

#use Apache::RequestRec;
#use Apache::Connection;

#use Fcntl qw(:flock);

sub handler
{
	my( $r ) = @_;

	my $session = new EPrints::Session;
	return EPrints::AnApache::DECLINED unless defined $session;

	my $repository = $session->get_repository;

#	my $root = $repository->get_conf( "archiveroot" );
#	my $logpath = "$root/logs";

#	mkdir($logpath);

#	my $logfile = "$logpath/handler.log";
#	open my $fh, ">>$logfile" or die "can't open $logfile: $!";
#	flock $fh, LOCK_EX;
#	print $fh sprintf("%d\t%s\t%s\n", time(), $repository->get_id, $r->uri);
#	close $fh;

	my $c = $r->connection();
	my $ip = $c->remote_ip();

	my $rfr = $r->headers_in->{ "Referer" };
	if( $rfr and $rfr !~ /^https?:/ )
	{
		$rfr = '';
	}

	my $data = EPrints::DataObj::Access->get_defaults(
		$session,
		{
			requester_id => 'urn:ip:' . $ip,
			requester_user_agent => $r->headers_in->{ "User-Agent" },
			requester_country => undef,
			requester_institution => undef,
			referring_entity_id => $rfr,
			service_type_id => '',
			referent_id => $r->uri,
			referent_docid => $r->filename,
		});

	EPrints::DataObj::Access->create_from_data(
		$session,
		$data,
		$session->get_repository->get_dataset( "accesslog" )
	);
	
	return EPrints::AnApache::OK;
}

1;
