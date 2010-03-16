package EPrints::Plugin::Event::Delete_Plan_Docs;

@ISA = qw( EPrints::Plugin::Event );

use strict;

sub delete_plan_docs
{
	my( $self, $format ) = @_;

	my $session = $self->{session};
	

	if (defined $format)
        {

                $format =~ s/\//_/;
                $format =~ s/\\/_/;
		
		my $dataset = $session->get_repository->get_dataset( "preservation_plan" );	
                
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
                        my $result = $self->remove_documents($preservation_plan);
                });
	}
}

sub remove_documents {

        my ( $self, $preservation_plan ) = @_;

        my $session = $self->{session};

        my $pres_plan_uri = $preservation_plan->internal_uri();

        my $dataset = $session->get_repository->get_dataset( "document" );

        my $searchexp = EPrints::Search->new(
                        session => $session,
                        dataset => $dataset,
                        filters => [
                        { meta_fields => [qw( relation_uri )], value => "$pres_plan_uri", match => "EX" },
                        ],
                        );

        my $list = $searchexp->perform_search;

        $list->map( sub {
                my $document = $_[2];
                $document->remove();
        });

        return 1;

}

1;
