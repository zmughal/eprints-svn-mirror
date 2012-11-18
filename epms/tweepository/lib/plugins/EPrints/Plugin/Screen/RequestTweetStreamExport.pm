package EPrints::Plugin::Screen::RequestTweetStreamExport;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ queue_export /];

	$self->{icon} = "tweetstream_package.png";

	$self->{appears} = [
		{
			place => "dataobj_actions",
			position => 1600,
		},
		{
			place => "dataobj_view_actions",
			position => 1600,
		},
	];
	
	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless $self->{processor}->{dataset}->id eq 'tweetstream';

	return $self->allow( "tweetstream/export" );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $ts = $self->{processor}->{dataobj};

	my $div = $session->make_element( "div", class=>"ep_block" );

	if ($ts->pending_package_request || $ts->running_package_request)
	{
		$div->appendChild($self->html_phrase('package_pending'));
	}
	else
	{
		my $file = $ts->export_package_filepath;
		if (-e $file)
		{
			my $size = -s $file;
			if ($size >= (1024 * 1024))
			{
				$size = sprintf("%.1f", ($size / (1024 * 1024))) . ' MB';
			}
			elsif ($size >= 1024)
			{
				$size = sprintf("%.1f", ($size / 1024 )) . ' KB';
			}

			$size = $session->make_text($size);

			my $mtime = (stat( $file ))[9];
			my $date = $session->make_text(scalar localtime($mtime));
			my $link = $session->render_link('http://example.org/');
			$link->appendChild($session->make_text('Download'));

			$div->appendChild($self->html_phrase('package_exists', filesize => $size, datestamp => $date, 'link' => $link));
		}
		else
		{
			$div->appendChild($self->html_phrase('package_absent'));
		}
		my %buttons = ( queue_export => $self->phrase('queue_export') );

		my $form= $self->render_form;
		$form->appendChild( 
			$self->{session}->render_action_buttons( 
				%buttons ) );
		$div->appendChild( $form );
	}

#	$div->appendChild( $self->html_phrase("sure_delete",
#		title=>$self->{processor}->{dataobj}->render_description() ) );
#

	return( $div );
}	

sub action_queue_export
{
	my( $self ) = @_;

	my $ds = $self->repository->dataset('tsexport');
	my $tweetstreamid = $self->{processor}->{dataobj}->id;
	$ds->create_object( $self->repository, { tweetstream => $tweetstreamid } );


	$self->{processor}->add_message( "message",
                $self->html_phrase( "export_queued" ) );

	#$self->{processor}->{screenid} = $self->{processor}->{dataobj}->view_screen;
}

1;

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

