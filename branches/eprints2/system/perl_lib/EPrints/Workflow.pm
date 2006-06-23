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

B<EPrints::Workflow> - Models the submission process used by an repository. 

=head1 DESCRIPTION

The workflow class handles loading the workflow configuration for a 
single repository. 

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

use EPrints::Workflow::Stage;

use strict;

######################################################################
=pod

=item $language = EPrints::Workflow->new( $session, $workflow_id, %params )

Create a new workflow object representing the specification given in
the workflow.xml configuration

# needs more config - about object etc.

=cut
######################################################################

sub new
{
	my( $class , $session, $workflow_id, %params ) = @_;

	my $self = {};

	bless $self, $class;
	
	$self->{repository} = $session->get_repository;
	$self->{session} = $session;
	$self->{dataset} = $params{item}->get_dataset;
	$self->{item} = $params{item};
	$self->{workflow_id} = $workflow_id;
	$self->{autosend} = $params{autosend};
	unless( defined $self->{autosend} ) { $self->{autosend} = 1; }

	$self->{raw_config} = $self->{repository}->get_workflow_config( $self->{dataset}->confid, $workflow_id );
	$self->{config} = EPrints::Utils::collapse_conditions( $session, $self->{raw_config}, %params );

	$self->_read_flow;
	$self->_read_stages;

	print STDERR "Workflow loaded\n";
	return( $self );
}

sub append_stage
{
	my( $self, $stage_id, $stage ) = @_;

	$self->{stage_order} = [ @{$self->{stage_order}}, $stage_id ];
	$self->{stages}->{$stage_id} = $stage;
	$self->renumber_stages;
}

sub prepend_stage
{
	my( $self, $stage_id, $stage ) = @_;

	$self->{stage_order} = [ $stage_id, @{$self->{stage_order}} ];
	$self->{stages}->{$stage_id} = $stage;
	$self->renumber_stages;
}

sub renumber_stages
{
	my( $self ) = @_;

	my $n = 0;
	$self->{stage_number} = {};
	foreach my $stage_id ( @{$self->{stage_order}} )
	{
		$self->{stage_number}->{$stage_id} = $n;
		$n += 1;
	}
}

sub _read_flow
{
	my( $self, $doc ) = @_;

	$self->{stage_order} = [];
	$self->{stage_number} = {};

	my $flow = ($self->{config}->getElementsByTagName("flow"))[0];
	if(!defined $flow)
	{
		EPrints::abort( "Workflow (".$self->{dataset}->confid.",".$self->{workflow_id}.") - no <flow> element.\n" );
		return;
	}
	my $has_stages = 0; 
	foreach my $element ( $flow->getChildNodes )
	{
		my $name = $element->getNodeName;
		if( $name eq "stage" )
		{
			if( !$element->hasAttribute("ref") )
			{
				EPrints::abort( "Workflow (".$self->{dataset}->confid.",".$self->{workflow_id}.") - <stage> in <flow> has no ref attribute." );
			}
			my $ref = $element->getAttribute("ref");
			push @{$self->{stage_order}}, $ref;
			$has_stages = 1;
		}
	}

	if( $has_stages == 0 )
	{
		EPrints::abort( "Workflow (".$self->{dataset}->confid.",".$self->{workflow_id}.") - no stages in <flow> element.\n" );
	}
	$self->renumber_stages;
}


sub _read_stages
{
	my( $self ) = @_;
	print STDERR "Reading stages\n";

	$self->{stages}={};

	foreach my $element ( $self->{config}->getChildNodes )
	{
		my $e_name = $element->getNodeName;
		next unless( $e_name eq "stage" );

		if( !$element->hasAttribute("name") )
		{
			EPrints::abort( "Workflow (".$self->{dataset}->confid.",".$self->{workflow_id}.") - <element> definition has no name attribute.\n".$element->toString );
		}
		my $stage_id = $element->getAttribute("name");
print STDERR "***$stage_id\n".$self->{item}."\n";
		$self->{stages}->{$stage_id} = new EPrints::Workflow::Stage( $element, $self );
	}

	foreach my $stage_id ( @{$self->{stage_order}} )
	{
		if( !defined $self->{stages}->{$stage_id} )
		{
			EPrints::abort( "Workflow (".$self->{dataset}->confid.",".$self->{workflow_id}.") - stage $stage_id defined in <flow> but not actually defined in the body of the workflow\n" );
		}
	}
}

sub get_stage_ids
{
	my( $self ) = @_;

	return @{$self->{stage_order}};
}

# note - this can return a stage not in the flow, but defined in the body.
sub get_stage
{
	my( $self, $stage_id ) = @_;
  
	return $self->{stages}->{$stage_id};
}

sub get_first_stage_id
{
	my( $self ) = @_;

	return $self->{stage_order}->[0];
}

sub get_last_stage_id
{
	my( $self ) = @_;

	return $self->{stage_order}->[-1];
}

