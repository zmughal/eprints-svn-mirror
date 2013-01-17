=head1 NAME

EPrints::Plugin::Screen::Staff::EPrintSearch

=cut


package EPrints::Plugin::Screen::Staff::EPrintSearch;

@ISA = ( 'EPrints::Plugin::Screen::AbstractSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "admin_actions_editorial",
			position => 500,
		},
	];

	return $self;
}

sub search_dataset
{
	my( $self ) = @_;

	return $self->{session}->get_repository->get_dataset( "eprint" );
}

sub search_filters
{
	my( $self ) = @_;

	return;
}

sub allow_export { return 1; }

sub allow_export_redir { return 1; }

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "staff/eprint_search" );
}

sub from
{
	my( $self ) = @_;

	my $sconf = {
		staff => 1,
		dataset_id => "eprint",
		citation => $self->{session}->get_repository->get_conf( "search","advanced","citation" ),
		order_methods => $self->{session}->get_repository->get_conf( "search","advanced","order_methods" ),
		default_order => $self->{session}->get_repository->get_conf( "search","advanced","default_order"),
	};
		
	my $adv_fields = $self->{session}->get_repository->get_conf( "search","advanced","search_fields" );
	my $extra_fields = $self->param( "extra_fields" );
	$extra_fields = [] if !defined $extra_fields;
	$sconf->{"search_fields"} = [
		{ meta_fields => [ "eprintid" ] },
		{ meta_fields => [ "userid.username" ] },
		{ meta_fields => [ "userid.name" ] },
		{ meta_fields => [ "eprint_status" ], default=>'archive buffer' },
		{ meta_fields => [ "dir" ] },
		@{$adv_fields},
		@{$extra_fields},
	];

	$self->{processor}->{sconf} = $sconf;

	$self->SUPER::from;
}

sub _vis_level
{
	my( $self ) = @_;

	return "staff";
}

sub get_controls_before
{
	my( $self ) = @_;

	return $self->get_basic_controls_before;	
}

sub render_result_row
{
	my( $self, $session, $result, $searchexp, $n ) = @_;

	return $result->render_citation_link_staff(
			$self->{processor}->{sconf}->{citation},  #undef unless specified
			n => [$n,"INTEGER"] );
}






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

