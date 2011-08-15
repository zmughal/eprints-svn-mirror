package EPrints::Plugin::Export::TweetStream::HTML;


our @ISA = qw( EPrints::Plugin::Export::HTMLFile );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

        $self->{name} = "HTML";
        $self->{accept} = [ 'dataobj/tweetstream' ];
        $self->{visible} = "all";

	return $self;
}

sub output_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $repository = $dataobj->repository;

	my $title = $dataobj->render_citation;

	my $body = $dataobj->render_items_actual;


	my $page = $repository->xhtml->page({title=>$title, page=> $body});


	$page->send;
	exit;
}

sub initialise_fh
{
	my( $plugin, $fh ) = @_;

	binmode($fh, ":utf8");
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

