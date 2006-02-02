
######################################################################
#
# EPrints::Component
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

B<EPrints::Component> - A single form component 

=cut

package EPrints::Plugin::Component;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Component::ABSTRACT = 1;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Base component plugin: This should have been subclassed";
	$self->{visible} = "all";

	return $self;
}

sub render_shell
{
	my( $self, $session, $metafield, $dataset, $type ) = @_;
	my $shell = $session->make_element( "div", class => "wf_component" );
	my $name = $metafield->get_name;
	
	my $helpimg = $session->make_element( "img", src => "/images/help.gif", class => "wf_help_icon", border => "0" );
	my $reqimg = $session->make_element( "img", src => "/images/req.gif", class => "wf_req_icon", border => "0" );

	my $title = $session->make_element( "div", class => "wf_title" );

	my $helplink = $session->make_element( "a", onClick => "doToggle('help_$name')" );
	$helplink->appendChild($helpimg);

	$title->appendChild( $helplink );
	
	my $req = $dataset->field_required_in_type( $metafield, $type );
	if($req)
	{
		$title->appendChild( $reqimg );
	}
	$title->appendChild( $session->make_text(" ") );
	$title->appendChild( $metafield->render_name( $session ) );

	my $help = $session->make_element( "div", class => "wf_help", style => "display: none", id => "help_$name" );
	$help->appendChild( $metafield->render_help( $session, $metafield->get_type() ) );

	$shell->appendChild( $title );
	$shell->appendChild( $help );
	return $shell;
}

sub from_form
{
	my( $self, $modobj ) = @_;
}

sub validate
{
	return 1;
}

# all or ""
sub is_visible
{
	my( $plugin, $vis_level ) = @_;
	return( 1 ) unless( defined $vis_level );

	return( 0 ) unless( defined $plugin->{visible} );

	if( $vis_level eq "all" && $plugin->{visible} ne "all" ) {
		return 0;
	}

	return 1;
}

######################################################################
1;
