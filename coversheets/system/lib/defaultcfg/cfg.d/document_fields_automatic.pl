
$c->{set_document_automatic_fields} = sub
{
	my( $doc ) = @_;

	if ($doc->get_value('format') eq 'application/pdf')
	{

##Check the uploaded file isn't encrypted
		use PDF::API2;
		my $file_path = $doc->local_path."/".$doc->get_main;
		if (-e $file_path and $file_path =~ m/\.pdf$/i)
		{
			my $pdf = PDF::API2->open( $file_path );
			if ($pdf->isEncrypted)
			{
				my $session = $doc->{session};

				my $dataset = $session->get_repository->get_dataset( "message" );

				$dataset->create_object( $session, {
					userid => $session->current_user->get_id,
					type => 'warning',
					message => EPrints::XML::to_string($session->html_phrase('pdf_is_encypted')),
				});
			}
		}
	}

};
