
######################################################################
#
# EPrints::Plugin::InputForm::Component
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

B<EPrints::Plugin::InputForm::Component> - A single form component 

=cut

package EPrints::Plugin::InputForm::Component;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::InputForm::Component::ABSTRACT = 1;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Base component plugin: This should have been subclassed";
	$self->{visible} = "all";

	return $self;
}

=pod

=item $bool = $component->parse_config( $config_dom )

Parses the supplied DOM object and populates $component->{config}

=cut

sub parse_config
{
	my( $self, $session, $config_dom ) = @_;
}

=pod

=item $bool = $component->is_required()

returns true if this component is required to be completed before the
workflow may proceed

=cut

sub is_required
{
	my( $self ) = @_;
	return 0;
}

=pod

=item $bool = $component->is_collapsed()

returns true if this component is to be rendered in a compact form
(for example, just title / required / help).

=cut

sub is_collapsed
{
	my( $self ) = @_;
	return 0;
}

sub are_all_collapsed
{
	my( $self, $fields ) = @_;
	foreach my $field ( @$fields )
	{
		return 0 if( $field->{collapsed} ne "yes" );
	}
	return 1;
}

=pod

=item $help = $component->render_help( $session, $surround )

Returns DOM containing the help text for this component.

=cut

sub render_help
{
	my( $self, $session, $surround ) = @_;
}

=pod

=item $name = $component->get_name()

Returns the unique name of this field (for prefixes, etc).

=cut

sub get_name
{
	my( $self ) = @_;
}

=pod

=item $title = $component->render_title( $session, $surround )

Returns the title of this component as a DOM object.

=cut

sub render_title
{
	my( $self, $session, $surround ) = @_;
}

=pod

=item $content = $component->render_content( $session, $surround )

Returns the DOM for the content of this component.

=cut

sub render_content
{
	my( $self, $session, $surround ) = @_;
}

######################################################################
1;
