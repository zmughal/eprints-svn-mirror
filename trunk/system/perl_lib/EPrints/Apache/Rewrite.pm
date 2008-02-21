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

This also causes some pages to be regenerated on demand, if they are stale.

=over 4

=cut

package EPrints::Apache::Rewrite;

use EPrints::Apache::AnApache; # exports apache constants

use Data::Dumper;

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
	if( $secure ) 
	{ 
		$urlpath = $repository->get_conf( "securepath" );
	}
	else
	{ 
		$urlpath = $repository->get_conf( "urlpath" );
	}

	my $uri = $r->uri;

	my $lang = EPrints::Session::get_session_language( $repository, $r );
	my $args = $r->args;
	if( $args ne "" ) { $args = '?'.$args; }

	# REMOVE the urlpath if any!
	unless( $uri =~ s#^$urlpath## )
	{
		return DECLINED;
	}

	# Skip rewriting the /cgi/ path and any other specified in
	# the config file.
	my $econf = $repository->get_conf('rewrite_exceptions');
	my @exceptions = ();
	if( defined $econf ) { @exceptions = @{$econf}; }
	push @exceptions, '/cgi/', '/thumbnails/';

	my $securehost = $repository->get_conf( "securehost" );
	if( EPrints::Utils::is_set( $securehost ) && !$secure )
	{
		# If this repository has secure mode but we're not
		# on the https site then skip /secure/ to let
		# it just get rediected to the secure site.
		push @exceptions, '/secure/';
	}
	


	foreach my $exppath ( @exceptions )
	{
		return DECLINED if( $uri =~ m/^$exppath/ );
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
				$session->terminate;
				return OK;
			}
	
			my $filename = sprintf( '%s/%02d%s',$eprint->local_path.($thumbnails?"/thumbnails":""), $pos, $tail );

			$r->filename( $filename );

			$session->terminate;
			
			return OK;
		}
		
		my $file = $repository->get_conf( "variables_path" )."/abstracts.timestamp";	
		if( -e $file )
		{
			my $poketime = (stat( $file ))[9];
			my $localpath = $uri;
			$localpath.="index.html" if( $uri =~ m#/$# );
			my $targetfile = $repository->get_conf( "htdocs_path" )."/".$lang.$localpath;
			if( -e $targetfile )
			{
				my $targettime = (stat( $targetfile ))[9];
				if( $targettime < $poketime )
				{
					# There is an abstracts file, AND we're looking
					# at serving an abstract page, AND the abstracts timestamp
					# file is newer than the abstracts page...
					# so try and regenerate the abstracts page.
					my $session = new EPrints::Session(2); # don't open the CGI info
					my $eprint = EPrints::DataObj::EPrint->new( $session, $eprintid );
					if( defined $eprint )
					{
						$eprint->generate_static;
					}
					$session->terminate;
				}
			}
		}
	}

	# apache 2 does not automatically look for index.html so we have to do it ourselves
	my $localpath = $uri;
	if( $uri =~ m#/$# )
	{
		$localpath.="index.html";
	}
	$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$localpath );

	if( $uri =~ m#^/view(.*)# )
	{
		my $session = new EPrints::Session(2); # don't open the CGI info
		EPrints::Update::Views::update_view_file( $session, $lang, $localpath, $uri );
		$session->terminate;
	}
	else
	{
		EPrints::Update::Static::update_static_file( $repository, $lang, $localpath );
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


