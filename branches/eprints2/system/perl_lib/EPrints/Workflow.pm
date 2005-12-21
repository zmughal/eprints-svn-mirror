######################################################################
#
# EPrints::Workflow
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

B<EPrints::Workflow> - Models the submission process used by an archive. 

=head1 DESCRIPTION

The workflow class handles loading the workflow configuration for a 
single archive. 

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{xmldoc}
#     A XML document to hold all the stray DOM elements.
#
######################################################################

package EPrints::Workflow;

use EPrints::XML;
use EPrints::Workflow::Stage;

use strict;

######################################################################
=pod

=item $language = EPrints::Workflow->new( $archive )

Create a new workflow object representing the specification given in
the workflow.xml configuration

=cut
######################################################################

sub new
{
	my( $class , $archive ) = @_;

	my $self = {};

	bless $self, $class;
	
	$self->{archive} = $archive;

	my $content = $self->_read_workflow( 
		$archive->get_conf( "config_path" ).
		"/workflow.xml", 
		$archive );

	foreach my $item (keys %$content)
	{
		$self->{$item} = $content->{$item};
	}
	print STDERR "Workflow loaded\n";
	return( $self );
}

sub _read_workflow
{
	my( $self, $file, $archive) = @_;
	my $workflow = {};
	my $doc = $archive->parse_xml( $file );
	if( !defined $doc )
	{
		print STDERR "Error loading $file\n";
		return;
	}

	$workflow->{flow} = $self->_read_flow( $doc );
	($workflow->{stages}, $workflow->{nummap}) = $self->_read_stages( $doc );

	return $workflow;
}

sub _read_stages
{
	my( $self, $doc ) = @_;
	print STDERR "Reading stages\n";
	my $stageout = [];
	my $nummap = {};
	my $stages = ($doc->getElementsByTagName("stage"));

	if(!defined $stages)
	{
		print STDERR "Error loading workflow: No stages defined\n";
		return;
	}
	my $pos = 0;
	for( my $i=0; $i<$stages->getLength(); $i++)
	{
		next if( !$stages->item($i)->hasAttribute("name") );
		my $stage = new EPrints::Workflow::Stage( $stages->item($i), $self->{archive} );
		push @$stageout, $stage;
		$nummap->{ $stage->get_name() } = $pos++;
	}

	return ($stageout, $nummap);  
}

sub get_stage
{
	my( $self, $stage ) = @_;
  
	return $self->{stages}->[ $self->{nummap}->{$stage} ];
}

sub get_first_stage
{
	my( $self ) = @_;
	my $stage = $self->{stages}->[0];
	return $stage->get_name();
}

sub _read_flow
{
	my( $self, $doc ) = @_;

	my $flowout = [];

	my $flow = ($doc->getElementsByTagName("flow"))[0];
	if(!defined $flow)
	{
		print STDERR "Error loading workflow: No wf:flow defined\n";
		return;
	}
  
  
	my $element;
	foreach my $element ( $flow->getChildNodes )
	{
		my $name = $element->getNodeName;
		if( $name eq "wf:stage" )
		{
			push @$flowout, $element->getAttribute("ref");
		}
	}
	return $flowout;
}

1;

######################################################################
=pod

=back

=cut

