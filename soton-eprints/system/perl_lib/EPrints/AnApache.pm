######################################################################
#
# EPrints::AnApache
#
######################################################################
#
#  This file is part of GNU EPrints 2.
#  
#  Copyright (c) 2000-2004 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 2 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 2 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 2; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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

	# Detect API version, either 1 or 2 
	$EPrints::AnApache::ModPerlAPI = 0;

	eval "require Apache2::Util"; 
	unless( $@ ) { $EPrints::AnApache::ModPerlAPI = 2; }

	if( !$EPrints::AnApache::ModPerlAPI ) 
	{ 
		eval "require Apache2"; 
		unless( $@ ) { $EPrints::AnApache::ModPerlAPI = 1; } 
	}

	# no API version, is mod_perl 2 even installed?
	if( !$EPrints::AnApache::ModPerlAPI )
	{
		# can't find either old OR new mod_perl API

		# not logging functions available to eprints runtime yet
		print STDERR "\n------------------------------------------------------------\n";
		print STDERR "Failed to load mod_perl for Apache 2\n";
		eval "require Apache"; if( !$@ ) {
			print STDERR "However mod_perl for Apache 1.3 is available. Is the 'apache'\nparameter in perl_lib/EPrints/SystemSettings.pm correct?\n";
		}
		print STDERR "------------------------------------------------------------\n";

		die;
	};

	my @modules = ( 
		'EPrints::RequestWrapper2', 
		'Apache::AuthDBI', 
		'ModPerl::Registry' 
	);
	if( $EPrints::AnApache::ModPerlAPI == 1 )
	{
		push @modules, 'Apache::Const';
	}
	if( $EPrints::AnApache::ModPerlAPI == 2 )
	{
		push @modules, 'Apache2::Const';
	}
	foreach my $module ( @modules )
	{
		eval "use $module"; 
		next unless( $@ );
		die "Error loading module $module:\n$@";
	}

	$EPrints::AnApache::RequestWrapper = "EPrints::RequestWrapper2"; 

	eval '

		sub upload_doc_file
		{
			my( $session, $document, $paramid ) = @_;
		
			my $cgi = $session->get_query;
		
			return $document->upload( 
				$cgi->upload( $paramid ), 
				$cgi->param( $paramid ) );	
		}

		sub upload_doc_archive
		{
			my( $session, $document, $paramid, $archive_format ) = @_;

			my $cgi = $session->get_query;
		
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

		sub get_request
		{
			if( $EPrints::AnApache::ModPerlAPI == 1 )
			{
				return Apache->request;
			}
			if( $EPrints::AnApache::ModPerlAPI == 2 )
			{
				return Apache2::RequestUtil->request();
			}
			die "Unknown ModPerlAPI version: $EPrints::AnApache::ModPerlAPI";
		}
	';
	
}
else
{
	# Apache 1.3
	eval "require Apache"; if( $@ ) {
		# not logging functions available yet
		print STDERR "\n------------------------------------------------------------\n";
		print STDERR "Failed to load mod_perl for Apache 1.3\n";
		my $modperl2 = 0;
		eval "require Apache2"; unless( $@ ) { $modperl2 = 1; }
		eval "require Apache2::Utils"; unless( $@ ) { $modperl2 = 1; }
 		if( $modperl2 )
		{
			print STDERR "However mod_perl for Apache 2 is available. Is the 'apache'\nparameter in perl_lib/EPrints/SystemSettings.pm correct?\n";
		}
		print STDERR "------------------------------------------------------------\n";

		die;
	};
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
			my( $session, $document, $paramid ) = @_;
		
			my $cgi = $session->get_query;
		
			return $document->upload( 
				$cgi->upload( $paramid ), 
				$cgi->param( $paramid ) );	
		}

		sub upload_doc_archive
		{
			my( $session, $document, $paramid, $archive_format ) = @_;

			my $cgi = $session->get_query;
		
			return $document->upload_archive( 
				$cgi->upload( $paramid ), 
				$cgi->param( $paramid ), 
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
		
		sub get_request
		{
			return Apache->request;
		}
	';
}


1;
