######################################################################
#
# EPrints::Apache::Rewrite
#
######################################################################
#
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

	my $repoid = $r->dir_config( "EPrints_ArchiveID" );
	return DECLINED if !$repoid;

	if( defined $EPrints::HANDLE )
	{
		$EPrints::HANDLE->init_from_request( $r );
	}
	else
	{
		EPrints->abort( __PACKAGE__."::handler was called before EPrints was initialised (you may need to re-run generate_apacheconf)" );
	}

	my $repository = $EPrints::HANDLE->current_repository();
	if( !defined $repository )
	{
		EPrints->abort( "'$repoid' is not a valid repository identifier:\nPerlSetVar EPrints_ArchiveID $repoid" );
	}

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
	{
		$uri = eval { Encode::decode_utf8( $uri ) };
		$uri = Encode::decode( "iso-8859-1", $uri ) if $@; # utf-8 failed
	}

	# Not an EPrints path (only applies if we're in a non-standard path)
	if( $uri !~ /^(?:$urlpath)|(?:$cgipath)/ )
	{
		return DECLINED;
	}

	# Non-EPrints paths within our tree
	my $exceptions = $repository->config( 'rewrite_exceptions' );
	$exceptions = [] if !defined $exceptions;
	foreach my $exppath ( @$exceptions )
	{
		next if $exppath eq '/cgi/'; # legacy
		next if $exppath eq '/archive/'; # legacy
		return DECLINED if( $uri =~ m/^$exppath/ );
	}

	# database needs updating
	if( $r->is_initial_req && !$repository->get_database->is_latest_version )
	{
		my $msg = "Database schema is out of date: ./bin/epadmin upgrade ".$repository->get_id;
		$repository->log( $msg );
		EPrints::Apache::AnApache::send_status_line( $r, 500, "EPrints Database schema is out of date" );
		return 500;
	}

	# 404 handler
	$r->custom_response( Apache2::Const::NOT_FOUND, $repository->current_url( path => "cgi", "handle_404" ) );

	my $args = $r->args;
	$args = "" if !defined $args;
	$args = "?$args" if length($args);

	my $lang = EPrints::Session::get_session_language( $repository, $r );

	my $rc = undef;
	$repository->run_trigger( EPrints::Const::EP_TRIGGER_URL_REWRITE,
		request => $r,
		   lang => $lang,    # en
		   args => $args,    # "" or "?foo=bar"
		urlpath => $urlpath, # "" or "/subdir"
		cgipath => $cgipath, # /cgi or /subdir/cgi
		    uri => $uri,     # /foo/bar
		 secure => $secure,  # boolean
            return_code => \$rc,     # set to trigger a return
	);
	# if the trigger has set an return code
	return $rc if defined $rc;

	# /archive/ redirect
	if( $uri =~ m! ^$urlpath/archive/(.*) !x )
	{
		return redir( $r, "$urlpath/$1$args" );
	}

	# don't respond to anything containing '/.'
	if( $uri =~ /\/\./ )
	{
		return DECLINED;
	}

	# /perl/ redirect
	my $perlpath = $cgipath;
	$perlpath =~ s! /cgi\b ! /perl !x;
	if( $uri =~ s! ^$perlpath !!x )
	{
		return redir( $r, "$cgipath$uri$args" );
	}

	# CGI
	if( $uri =~ s! ^$cgipath !!x )
	{
		# redirect secure stuff
		if( $repository->config( "securehost" ) && !$secure && $uri =~ s! ^/(
			(?:users/)|
			(?:change_user)|
			(?:confirm)|
			(?:register)|
			(?:reset_password)|
			(?:set_password)
			) !!x )
		{
			my $https_redirect = $repository->current_url(
				scheme => "https", 
				host => 1,
				path => "cgi",
				"$1$uri" ) . $args;
			return redir( $r, $https_redirect );
		}

		if( $repository->config( "use_mimetex" ) && $uri eq "mimetex.cgi" )
		{
			$r->handler('cgi-script');
			$r->filename( $repository->config( "executables", "mimetex" ) );
			return OK;
		}

		$r->filename( EPrints::Config::get( "cgi_path" ).$uri );

		# !!!Warning!!!
		# If path_info is defined before the Response stage Apache will
		# attempt to find the file identified by path_info using an internal
		# request (presumably to get the content-type). We don't want that to
		# happen so we delay setting path_info until just before the response
		# is generated.
		my $path_info;
		# strip the leading '/'
		my( undef, @parts ) = split m! /+ !x, $uri;
		PATH: foreach my $path (
				$repository->config( "cgi_path" ),
				EPrints::Config::get( "cgi_path" ),
			)
		{
			for(my $i = $#parts; $i >= 0; --$i)
			{
				my $filename = join('/', $path, @parts[0..$i]);
				if( -f $filename )
				{
					$r->filename( $filename );
					$path_info = join('/', @parts[$i+1..$#parts]);
					$path_info = '/' . $path_info if length($path_info);
					last PATH;
				}
			}
		}

		if( $uri =~ m! ^/users\b !x )
		{
			$r->push_handlers(PerlAccessHandler => [
				\&EPrints::Apache::Auth::authen,
				\&EPrints::Apache::Auth::authz
				] );
		}

		$r->handler('perl-script');

		$r->set_handlers(PerlResponseHandler => [
			# set path_info for the CGI script
			sub { $_[0]->path_info( $path_info ); DECLINED },
			'ModPerl::Registry'
			]);

		return OK;
	}

	# SWORD-APP
	if( $uri =~ s! ^$urlpath/sword-app/ !!x )
	{
		$r->handler( 'perl-script' );

		$r->set_handlers( PerlMapToStorageHandler => sub { OK } );

		if( $uri =~ s! ^atom\b !!x )
		{
			$r->set_handlers( PerlResponseHandler => [ 'EPrints::Sword::AtomHandler' ] );
		}
		elsif( $uri =~ s! ^deposit\b !!x )
		{
			$r->set_handlers( PerlResponseHandler => [ 'EPrints::Sword::DepositHandler' ] );
		}
		elsif( $uri =~ s! ^servicedocument\b !!x )
		{
			$r->set_handlers( PerlResponseHandler => [ 'EPrints::Sword::ServiceDocument' ] );
		}
		else
		{
			return NOT_FOUND;
		}
		return OK;
	}
	
	#CRUD
	my $method = $r->method();
	if (!($method eq "GET") and $uri !~ /^(?:$cgipath)/ and $uri !~ /^\/rest\// ) 
	{
		$r->handler( 'perl-script' );

		$r->set_handlers( PerlMapToStorageHandler => sub { OK } );

		if ($method eq "DELETE") { 
			$r->set_handlers( PerlResponseHandler => [ 'EPrints::CRUD::DeleteHandler' ] );
			return OK;
		}
		if ($method eq "POST") {
			if ($uri eq "/") {
				my $url = $repository->config( "base_url" )."/sword-app/deposit/inbox";
				return redir_see_other( $r, $url );
			}
			else 
			{
				$r->set_handlers( PerlResponseHandler => [ 'EPrints::CRUD::PostHandler' ] );
				return OK;
			}
		}
		if ($method eq "PUT") { 
			$r->set_handlers( PerlResponseHandler => [ 'EPrints::CRUD::PutHandler' ] );
			return OK;
		};
			
		#return OK;
	}
	
	# robots.txt (nb. only works if site is in root / of domain.)
	if( $uri =~ m! ^$urlpath/robots\.txt$ !x )
	{
		$r->handler( 'perl-script' );

	 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::RobotsTxt::handler );

		return OK;
	}

	# sitemap.xml (nb. only works if site is in root / of domain.)
	if( $uri =~ m! ^$urlpath/sitemap\.xml$ !x )
	{
		$r->handler( 'perl-script' );

	 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::SiteMap::handler );

		return OK;
	}


	# REST
	if( $uri =~ m! ^$urlpath/rest !x )
	{
		$r->handler( 'perl-script' );

		$r->set_handlers( PerlMapToStorageHandler => sub { OK } );

	 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::REST::handler );
		return OK;
	}

	# URI redirection
	if( $uri =~ m! ^$urlpath/id/(repository|dump|records)$ !x )
	{
		my $file = $1;
		my $accept = EPrints::Apache::AnApache::header_in( $r, "Accept" );
		$accept = "application/rdf+xml" unless defined $accept;
		my $can_accept = "list/triple";

		if ( $file eq "records" ) 
		{
			$can_accept = "list/eprint";
		}
		
		my $plugin = content_negotiate_best_plugin( 
			$repository, 
			accept_header => $accept,
			consider_summary_page => 0,
			plugins => [$repository->get_plugins(
				type => "Export",
				is_visible => "all",
				can_accept => $can_accept )]
		);
	
		if( !defined $plugin )  { return NOT_FOUND; }

		my $url = $repository->config( "http_cgiurl" )."/export/$file/".
			$plugin->get_subtype."/".$repository->get_id.$plugin->param("suffix");

		return redir_see_other( $r, $url );
	}

	if( $uri =~ m! ^$urlpath/id/([^\/]+)/(ext-.*)$ !x )
	{
		my $exttype = $1;
		my $id = $2;
		my $accept = EPrints::Apache::AnApache::header_in( $r, "Accept" );
		$accept = "application/rdf+xml" unless defined $accept;

		my $plugin = content_negotiate_best_plugin( 
			$repository, 
			accept_header => $accept,
			consider_summary_page => 0,
			plugins => [$repository->get_plugins(
				type => "Export",
				is_visible => "all",
				can_accept => "list/triple" )]
		);

		if( !defined $plugin )  { return NOT_FOUND; }

		my $fn = $id;
		$fn=~s/\//_/g;
		my $url = $repository->config( "http_cgiurl" )."/export/$exttype/".
			$id."/".$plugin->get_subtype."/$fn".$plugin->param("suffix");

		return redir_see_other( $r, $url );
	}

	if( $uri =~ s! ^$urlpath/id/([^/]+)/([^/]+)(?:/([^/]+))? !!x )
	{
		my( $datasetid, $id, $part ) = ( $1, $2, $3 );
		$part = '' if !defined $part;

		my $dataset = $repository->get_dataset( $datasetid );
		my $item;
		if( defined $dataset )
		{
			$item = $dataset->dataobj( $id );
		}
		return NOT_FOUND if !defined $item;

		# Subject URI's redirect to the top of that particular subject tree
		# rather than the node in the tree. (the ancestor with "ROOT" as a parent).
		if( $dataset->id eq "subject" )
		{
ANCESTORS: foreach my $anc_subject_id ( @{$item->get_value( "ancestors" )} )
		   {
			   my $anc_subject = $dataset->dataobj($anc_subject_id);
			   next ANCESTORS if( !$anc_subject );
			   next ANCESTORS if( !$anc_subject->is_set( "parents" ) );
			   foreach my $anc_subject_parent_id ( @{$anc_subject->get_value( "parents" )} )
			   {
				   if( $anc_subject_parent_id eq "ROOT" )
				   {
					   $item = $anc_subject;
					   last ANCESTORS;
				   }
			   }
		   }
		}

		# content negotiation. Only worries about type, not charset
		# or language etc. at this stage.
		my $accept = EPrints::Apache::AnApache::header_in( $r, "Accept" );
		$accept = "" if !defined $accept;

		# get the real eprint dataset
		if( $dataset->base_id eq "eprint" )
		{
			$dataset = $item->get_dataset;
		}

		my $accept_type = "dataobj/".$dataset->base_id;

		my $url;

		if( $part eq "contents" )
		{
			if( $item->isa( "EPrints::DataObj::EPrint" ) )
			{
				$part = "documents";
			}
			elsif( $item->isa( "EPrint::DataObj::Document" ) )
			{
				$part = "files";
			}
		}

		if( $part )
		{
			my $field = $dataset->field( $part );
			return NOT_FOUND if !defined $field;
			return NOT_FOUND if !$field->isa( "EPrints::MetaField::Subobject" );
			$accept_type = "list/".$field->property( "datasetid" );
			$r->pnotes->{field} = $field;
		}
		else
		{
			$url = $item->get_url;
			undef $url if $url eq $item->uri; # item's summary page *is* it's id location
		}

		my $match = content_negotiate_best_plugin( 
			$repository, 
			accept_header => $accept,
			consider_summary_page => defined( $url ),
			plugins => [$repository->get_plugins(
				type => "Export",
				is_visible => "all",
				can_accept => $accept_type )],
		);
		
		if( $match eq "DEFAULT_SUMMARY_PAGE" )
		{
			if( $dataset->base_id eq "eprint" && $dataset->id ne "archive" )
			{
				$url = $item->get_control_url;
			}
			return redir_see_other( $r, $url );
		}
		elsif( $dataset->base_id eq "subject" )
		{
			return redir_see_other( $r, $match->dataobj_export_url( $item ) );
		}
		else
		{
			$r->pnotes->{dataset} = $dataset;
			$r->pnotes->{dataobj} = $item;
			$r->pnotes->{plugin} = $match;

			$r->handler('perl-script');

			# no real file to map to
			$r->set_handlers(PerlMapToStorageHandler => sub { OK } );

			$r->push_handlers(PerlAccessHandler => [
				\&EPrints::Apache::Export::authen,
				\&EPrints::Apache::Export::authz
				] );

		 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::Export::handler );

			return OK;
		}

		return NOT_FOUND;
	}

	# /XX/ eprints
	if( $uri =~ s! ^$urlpath/(0*)([1-9][0-9]*)\b !!x )  # ignore leading 0s
	{
		# It's an eprint...
	
		my $eprintid = $2;
		my $eprint = $repository->dataset( "eprint" )->dataobj( $eprintid );
		if( !defined $eprint )
		{
			return NOT_FOUND;
		}

		# redirect to canonical path - /XX/
		if( !length($uri) )
		{
			return redir( $r, "$urlpath/$eprintid/$args" );
		}
		elsif( length($1) )
		{
			return redir( $r, "$urlpath/$eprintid$uri$args" );
		}

		if( $uri =~ s! ^/(0*)([1-9][0-9]*)\b !!x )
		{
			# It's a document....			

			my $pos = $2;
			my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos( $repository, $eprintid, $pos );
			if( !defined $doc )
			{
				return NOT_FOUND;
			}

			if( !length($uri) )
			{
				return redir( $r, "$urlpath/$eprintid/$pos/$args" );
			}
			elsif( length($1) )
			{
				return redir( $r, "$urlpath/$eprintid/$pos$uri$args" );
			}

			$uri =~ s! ^([^/]*)/ !!x;
			my @relations = grep { length($_) } split /\./, $1;

			my $filename = $uri;

			$r->pnotes( eprint => $eprint );
			$r->pnotes( document => $doc );
			$r->pnotes( dataobj => $doc );
			$r->pnotes( filename => $filename );

			$r->handler('perl-script');

			# no real file to map to
			$r->set_handlers(PerlMapToStorageHandler => sub { OK } );

			$r->push_handlers(PerlAccessHandler => [
				\&EPrints::Apache::Auth::authen_doc,
				\&EPrints::Apache::Auth::authz_doc
				] );

		 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::Storage::handler );

			$r->pool->cleanup_register(\&EPrints::Apache::LogHandler::document, $r);

			my $rc = undef;
			$repository->run_trigger( EPrints::Const::EP_TRIGGER_DOC_URL_REWRITE,
				# same as for URL_REWRITE
				request => $r,
				   lang => $lang,    # en
				   args => $args,    # "" or "?foo=bar"
				urlpath => $urlpath, # "" or "/subdir"
				cgipath => $cgipath, # /cgi or /subdir/cgi
				    uri => $uri,     # /foo/bar
				 secure => $secure,  # boolean
			    return_code => \$rc,     # set to trigger a return
				# extra bits
				 eprint => $eprint,
			       document => $doc,
			       filename => $filename,
			      relations => \@relations,
			);

			# if the trigger has set an return code
			return $rc if defined $rc;
	
			# This way of getting a status from a trigger turns out to cause 
			# problems and is included as a legacy feature only. Don't use it, 
			# set ${$opts->{return_code}} = 404; or whatever, instead.
			return $r->status if $r->status != 200;
		}
		# OK, It's the EPrints abstract page (or something whacky like /23/fish)
		else
		{
			my $path = "/archive/" . $eprint->store_path();
			EPrints::Update::Abstract::update( $repository, $lang, $eprint->id, $path );

			if( $uri =~ m! /$ !x )
			{
				$uri .= "index.html";
			}
			$r->filename( $eprint->_htmlpath( $lang ) . $uri );

			if( $uri =~ /\.html$/ )
			{
				$r->pnotes( eprint => $eprint );

				$r->handler('perl-script');
				$r->set_handlers(PerlResponseHandler => [ 'EPrints::Apache::Template' ] );

				# log abstract hits
				$r->pool->cleanup_register(\&EPrints::Apache::LogHandler::eprint, $r);
			}
		}

		return OK;
	}

	# apache 2 does not automatically look for index.html so we have to do it ourselves
	my $localpath = $uri;
	$localpath =~ s! ^$urlpath !!x;
	if( $uri =~ m! /$ !x )
	{
		$localpath.="index.html";
	}
	$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$localpath );

	if( $uri =~ m! ^$urlpath/view(/|\$.*) !x )
	{
		$uri =~ s! ^$urlpath !!x;
		# redirect /foo to /foo/ 
		if( $uri eq "/view" || $uri =~ m! ^/view/[^/]+$ !x )
		{
			return redir( $r, "$urlpath$uri/" );
		}

		local $repository->{preparing_static_page} = 1; 
		my $filename = EPrints::Update::Views::update_view_file( $repository, $lang, $localpath, $uri );
		return NOT_FOUND if( !defined $filename );

		$r->filename( $filename );
	}
	else
	{
		local $repository->{preparing_static_page} = 1; 
		EPrints::Update::Static::update_static_file( $repository, $lang, $localpath );
	}

	if( $r->filename =~ /\.html$/ )
	{
		$r->handler('perl-script');
		$r->set_handlers(PerlResponseHandler => [ 'EPrints::Apache::Template' ] );
	}

	return OK;
}

