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
		$list->map( sub {
			my $preservation_plan = $_[2];
			my $file_path = $preservation_plan->get_value("file_path");
			unlink($file_path);
			if (!-s "$file_path") {
				$preservation_plan->remove();
			} else {
				$failed_flag = 1;
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

