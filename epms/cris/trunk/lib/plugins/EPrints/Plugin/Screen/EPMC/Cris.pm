=head1 NAME

EPrints::Plugin::Screen::EPMC::Cris

=cut

package EPrints::Plugin::Screen::EPMC::Cris;

use EPrints::Plugin::Screen::EPMC;

@ISA = ( 'EPrints::Plugin::Screen::EPMC' );

use strict;

sub render_messages
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;

	if(
		$repo->dataset( "eprint" )->has_field( "funders" ) &&
		!$repo->dataset( "eprint" )->field( "funders" )->isa( "EPrints::MetaField::Dataobjref" )
	  )
	{
		$frag->appendChild(
			$repo->render_message( "warning", $self->html_phrase( "error_funders" ) )
		);
	}

	return $frag;
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

