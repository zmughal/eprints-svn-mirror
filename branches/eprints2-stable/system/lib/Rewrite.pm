

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
		return DECLINED;
	}
	my $archive = EPrints::Archive->new_archive_by_id( $archiveid );
	my $urlpath = $archive->get_conf( "urlpath" );
	my $uri = $r->uri;
	my $lang = EPrints::Session::get_session_language( $archive, $r );

	# REMOVE the urlpath if any!
	unless( $uri =~ s#^$urlpath## )
	{
		return DECLINED;
	}

	if( $uri =~ m#^/perl/# )
	{
		return DECLINED;
	} 

	if( $uri =~ m#^/archive/([0-9]{1,7})($|/[^0-9].*)# )
	{
		my $n = $1;
		my $tail = $2;
		if( $tail eq "" )
		{
			$tail = "/";
		}
		my $url = sprintf( "%s/archive/%08d%s",$urlpath, $n, $tail );
		$r->status_line( "302 Close but no Cigar" );
		$r->header_out( "Location", $url );
		$r->send_http_header;
		return DONE;
	}

	if( $uri =~ s#^/secure/([0-9]+)([0-9][0-9])([0-9][0-9])([0-9][0-9])#/secure/$1/$2/$3/$4# )
	{
		$r->filename( $archive->get_conf( "htdocs_path" )."/".$uri );
		return OK;
	}

	$uri =~ s#^/archive/([0-9]+)([0-9][0-9])([0-9][0-9])([0-9][0-9])#/archive/$1/$2/$3/$4#;
	$r->filename( $archive->get_conf( "htdocs_path" )."/".$lang.$uri );

	return OK;
}





1;


