

package EPrints::Rewrite;
  
use Apache::Constants qw(DECLINED OK);
use strict;
  
sub handler 
{
	my( $r ) = @_;

	my $archiveid = $r->dir_config( "EPrints_ArchiveID" );
	my $archive = EPrints::Archive->new_archive_by_id( $archiveid );

	my $uri =  $r->uri;

	if( $r->uri =~ m#^/perl/# )
	{
		return DECLINED;
	} 

	if( $r->uri =~ m#^/secure/# )
	{
		return DECLINED;
	} 

	$r->document_root( $archive->get_conf( "htdocs_path" )."/"."en" );

	if( $r->uri =~ m#^/archive/([0-9]+)/([0-9][0-9])/([0-9][0-9])/([0-9][0-9])(.*)$# )
	{
		#??
	}
	if( $r->uri =~ m#^/archive/([0-9]+)([0-9][0-9])([0-9][0-9])([0-9][0-9])(.*)$# )
	{
		$r->uri( "/archive/$1/$2/$3/$4$5" );
	}

	return DECLINED;
}
1;
