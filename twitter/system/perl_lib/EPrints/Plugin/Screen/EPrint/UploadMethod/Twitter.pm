package EPrints::Plugin::Screen::EPrint::UploadMethod::Twitter;

#Note that the location of these plugins may have changed.  See install documentation.

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
	my $twitter = EPrints::Feed::Twitter->new($document);
	$twitter->create_main_file;

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


#The following is forwards or backwards compatibility.
#...on a related note, I sometimes find development confusing....

sub render_add_document
{
        my ( $self, $basename ) = @_;
        return $self->render($basename);

}

sub render_tab_title
{
        my( $self ) = @_;

        return $self->{session}->html_phrase( "Plugin/Screen/EPrint/UploadMethod/Twitter:title" );
}

sub update_from_form
{
        my( $self, $processor ) = @_;

        my $doc_data = {
                _parent => $self->{dataobj},
                eprintid => $self->{dataobj}->get_id,
                format=>"text/plain",
                content=>'feed/twitter',
                };

        my $repository = $self->{session}->get_repository;

        my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
        my $document = $doc_ds->create_object( $self->{session}, $doc_data );
        if( !defined $document )
        {
                $processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
                return;
        }
        my $success = 1;
        foreach my $fieldname (qw/twitter_expiry_date twitter_hashtag/)
        {
                my $value;
                if ($fieldname eq 'twitter_expiry_date')
                {
                        my ($year,$day,$month) =
                        (
                                $self->{session}->param( $fieldname . '_year' ),
                                $self->{session}->param( $fieldname . '_month' ),
                                $self->{session}->param( $fieldname . '_day' )
                        );
                        $value = $year;
                        if ($value and $month)
                        {
                                $value .= '-' . $year;
                                if ($day)
                                {
                                        $value .= '-' . $day;
                                }
                        }
                }
                else
                {
                        $value = $self->{session}->param( $fieldname);
                }
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
        my $twitter = EPrints::Feed::Twitter->new($document);
        $twitter->create_main_file;

        $document->commit;

        $processor->{notes}->{upload_plugin}->{to_unroll}->{$document->get_id} = 1;
}



1;
