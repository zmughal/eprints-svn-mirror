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

=cut

package EPrints::LogHandler;

use strict;
use warnings;

use Fcntl qw(:flock);

#use EPrints::Session;
#use EPrints::AnApache;

sub handler
{
	my( $r ) = shift;

	my $session = new EPrints::Session;
	return EPrints::AnApache::DECLINED unless defined $session;

	# The rest of this is a hack to test with
	my $archive = $session->get_archive();

	my $root = $archive->get_conf( "archiveroot" );
	my $logpath = "$root/logs";

	mkdir($logpath);

	my $logfile = "$logpath/handler.log";
	open my $fh, ">>$logfile" or die "can't open $logfile: $!";
	flock $fh, LOCK_EX;
	print $fh sprintf("%d\t%s\t%s\n", time(), $archive->get_id, $r->uri);
	close $fh;
	return EPrints::AnApache::OK;
}

1;