sub redir
{
	my( $r, $url ) = @_;

	EPrints::Apache::AnApache::send_status_line( $r, 302, "Found" );
	EPrints::Apache::AnApache::header_out( $r, "Location", $url );
	EPrints::Apache::AnApache::send_http_header( $r );
	return DONE;
} 

sub redir_see_other
{
	my( $r, $url ) = @_;

	EPrints::Apache::AnApache::send_status_line( $r, 303, "See Other" );
	EPrints::Apache::AnApache::header_out( $r, "Location", $url );
	EPrints::Apache::AnApache::send_http_header( $r );
	return DONE;
} 

sub content_negotiate_best_plugin
{
	my( $repository, %o ) = @_;

	EPrints::Utils::process_parameters( \%o, {
		accept_header => "*REQUIRED*",
		consider_summary_page => 1, 
		plugins => "*REQUIRED*",
	 } );

	my $pset = {};
	if( $o{consider_summary_page} )
	{
		$pset->{"text/html"} = { qs=>0.99, DEFAULT_SUMMARY_PAGE=>1 };
	}

	foreach my $plugin ( @{$o{plugins}} )
	{
		my( $type, %params ) = split( /\s*[;=]\s*/, $plugin->{mimetype} );
	
		next if( defined $pset->{$type} && $pset->{$type}->{qs} >= $plugin->{qs} );
		$pset->{$type} = $plugin;
	}
	my @pset_order = sort { $pset->{$b}->{qs} <=> $pset->{$a}->{qs} } keys %{$pset};

	my $accepts = { "*/*" => { q=>0.000001 }};
	CHOICE: foreach my $choice ( split( /\s*,\s*/, $o{accept_header} ) )
	{
		my( $mime, %params ) = split( /\s*[;=]\s*/, $choice );
		$params{q} = 1 unless defined $params{q};
		my $match = $pset->{$mime};
		$params{q} *= defined $match ? $match->{qs} : 0;
		$accepts->{$mime} = \%params;
	}
	my @acc_order = sort { $accepts->{$b}->{q} <=> $accepts->{$a}->{q} } keys %{$accepts};

	my $match;
	CHOICE: foreach my $choice ( @acc_order )
	{
		if( $pset->{$choice} ) 
		{
			$match = $pset->{$choice};
			last CHOICE;
		}

		if( $choice eq "*/*" )
		{
			$match = $pset->{$pset_order[0]};
			last CHOICE;
		}

		if( $choice =~ s/\*[^\/]+$// )
		{
			foreach my $type ( @pset_order )
			{
				if( $choice eq substr( $type, 0, length $type ) )
				{
					$match = $pset->{$type};
					last CHOICE;
				}
			}
		}
	}

	if( $match->{DEFAULT_SUMMARY_PAGE} )
	{
		return "DEFAULT_SUMMARY_PAGE";
	}

	return $match; 
}


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

