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
	my( $self ) = @_;

	my $session = $self->{session};
	
	my $repo = $session->get_repository->get_id();
	
	my $dataset = $session->get_repository->get_dataset( "eprint" );
	my $count = $dataset->count( $session );

	my( $html, $h1 );
	
	$html = $session->make_doc_fragment;

	if ($count > 0) {	
		my $pronom_error_div = $session->make_element(
			"div",
			align => "center"
			);	
		$pronom_error_div->appendChild( $session->make_text( "Failed : You alrady have objects in your repository" ));

		my $warning = $session->render_message("error",
			$pronom_error_div
		);
		$html->appendChild($warning);
		return $html;	
	}
	
	my $db = $session->get_database;

	$userid = 1 unless defined $userid;
	$datasetid = "archive" unless defined $datasetid;

	my $datapath = $EPrints::SystemSettings::conf->{base_path}."/testdata/preserv_testdata/data";

	my $ds = $session->get_archive()->get_dataset( $datasetid );

	my $pluginid = "Import::XML";
	my $plugin = $session->plugin( $pluginid );

	my $infile = $datapath."/data.xml.gz";

	my $fh;
	open( $fh, "gunzip -c $infile |" ) || die "Can't gunzip file.";
	my $list = $plugin->input_fh( dataset=>$ds, fh=>$fh, filename=>$infile );
	close $fh; 
	
	$html = $session->make_doc_fragment;
	
	my $title = $session->make_element("h2");
	$title->appendChild($self->html_phrase("imported"));
	my $imported_element = $session->make_doc_fragment();
	my $flag;
	foreach my $imported (@{$list->{ids}}) {
		$flag = 1;
		my $href = $session->get_repository->get_conf("base_url") . "/" . $imported;
		my $element = $session->make_element("a", href=>$href);
		$element->appendChild($session->make_text($href));
		$imported_element->appendChild($element);
		$imported_element->appendChild($session->make_element("br"));
	}

	$html->appendChild($title);

	if (defined $flag) {
		$html->appendChild($imported_element);
	}

	return $html;

}



1;