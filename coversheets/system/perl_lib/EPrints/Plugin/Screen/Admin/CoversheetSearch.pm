
package EPrints::Plugin::Screen::Admin::CoversheetSearch;

@ISA = ( 'EPrints::Plugin::Screen::AbstractSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "coversheet_tools",
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

	return $self->allow( "coversheet/search" );
}

sub from
{
	my( $self ) = @_;

	my $sconf = {
		staff => 1,
		dataset_id => "eprint",
		citation => $self->{session}->get_repository->get_conf( "search","advanced","citation" ),
		order_methods => $self->{session}->get_repository->get_conf( "search","advanced","order_methods" ),
	};
		
	$sconf->{"search_fields"} = [
		{ meta_fields => [ "documents.coversheet" ] },
		{ meta_fields => [ "eprint_status" ], default=>'archive buffer' },
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





