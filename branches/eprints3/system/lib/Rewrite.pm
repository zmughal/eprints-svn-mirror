

package EPrints::Rewrite;

use EPrints::AnApache;  
use Apache::Request;

use EPrints::Session;

use strict;
  
sub handler 
{
	my( $r ) = @_;

	my $archiveid = $r->dir_config( "EPrints_ArchiveID" );
	if( !defined $archiveid )
	{
		return send_error( $r, "<p>archiveid was not set in the apache configuration.</p>" );
	}
	my $archive = EPrints::Archive->new_archive_by_id( $archiveid );
	if( !defined $archive )
	{
		return send_error( $r, "<p>Could not find archive with archiveid \"$archiveid\". archiveid was set in the apache configuration.</p>" );
	}
	EPrints::Session::set_archive( $archive );
	
	my $urlpath = &ARCHIVE->get_conf( "urlpath" );
	my $uri = $r->uri;
	my $args = $r->args;
	if( $args ne "" ) { $args = '?'.$args; }
	my $lang = EPrints::Session::get_session_language( $r );

	# REMOVE the urlpath if any!
	unless( $uri =~ s#^$urlpath## )
	{
		return DECLINED;
	}

	if( $uri =~ m#^/perl/# )
	{
		return DECLINED;
	} 

	if( $uri =~ m#^/cgi/# )
	{
		# In case people want a real CGI Directory on the same
		# server. For example for mimetex.
		return DECLINED;
	} 

	
	# shorturl does not (yet) effect secure docs.
	if( $uri =~ s#^/secure/([0-9]+)([0-9][0-9])([0-9][0-9])([0-9][0-9])#/secure/$1/$2/$3/$4# )
	{
		$r->filename( &ARCHIVE->get_conf( "htdocs_path" )."/".$uri );
		return OK;
	}


	my $shorturl = &ARCHIVE->get_conf( "use_short_urls" );
	$shorturl = 0 unless( defined $shorturl );

	if( $uri =~ m#^/archive/([0-9]+)(.*)$# )
	{
		# is a long record url
		my $n = $1;
		my $tail = $2;
		my $redir =0;
		if( $tail eq "" ) { $tail = "/"; $redir=1 }
		
		if( $shorturl )
		{
			# redirect to short form
			return send_redir( $r, sprintf( "%s/%d%s",$urlpath, $n, $tail ).$args );
		}

		my $s8 = sprintf('%08d',$n);
		$s8 =~ m/(..)(..)(..)(..)/;	
		if( length $n < 8 || $redir)
		{
			# not enough zeros, redirect to correct version
			return send_redir( $r, sprintf( "%s/archive/%08d%s",$urlpath, $n, $tail ).$args );
		}
		$uri = "/archive/$1/$2/$3/$4$tail";
	}

	
	if( $uri =~ m#^/([0-9]+)(.*)$# )
	{
		# is a shorturl record url
		my $n = $1;
		my $tail = $2;
		my $redir = 0;
		if( $tail eq "" ) { $tail = "/"; $redir = 1; }
		if( !$shorturl )
		{
			# redir to long form
			return send_redir( $r, sprintf( "%s/archive/%08d%s",$urlpath, $n, $tail ).$args);
		} 

		if( ($n + 0) ne $n || $redir)
		{
			# leading zeros
			return send_redir( $r, sprintf( "%s/%d%s",$urlpath, $n, $tail ).$args );
		}
		my $s8 = sprintf('%08d',$n);
		$s8 =~ m/(..)(..)(..)(..)/;	
		$uri = "/archive/$1/$2/$3/$4$tail";
	}

	# apache 2 does not automatically look for index.html so we have to do it ourselves
	if( $uri =~ m#/$# )
	{
		$r->filename( &ARCHIVE->get_conf( "htdocs_path" )."/".$lang.$uri."index.html" );
	}
	else
	{
		$r->filename( &ARCHIVE->get_conf( "htdocs_path" )."/".$lang.$uri );
	}

	return OK;
}


sub send_redir
{
	my( $r, $url ) = @_;

	$r->status_line( "302 Close but no Cigar" );
	EPrints::AnApache::header_out( $r, "Location", $url );
	$r->send_http_header;
	return DONE;
} 

sub send_error
{
	my( $r, $msg ) = @_;

	$r->content_type( 'text/html' );
	$r->status_line( "403 EPrints Error" );
	$r->send_http_header;
	$r->print( <<END );
<html>
  <head>
    <title>EPrints System Error</title>
  </head>
  <body>
    <h1>EPrints System Error</h1>
    $msg
  </body>
</html>
END
	return DONE;
}


1;


