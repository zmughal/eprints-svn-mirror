=head1 NAME

EPrints::Plugin::Export::SummaryPage

=cut

package EPrints::Plugin::Export::SummaryPage;

use EPrints::Plugin::Export::HTMLFile;

@ISA = ( "EPrints::Plugin::Export::HTMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "Summary Page";
	$self->{accept} = [];
	$self->{visible} = "all";
	$self->{advertise} = 0;
	$self->{qs} = 0.9;

	return $self;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my $repo = $self->{session};

	return "" if !$repo->get_online;

	my $title = $dataobj->render_citation( "summary_title" );
	my $page = $dataobj->render_citation( "summary_page" );
	$repo->build_page( $title, $page, "export" );
	$repo->send_page;

	return "";
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