sub get_next_stage_id
{
	my( $self ) = @_;

	my $num = $self->{stage_number}->{$self->{curr_stage}};

	if( $num == scalar @{$self->{stage_order}}-1 )
	{
		return $self->{curr_stage};
	}

	return $self->{stage_order}->[$num+1];
}

sub get_prev_stage_id
{
	my( $self ) = @_;
	my $num = $self->{stage_number}->{$self->{curr_stage}};
	if( $num == 0 )
	{
		return undef;
	}

	return $self->{stage_order}->[$num-1];
}


sub process
{
	my( $self ) = @_;
	
	$self->{action}    = $self->{session}->get_action_button();
	$self->{stage}     = $self->{session}->param( "stage" );
	$self->{user}      = $self->{session}->current_user();
	$self->{dataview}  = $self->{session}->param( "dataview" );

	$self->{problems} = [];
	my $ok = 1;


	if( $self->{action} eq "jump" )
	{
		$self->{new_stage} = $self->{stage};
	}
	else
	{
		# Process data from previous stage

		if( !defined $self->{stage} )
		{
			$self->{stage} = $self->get_first_stage_id;
		}
			
		# If we don't have an item then something's
		# gone wrong.
		if( !defined $self->{item} )
		{
			$self->_corrupt_err;
			return( 0 );
		}

		if( !defined $self->{stages}->{$self->{stage}} )
		{
			# Not a valid stage
			$self->_corrupt_err;
			return( 0 );
		}
		
		my $stage_obj = $self->get_stage( $self->{stage} );
		$ok = $stage_obj->validate();
		$ok = 0; #moj	
		if( $ok )
		{
			$self->{new_stage} = $self->get_next_stage_id;
		}
		else
		{
			$self->{new_stage} = $self->{stage};
		}
	}
	
#	if( $ok )
#	{
		# Render stuff for next stage
		my $stage = $self->{new_stage};

#		if( $self->{session}->get_repository->get_conf( 'log_submission_timing' ) )
#		{
#			if( $stage ne "meta" )
#			{
#				$self->log_submission_stage($stage);
#			}
#			# meta gets logged after pageid is worked out
#		}
	
		
		my $form = $self->{session}->render_form( "post", $self->{formtarget}."#t" );
		
		my $hidden_fields = {
			stage => $stage,
		};

		foreach (keys %$hidden_fields)
		{
			$form->appendChild( $self->{session}->render_hidden_field(
			$_,
			$hidden_fields->{$_} ) );
		}

		# Add the stage components

		my $stage_obj = $self->get_stage( $stage );
		my $stage_dom;
		$stage_dom = $stage_obj->render( $self->{session}, $self );

		$form->appendChild( $stage_dom );
		
		if( $self->{autosend} )
		{	
			my $title_phraseid = "metapage_title_".$stage;
			$self->{session}->build_page(
				$self->{session}->html_phrase( 
					$title_phraseid,
					type => $self->{item}->render_value( "type" ),
					desc => $self->{item}->render_description ),
				$form,
				"submission_".$stage );
			$self->{session}->send_page();
		}
		else
		{
			$self->{page} = $form;
		}
#	}
	return( 1 );
}


######################################################################
# 
# $s_form->_corrupt_err
#
######################################################################

sub _corrupt_err
{
	my( $self ) = @_;

	$self->{session}->render_error( 
		$self->{session}->html_phrase( 
			"lib/submissionform:corrupt_err",
			line_no => 
				$self->{session}->make_text( (caller())[2] ) ),
		$self->{session}->get_repository->get_conf( "userhome" ) );

}

######################################################################
# 
# $s_form->_database_err
#
######################################################################

sub _database_err
{
	my( $self ) = @_;

	$self->{session}->render_error( 
		$self->{session}->html_phrase( 
			"lib/submissionform:database_err",
			line_no => 
				$self->{session}->make_text( (caller())[2] ) ),
		$self->{session}->get_repository->get_conf( "userhome" ) );
}








# static method to return all workflow documents for a single repository

sub load_all
{
	my( $path ) = @_;

	my $v = {};
	my $dh;
	opendir( $dh, $path ) || die "Could not open $path";
	# This sorts the directory such that directories are last
	my @filenames = sort { -d "$path/$a" <=> -d "$path/$b" } readdir( $dh );
	foreach my $fn ( @filenames )
	{
		next if( $fn =~ m/^\./ );
		next if( $fn eq "CVS" );
		next if( $fn eq ".svn" );
		my $filename = "$path/$fn";
		if( -d $filename )
		{
			$v->{$fn} = load_all( $filename );
			next;
		}
		if( $fn=~m/^(.*)\.xml$/ )
		{
			my $doc = EPrints::XML::parse_xml( $filename );
			$v->{$1} = $doc->getDocumentElement();
		}
	}
	return $v;
}

1;

######################################################################
=pod

=back

=cut

