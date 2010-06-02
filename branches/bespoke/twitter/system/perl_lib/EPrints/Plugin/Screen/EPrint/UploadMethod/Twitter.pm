package EPrints::Plugin::Screen::EPrint::UploadMethod::Twitter;

use EPrints::Plugin::Screen::EPrint::UploadMethod;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod );

use strict;

sub new
{
	my( $self, %params ) = @_;

	return $self->SUPER::new(
		appears => [
			{ place => "upload_methods", position => 1 },
		],
		%params );
}

sub from
{
	my( $self, $basename ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};

	my $document = $eprint->create_subdataobj( "documents", {
		format => "text/plain",
		content => 'feed/twitter',
	});
	if( !defined $document )
	{
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}

        my $success = 1;
        foreach my $fieldname (qw/twitter_expiry_date twitter_hashtag/)
        {
                my $value = $document->get_dataset->get_field($fieldname)->form_value($session, $document);
                if ($value)
                {
                        $document->set_value($fieldname, $value);
                }
                else
                {
                        $success = 0;
                }

        }

	if( !$success )
	{
		$document->remove();
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:upload_failed" ) );
		return;
	}

	#this probably isn't storage layer friendly.
	my $filename = File::Temp->new;
	my $twitter = EPrints::Feed::Twitter->new($filename);
	
	open FILE,">$filename" or print STDERR "Couldn't open $filename\n";
	print FILE $twitter->file_header;
	close FILE;

	$document->add_file($filename,'twitter.txt');

	$document->commit;

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$document->get_id} = 1;
}


sub render
{
        my( $self, $basename ) = @_;

        my $session = $self->{session};
        my $f = $session->make_doc_fragment;

        my $add_format_button = $session->render_button(
                value => $session->phrase( "Plugin/InputForm/Component/Upload:add_format" ),
                class => "ep_form_internal_button",
                name => "_internal_".$basename."_add_format_".$self->get_id );

        my $table = $session->make_element('table', class => 'ep_multi');
        my $ds = $session->get_dataset('document');

        foreach my $fieldname( qw/twitter_hashtag twitter_expiry_date/ )
        {
                my $field = $ds->get_field($fieldname);
                $table->appendChild($session->render_row(
                        $session->html_phrase("document_fieldname_$fieldname"),
                        $field->render_input_field($session,undef,$ds),
                ));
        }


        $f->appendChild( $table );
        $f->appendChild( $add_format_button );

        return $f;
}


1;
