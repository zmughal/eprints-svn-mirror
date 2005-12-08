######################################################################
#
# EPrints::Workflow::Processor
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

B<EPrints::Workflow::Processor> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

######################################################################
#
#  EPrints Submission uploading/editing forms
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

package EPrints::Workflow::Processor;

use EPrints::EPrint;
use EPrints::Session;
use EPrints::Document;
use EPrints::Workflow;
use EPrints::Workflow::Stage;

use Unicode::String qw(utf8 latin1);
use strict;

######################################################################
=pod

=item $thing = EPrints::WorkflowProc->new( $session, $redirect, $staff, $dataset, $formtarget )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $session, $workflow_id ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{session} = $session;

	# Use user configured order for stages or...
	# $self->{workflow} = $session->get_archive->get_workflow( $workflow_id );

	return( $self );
}

######################################################################
=pod

=item $foo = $thing->render

undocumented

=cut
######################################################################

sub render
{
	my( $self, $stage ) = @_;


	my $arc = $self->{session}->get_archive;
	$self->{eprintid} = 100;
	$self->{dataset} = $arc->get_dataset( "archive" );

	$self->{eprint} = EPrints::EPrint->new(
	$self->{session},
	$self->{eprintid},
	$self->{dataset} );

	my $stage = $arc->{workflow}->get_stage($stage);
	$self->{session}->build_page(
		$self->{session}->html_phrase(
		"lib/submissionform:title_meta",
		type => $self->{eprint}->render_value( "type" ),
		eprintid => $self->{eprint}->render_value( "eprintid" ),
		desc => $self->{eprint}->render_description ),
		$stage->render( $self->{session}, $arc->{workflow} ), 
		"submission_metadata" );

	$self->{session}->send_page();

	return( 1 );
}

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}

1;

######################################################################
=pod

=back

=cut
