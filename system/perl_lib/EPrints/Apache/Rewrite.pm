######################################################################
#
# EPrints::Apache::Rewrite
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

B<EPrints::Apache::Rewrite> - rewrite cosmetic URL's to internally useful ones.

=head1 DESCRIPTION

This rewrites the URL apache receives based on certain things, such
as the current language.

Expands 
/archive/00000123/*
to 
/archive/00/00/01/23/*

and so forth.

This should only ever be called from within the mod_perl system.

=over 4

=cut

package EPrints::Apache::Rewrite;

use EPrints::Apache::AnApache; # exports apache constants

use strict;
  
sub handler 
{
	my( $r ) = @_;

	my $repository_id = $r->dir_config( "EPrints_ArchiveID" );
	if( !defined $repository_id )
	{
		return DECLINED;
	}
	my $repository = EPrints::Repository->new( $repository_id );
	$repository->check_secure_dirs( $r );
	my $esec = $r->dir_config( "EPrints_Secure" );
	my $secure = (defined $esec && $esec eq "yes" );
	my $urlpath;
	my $cgipath;
	if( $secure ) 
	{ 
		$urlpath = $repository->get_conf( "https_root" );
		$cgipath = $repository->get_conf( "https_cgiroot" );
	}
	else
	{ 
		$urlpath = $repository->get_conf( "http_root" );
		$cgipath = $repository->get_conf( "http_cgiroot" );
	}

	my $uri = $r->uri;
	my $lang = EPrints::Session::get_session_language( $repository, $r );
	my $args = $r->args;
	if( $args ne "" ) { $args = '?'.$args; }

	# Skip rewriting the /cgi/ path and any other specified in
	# the config file.
	my $econf = $repository->get_conf('rewrite_exceptions');
	my @exceptions = ();
	if( defined $econf ) { @exceptions = @{$econf}; }
	push @exceptions,
		$cgipath,
		"$urlpath/thumbnails/";

	my $securehost = $repository->get_conf( "securehost" );
	if( EPrints::Utils::is_set( $securehost ) && !$secure )
	{
		# If this repository has secure mode but we're not
		# on the https site then skip /secure/ to let
		# it just get rediected to the secure site.
		push @exceptions,
			$repository->get_conf( "https_cgiroot" ),
			$repository->get_conf( "https_root" );
	}
	


	foreach my $exppath ( @exceptions )
	{
		return DECLINED if( $uri =~ m/^$exppath/ );
	}
	
	# if we're not in an EPrints path return
	unless( $uri =~ s/^$urlpath// || $uri =~ s/^$cgipath// )
	{
		return DECLINED;
	}

	if( $uri =~ m#^/([0-9]+)(.*)$# )
	{
		# It's an eprint...
	
		my $eprintid = $1;
		my $tail = $2;
		my $redir = 0;
		if( $tail eq "" ) { $tail = "/"; $redir = 1; }

		if( ($eprintid + 0) ne $eprintid || $redir)
		{
			# leading zeros
			return redir( $r, sprintf( "%s/%d%s",$urlpath, $eprintid, $tail ).$args );
		}
		my $s8 = sprintf('%08d',$eprintid);
		$s8 =~ m/(..)(..)(..)(..)/;	
		my $splitpath = "$1/$2/$3/$4";
		$uri = "/archive/$splitpath$tail";

		my $thumbnails = 0;
		$thumbnails = 1 if( $tail =~ s/^\/thumbnails// );

		if( $tail =~ s/^\/(\d+)// )
		{
			# it's a document....			

			my $pos = $1;
			if( $tail eq "" || $pos ne $pos+0 )
			{
				$tail = "/" if $tail eq "";
				return redir( $r, sprintf( "%s/%d/%d%s",$urlpath, $eprintid, $pos, $tail ).$args );
			}
			my $session = new EPrints::Session(2); # don't open the CGI info
			my $ds = $repository->get_dataset("eprint") ;
			my $searchexp = new EPrints::Search( session=>$session, dataset=>$ds );
			$searchexp->add_field( $ds->get_field( "eprintid" ), $eprintid );
			my $results = $searchexp->perform_search;
			my( $eprint ) = $results->get_records(0,1);
			$searchexp->dispose;
		
			# let it fail if this isn't a real eprint	
			if( !defined $eprint )
			{
				return OK;
			}
	
			my $filename = sprintf( '%s/%02d%s',$eprint->local_path.($thumbnails?"/thumbnails":""), $pos, $tail );

			$r->filename( $filename );

			$session->terminate;
			
			return OK;
		}
	}

	# apache 2 does not automatically look for index.html so we have to do it ourselves
	if( $uri =~ m#/$# )
	{
		$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$uri."index.html" );
	}
	else
	{
		$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$uri );
	}
	$r->set_handlers(PerlResponseHandler =>[ 'EPrints::Apache::Template' ] );

	return OK;
}


sub redir
{
	my( $r, $url ) = @_;

	EPrints::Apache::AnApache::send_status_line( $r, 302, "Close but no Cigar" );
	EPrints::Apache::AnApache::header_out( $r, "Location", $url );
	EPrints::Apache::AnApache::send_http_header( $r );
	return DONE;
} 



1;


