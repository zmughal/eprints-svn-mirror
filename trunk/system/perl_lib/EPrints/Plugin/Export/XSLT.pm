=head1 NAME

EPrints::Plugin::Export::XSLT

=cut

package EPrints::Plugin::Export::XSLT;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub output_dataobj
{
	my( $self, $dataobj ) = @_;

	my $session;
	local $session->{xml};

	my $xml = $dataobj->to_xml;
	my $doc = $xml->ownerDocument;
	$doc->setDocumentElement( $xml );

	return $self->{stylesheet}->output_as_bytes( $doc );
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

