######################################################################
#
# EPrints::Apache::Template
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

B<EPrints::Apache::Template> - Template Applying Module

=head1 DESCRIPTION

This module is consulted when any file is serverd. It applies the
EPrints template.

=over 4

=cut

package EPrints::Apache::Template;

use CGI;
use FileHandle;

use EPrints::Apache::AnApache; # exports apache constants

use strict;



######################################################################
#
# EPrints::Apache::VLit::handler( $r )
#
######################################################################

sub handler
{
	my( $r ) = @_;

	my $filename = $r->filename;

	return DECLINED unless( $filename =~ s/.html$// );

	return DECLINED unless( -r $filename.".page" );

	my $session = new EPrints::Session;

	my $parts;
	foreach my $part ( "title", "title.textonly", "page", "head" )
	{
		if( open( CACHE, $filename.".".$part ) ) 
		{
			$parts->{"utf-8.".$part} = join("",<CACHE>);
			close CACHE;
		}
		else
		{
			$parts->{"utf-8.".$part} = "";
			$session->get_repository->log( "Could not read ".$filename.".".$part );
		}
	}

	$session->prepare_page( $parts, pageid=>"static" );
	$session->send_page;

	$session->terminate;


	return OK;
}








1;

######################################################################
=pod

=back

=cut

