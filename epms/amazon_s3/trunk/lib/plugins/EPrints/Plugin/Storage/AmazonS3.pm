=head1 NAME

EPrints::Plugin::Storage::AmazonS3 - storage in Amazon S3

=head1 SYNOPSIS

	# cfg.d/plugins.pl
	$c->{plugins}->{"Storage::AmazonS3"}->{params}->{aws_bucket} = "...";
	$c->{plugins}->{"Storage::AmazonS3"}->{params}->{aws_access_key_id} = "...";
	$c->{plugins}->{"Storage::AmazonS3"}->{params}->{aws_secret_access_key} = "...";

	# lib/storage/default.xml
	<plugin name="AmazonS3"/>

=head1 DESCRIPTION

See L<EPrints::Plugin::Storage> for available methods.

To enable this module you must configure the bucket name, access key id and secret access key in your configuration.

If the bucket does not already exist the plugin will attempt to create it before any writes occur.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Storage::AmazonS3;

use URI;
use URI::Escape;
use File::Basename;

use EPrints::Plugin::Storage;

@ISA = ( "EPrints::Plugin::Storage" );

use HTTP::Request;
use LWP::UserAgent::AmazonS3;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Amazon S3 storage";
	$self->{storage_class} = "z_cloud_storage";
	
	if( $self->{session} )
	{
		my $aws_access_key_id = $self->param( "aws_access_key_id" );
		my $aws_secret_access_key = $self->param( "aws_secret_access_key" );
		my $aws_bucket = $self->param( "aws_bucket" );
		if( $aws_secret_access_key && $aws_access_key_id && $aws_bucket )
		{
			$self->{ua} = LWP::UserAgent::AmazonS3->new(
				aws_access_key_id => $aws_access_key_id,
				aws_secret_access_key => $aws_secret_access_key,
				);
			$self->{aws_bucket} = $aws_bucket;
		}
		else
		{
			$self->{visible} = "";
			$self->{error} = "Requires aws_secret_access_key and aws_access_key_id and aws_bucket";
		}
	}

	return $self;
}

sub request { shift->{ua}->request( @_ ); }

sub uri
{
	my( $self, $fileobj ) = @_;

	my $uri = URI->new( $self->{ua}->_proto . "://" . $self->{aws_bucket} . "." . $self->{ua}->_host );

	my $path = "/";

	if( defined $fileobj )
	{
		$path .= $fileobj->get_id;
		$path .= "/file/" . URI::Escape::uri_escape( $fileobj->get_value( "filename" ) );
	}

	$uri->path( $path );

	return $uri;
}

sub create_bucket
{
	my( $self ) = @_;

	my $uri = $self->uri;

	my $req = HTTP::Request->new( HEAD => $uri );

	my $r = $self->request( $req );

	return $r if $r->is_success;

	$req = HTTP::Request->new( PUT => $uri );

	$req->header( "Content-Length" => 0 );
	$req->content( "" );

	$r = $self->request( $req );

	return $r;
}

sub store
{
	my( $self, $fileobj, $f ) = @_;

	$self->create_bucket();

	my $uri = $self->uri( $fileobj );

	my $req = HTTP::Request->new( "PUT" => $uri );
	$req->header( "Content-Length" => $fileobj->get_value( "filesize" ) );
	$req->header( "Content-Type" => $fileobj->get_value( "mime_type" ) );
	$req->content( $f ); # read from sub

# FIXME: make everything public
	$req->header( "x-amz-acl" => "public-read" );

	my $r = $self->request( $req );

	unless( $r->is_success )
	{
		$self->{error} = $r->as_string . "\n\n" . $req->as_string;
		$self->{session}->get_repository->log( $self->{error} );
		return undef;
	}

	return $uri;
}

sub retrieve
{
	my( $self, $fileobj, $uri, $offset, $n, $f ) = @_;

	my $req = HTTP::Request->new( GET => $uri );

	if( $offset != 0 || $n != $fileobj->value( "filesize" ) )
	{
		$req->header( "Range" => sprintf("bytes=%d-%d\n",
			$offset,
			$n - $offset - 1
		) );
	}

	my $r = $self->request( $req, $f );

	if( $r->is_error )
	{
		$self->{session}->get_repository->log( $r->as_string );
	}

	return $r->is_success ? 1 : 0;
}

sub delete
{
	my( $self, $fileobj, $sourceid ) = @_;

	my $req = HTTP::Request->new( DELETE => $self->uri( $fileobj ) );

	return $self->request( $req )->is_success;
}

sub get_remote_copy
{
	my( $self, $fileobj, $uri ) = @_;

	my $req = HTTP::Request->new( HEAD => $uri );

	my $r = $self->request( $req );

	if( $r->is_error )
	{
		$self->{session}->get_repository->log( $r->as_string );
		return undef;
	}

	return $uri;
}

=back

=cut

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

