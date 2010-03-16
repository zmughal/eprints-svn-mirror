package EPrints::Plugin::Screen::Admin::FormatsRisks_delete_plan;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new {
	my( $class, %params ) = @_;
 	
	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ delete_plan /];

	return $self;
}

sub action_delete_plan {
	my ( $self ) = @_;

	my $session = $self->{session};

	my $format = $self->{session}->param( "format" );
		
	print STDERR "FORMAT : " . $format . "\n";

	my $dataset = $session->get_repository->get_dataset( "preservation_plan" );

	if (defined $format) 
	{
		
		$format =~ s/\//_/;
		$format =~ s/\\/_/;
		my $searchexp = EPrints::Search->new(
				session => $session,
				dataset => $dataset,
				filters => [
				{ meta_fields => [qw( format )], value => "$format", match => "EX" },
				],
				);

		my $list = $searchexp->perform_search;
		my $failed_flag = 0;
		my $msg = "success";
		$list->map( sub {
			my $preservation_plan = $_[2];
			if ($self->in_use($preservation_plan)<1){		
				my $file_path = $preservation_plan->get_value("file_path");
				unlink($file_path);
				if (!-s "$file_path") {
					$preservation_plan->remove();
				} else {
					$msg = "failed_in_delete";
				}
			} else {
				$msg = "in_use";
			}
		});

		if ($failed_flag > 0) {
			$self->{processor}->add_message(
					"error",
					$self->html_phrase( "failed_in_delete" )
					);
		} else {
			$self->{processor}->add_message(
					"message",
					$self->html_phrase( "success" )
					);
		}
		$self->{processor}->{screenid} = "Admin::FormatsRisks";
	} else {
		$self->{processor}->add_message(
				"error",
				$self->html_phrase( "Failed" )
				);
		$self->{processor}->{screenid} = "Admin::FormatsRisks";
	}

}

sub in_use 
{
	my ( $self, $preservation_plan ) = @_;
	
	my $session = $self->{session};

	my $dataset = $session->get_repository->get_dataset( "document" );
	
	my $pres_plan_uri = $preservation_plan->internal_uri();
	my $searchexp = EPrints::Search->new(
			session => $session,
			dataset => $dataset,
			filters => [
			{ meta_fields => [qw( relation_uri )], value => "$pres_plan_uri", match => "EX" },
			],
			);
	
	my $list = $searchexp->perform_search;
	if ($list->count() > 0) {
		return 1;
	} else {
		return 0;
	}

}

sub allow_delete_plan
{
	my( $self ) = @_;
	return 1;
}

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

1;

