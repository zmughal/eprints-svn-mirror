######################################################################
#
# EPrints::InputField
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

B<EPrints::InputField> - A single input field. 

=head1 DESCRIPTION

=over 4

=cut

package EPrints::InputField;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $dom = $params{dom};
	my $dataobj = $params{dataobj};
	my $dataset = $dataobj->get_dataset;

	# Do a few validation checks.

	if( $dom->getNodeName ne "wf:field" )
	{
		EPrints::Config::abort(
			"InputField config error: Not a wf:field node" );
	}
	if( !$dom->hasAttribute( "ref" ) )
	{
		EPrints::Config::abort(
			"InputField config error: No field ref attribute" );
	}
	
	my $self = {};

	$self->{name} = $dom->getAttribute( "ref" );
	$self->{handle} = $dataset->get_field( $self->{name} );
	
	if( !$self->{handle} )
	{
		EPrints::Config::abort(
			"InputField config error: Invalid field ref attribute" );
	}

	$self->{required} = "no";
	$self->{collapsed} = "no"; 

	if( $dom->hasChildNodes )
	{
		foreach my $child ( $dom->getChildNodes )
		{
			my $node_name = $child->getNodeName;
			if( $node_name eq "wf:required" )
			{
				$self->{required} = "yes";
			}
			elsif( $node_name eq "wf:required-for-archive" )
			{
				$self->{required} = "for_archive";
			}
			elsif( $node_name eq "wf:collapsed" )
			{
				$self->{collapsed} = "yes"; 
			}
		}
	}

	bless $self, $class;
	return $self;	
}

1;
