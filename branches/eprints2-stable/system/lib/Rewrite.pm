

package EPrints::Rewrite;
  
use Apache::Constants qw(DECLINED OK);
use Apache::Request;
use Apache::Cookie;

use EPrints::Session;

use strict;
  
sub handler 
{
	my( $r ) = @_;

	my $archiveid = $r->dir_config( "EPrints_ArchiveID" );
	my $archive = EPrints::Archive->new_archive_by_id( $archiveid );
	my $urlpath = $archive->get_conf( "urlpath" );
	my $uri = $r->uri;
	my $lang = EPrints::Session::get_session_language( $archive, $r );

	unless( $uri =~ s#^$urlpath## )
	{
		return DECLINED;
	}

	if( $uri =~ m#^/perl/# )
	{
		return DECLINED;
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


