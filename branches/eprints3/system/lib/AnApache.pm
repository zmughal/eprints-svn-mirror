######################################################################
#
# EPrints::AnApache
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

B<EPrints::AnApache> - Load appropriate Apache Module

=head1 DESCRIPTION

Handy way of loading Apache or Apache2 depending on value in SystemSettings.

Plus functions to paper over the cracks between the two interfaces.

=over 4

=cut

package EPrints::AnApache;

BEGIN
{
	use Exporter;
	our (@ISA, @EXPORT );
	@ISA	 = qw(Exporter);
	@EXPORT  = qw(OK AUTH_REQUIRED FORBIDDEN DECLINED SERVER_ERROR NOT_FOUND DONE);
}

use EPrints::SystemSettings;
use strict;


my $av =  $EPrints::SystemSettings::conf->{apache};
if( defined $av && $av eq "2" )
{
	# Apache 2
	eval "require EPrints::RequestWrapper2"; if( $@ ) { die $@; }
	eval "require Apache::AuthDBI"; if( $@ ) { die $@; }
	eval "require ModPerl::Registry"; if( $@ ) { die $@; }
	eval "require Apache::Const; import Apache::Const;"; if( $@ ) { die $@; }
	$EPrints::AnApache::RequestWrapper = "EPrints::RequestWrapper2"; 

# hjm Thu Nov 27 16:08:35 GMT 2003
# This is a workaround for what is apparently a bug in libapreq2-2.02-dev which
# truncates uploads at around 700K. This should use the bb interface when this
# bug is fixed.

	eval '

		sub upload_doc_file
		{
			my( $document, $paramid ) = @_;
		
			require CGI;

			my $cgi = CGI->new;
		
			return $document->upload( 
				$cgi->upload( $paramid ), 
				$cgi->param( $paramid ) );	
		}

		sub upload_doc_archive
		{
			my( $document, $paramid, $archive_format ) = @_;

			require CGI;

			my $cgi = CGI->new;
		
			return $document->upload_archive( 
				$cgi->upload( $paramid ), 
				$cgi->param( $paramid ), 
				$archive_format );	
		}

		sub send_http_header
		{
			my( $request ) = @_;
	
			# do nothing!
		}

		sub header_out
		{
			my( $request, $header, $value ) = @_;

			$request->headers_out->{$header} = $value;
		}

		sub header_in
		{
			my( $request, $header ) = @_;	
	
			return $request->headers_in->{$header};
		}

	';
	
}
else
{
	# Apache 1.3
	eval "require EPrints::RequestWrapper"; if( $@ ) { die $@; }
	eval "require Apache::AuthDBI"; if( $@ ) { die $@; }
	eval "require Apache::Registry"; if( $@ ) { die $@; }
	eval "require Apache::Constants; "; if( $@ ) { die $@; }
	$EPrints::AnApache::RequestWrapper = "EPrints::RequestWrapper"; 
	eval '

		sub OK { &Apache::Constants::OK; }
		sub AUTH_REQUIRED { &Apache::Constants::AUTH_REQUIRED; }
		sub FORBIDDEN { &Apache::Constants::FORBIDDEN; }
		sub DECLINED { &Apache::Constants::DECLINED; }
		sub SERVER_ERROR { &Apache::Constants::SERVER_ERROR; }
		sub NOT_FOUND { &Apache::Constants::NOT_FOUND; }
		sub DONE { &Apache::Constants::DONE; }

		sub upload_doc_file
		{
			my( $document, $paramid ) = @_;
		
			my $upload = &SESSION->get_apr->upload( $paramid );
		
			return $document->upload( 
				$upload->fh, 
				$upload->filename );	
		}

		sub upload_doc_archive
		{
			my( $document, $paramid, $archive_format ) = @_;

			my $upload = &SESSION->get_apr->upload( $paramid );
		
			return $document->upload_archive( 
				$upload->fh, 
				$upload->filename, 
				$archive_format );	
		}

		sub send_http_header
		{
			my( $request ) = @_;
	
			$request->send_http_header;
		}


		sub header_out
		{
			my( $request, $header, $value ) = @_;

			$request->header_out( $header => $value );
		}

		sub header_in
		{
			my( $request, $header ) = @_;	
	
			return $request->header_in( $header );
		}
	';
}


1;
