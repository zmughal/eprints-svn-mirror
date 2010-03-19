package EPrints::Plugin::Screen::Admin::TestDataImport;

@ISA = ( 'EPrints::Plugin::Screen' );

#use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ test_data_import /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 998, 
			#action => "repository_classify",
		},
	];

	return $self;
}

sub allow_regen_views
{
	my( $self ) = @_;

	return $self->allow( "config/edit" );
}

sub render
{
	my( $plugin ) = @_;

	my $session = $plugin->{session};
	
	my $repo = $session->get_repository->get_id();
	
	my $dataset = $session->get_repository->get_dataset( "eprint" );
	my $count = $dataset->count( $session );

	my( $html, $h1 );
	
	$html = $session->make_doc_fragment;

	if ($count > 0) {	
		my $pronom_error_div = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
		$pronom_error_div->appendChild( $plugin->{session}->make_text( "Failed : You alrady have objects in your repository" ));

		my $warning = $plugin->{session}->render_message("error",
			$pronom_error_div
		);
		$html->appendChild($warning);
		return $html;	
	}
	

	my $err_file = File::Temp->new(
                UNLINK => 1
        );

        {
        no warnings;
        open(OLD_STDERR, ">&STDERR") or die "Failed to save STDERR";
        }
        open(STDERR, ">$err_file") or die "Failed to redirect STDERR";	


	my $output = `perl /usr/share/eprints3/preserv_testdata/bin/import_test_data $repo`;

	open(STDERR,">&OLD_STDERR") or die "Failed to restore STDERR";

        seek( $err_file, 0, SEEK_SET );

	our $MAX_ERR_LEN = 1024;

        while(<$err_file>)
        {
                $_ =~ s/\s+$//;
                next unless length($_);
#		$html->appendText("$_<br/>");
		$html->appendChild( $session->make_text("$_"));
		$html->appendChild( $session->make_element( "br" ));
                last if length($err) > $MAX_ERR_LEN;
        }

	return $html;

}



1;
