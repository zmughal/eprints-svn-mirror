######################################################################
#
# EPrints::Apache::AnApache
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

B<EPrints::Apache::AnApache> - Utility methods for talking to mod_perl

=head1 DESCRIPTION

This module provides a number of utility methods for interacting with the
request object.

=head1 METHODS

=over 4

=cut

package EPrints::Apache::AnApache;

use Exporter;
@ISA	 = qw(Exporter);
@EXPORT  = qw(OK AUTH_REQUIRED FORBIDDEN DECLINED SERVER_ERROR NOT_FOUND DONE);

use ModPerl::Registry;
use Apache2::Util;
use Apache2::SubProcess;
use Apache2::Const;
use Apache2::Connection;
use Apache2::RequestUtil;
use Apache2::MPM;
use Apache2::Directive;

use strict;

######################################################################
=pod

=item EPrints::Apache::AnApache::send_http_header( $request )

Send the HTTP header, if needed.

$request is the current Apache request. 

=cut
######################################################################

sub send_http_header
{
	my( $request ) = @_;

	# do nothing!
}

=item EPrints::Apache::AnApache::header_out( $request, $header, $value )

Set a value in the HTTP headers of the response. $request is the
apache request object, $header is the name of the header and 
$value is the value to give that header.

=cut

sub header_out
{
	my( $request, $header, $value ) = @_;
	
	$request->headers_out->{$header} = $value;
}

=item $value = EPrints::Apache::AnApache::header_in( $request, $header )

Return the specified HTTP header from the current request.

=cut

sub header_in
{
	my( $request, $header ) = @_;	

	return $request->headers_in->{$header};
}

=item $request = EPrints::Apache::AnApache::get_request

Return the current Apache request object.

=cut

sub get_request
{
	return EPrints->new->request;
}

######################################################################
=pod

=item $value = EPrints::Apache::AnApache::cookie( $request, $cookieid )

Return the value of the named cookie, or undef if it is not set.

This avoids using L<CGI>, so does not consume the POST data.

=cut
######################################################################

sub cookie
{
	my( $request, $cookieid ) = @_;

	my $cookies = EPrints::Apache::AnApache::header_in( $request, 'Cookie' );

	return unless defined $cookies;

	foreach my $cookie ( split( /;\s*/, $cookies ) )
	{
		my( $k, $v ) = split( '=', $cookie );
		if( $k eq $cookieid )
		{
			return $v;
		}
	}

	return undef;
}

=item EPrints::Apache::AnApache::upload_doc_file( $session, $document, $paramid );

Collect a file named $paramid uploaded via HTTP and add it to the 
specified $document.

=cut

sub upload_doc_file
{
	my( $session, $document, $paramid ) = @_;

	my $cgi = $session->get_query;

	return $document->upload( 
		$cgi->upload( $paramid ), 
		$cgi->param( $paramid ),
		0, # preserve_path
		-s $cgi->upload( $paramid )
	);	
}

=item EPrints::Apache::AnApache::upload_doc_archive( $session, $document, $paramid, $archive_format );

Collect an archive file (.ZIP, .tar.gz, etc.) uploaded via HTTP and 
unpack it then add it to the specified document.

=cut

sub upload_doc_archive
{
	my( $session, $document, $paramid, $archive_format ) = @_;

	my $cgi = $session->get_query;

	return $document->upload_archive( 
		$cgi->upload( $paramid ), 
		$cgi->param( $paramid ), 
		$archive_format );	
}

######################################################################
=pod

=item EPrints::Apache::AnApache::send_status_line( $request, $code, $message )

Send a HTTP status to the client with $code and $message.

=cut
######################################################################

sub send_status_line
{	
	my( $request, $code, $message ) = @_;
	
	if( defined $message )
	{
		$request->status_line( "$code $message" );
	}
	$request->status( $code );
}

1;
