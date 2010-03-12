
package EPrints::Plugin::Screen::Coversheet::Edit;

use EPrints::Plugin::Screen::Coversheet;
use File::Copy;

@ISA = ( 'EPrints::Plugin::Screen::Coversheet' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

        $self->{icon} = "action_edit.png";

        $self->{appears} = [
                {
                        place => "coversheet_manager_actions",
                        position => 200,
                },
        ];

	$self->{actions} = [qw/ update exit delete_frontfile delete_backfile approve_newpages /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "coversheet/write" );
}

sub from
{
	my( $self ) = @_;

	if( defined $self->{processor}->{internal} )
	{
		my $from_ok = $self->workflow->update_from_form( $self->{processor},undef,1 );
		$self->uncache_workflow;
		return unless $from_ok;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub allow_approve_newpages
{
	my( $self ) = @_;

        my $coversheet = $self->{processor}->{coversheet};
        my $user = $self->{session}->current_user;
        return 0 unless
        (
                $coversheet->can_approve($user, 'frontfile') and
                $coversheet->can_approve($user, 'backfile')
        );

        return $self->allow( "coversheet/page/approve" );
}

sub action_approve_newpages
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Coversheet::ApproveNewPages";
}

sub allow_exit
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_exit
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::CoversheetManager";
}	

sub allow_delete_frontfile
{
	my( $self ) = @_;

	if (
		$self->{processor}->{coversheet}->get_value('status') eq 'draft' and
		$self->{processor}->{coversheet}->get_page_type('frontfile') ne 'none'
	)
	{
		return $self->can_be_viewed;
	}
	return 0;
}

sub action_delete_frontfile
{
	my( $self ) = @_;

	$self->_delete_file('frontfile');
}	

sub allow_delete_backfile
{
	my( $self ) = @_;

	if (
		$self->{processor}->{coversheet}->get_value('status') eq 'draft' and
		$self->{processor}->{coversheet}->get_page_type('backfile') ne 'none'
	)
	{
		return $self->can_be_viewed;
	}
	return 0;
}

sub action_delete_backfile
{
	my( $self ) = @_;

	$self->_delete_file('backfile');
}	

sub _delete_file
{
	my ($self, $fieldname) = @_;

	$self->{processor}->{coversheet}->erase_page($fieldname);

	$self->{processor}->add_message( 'message', $self->html_phrase('file_removed'));

	$self->{processor}->{screenid} = "Coversheet::Edit";
}

sub allow_update
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_update
{
	my( $self ) = @_;

	$self->workflow->update_from_form( $self->{processor} );

	my $errors = 0;
	foreach (qw/ frontfile backfile /)
	{
		my $status = $self->save_file( $_ . '_input', $_ );
		if ($status ne 'OK')
		{
			$self->{processor}->add_message( 'error', $self->html_phrase('file_not_ok'));
			$errors++;
		}
	}

	my @problems = $self->workflow->validate();
	$errors += scalar @problems;

	$self->uncache_workflow;

	unless ($errors)
	{
		$self->{processor}->add_message( 'message', $self->html_phrase('coversheet_saved'));
	}
	$self->{processor}->{screenid} = "Coversheet::Edit";
}

sub save_file
{
	my ($self, $cgi_param, $fieldname) = @_;

	my $session = $self->{session};
	my $coversheet = $self->{processor}->{coversheet};

	if ($coversheet->get_value('status') ne 'draft') #we don't just accept files in active or depricated items, they need to be approved by another person
	{
		$coversheet->set_value($fieldname . '_proposer_id', $session->current_user->get_id);
		$coversheet->commit;
		$fieldname = 'proposed_' . $fieldname;
	}

	my $fh = $session->get_query->upload( $cgi_param );
	my $filename = $session->get_query->param( $cgi_param );

	if( defined( $fh ) )
	{
		binmode($fh);

		$filename =~ m/[^\.]*$/;
		my $extension = $&;
		my $tmpfile = File::Temp->new( SUFFIX => ".$extension" );
		binmode($tmpfile);

		use bytes;
		while(sysread($fh,my $buffer,4096)) {
			syswrite($tmpfile,$buffer);
		}
		seek($tmpfile, 0, 0);

		if ($coversheet->valid_file($tmpfile))
		{
			$coversheet->erase_page($fieldname);
			my $abs_file = $coversheet->get_path() . "/$fieldname." . lc($extension);

			copy($tmpfile, $abs_file);

			$coversheet->commit; #update lastmod
			return 'OK' if -e $abs_file;
		}
		return 'BAD';
	}
	return 'OK';#there wasn't a file, but that's OK
}


sub screen_after_flow
{
	my( $self ) = @_;

	return "Admin::CoversheetManager";
}


sub render
{
	my( $self ) = @_;

#	$self->{processor}->before_messages( 
#		$self->render_blister( $self->workflow->get_stage_id, 1 ) );

	my $form = $self->render_form;

	$form->appendChild( $self->render_buttons );
	$form->appendChild( $self->workflow->render );
	$form->appendChild( $self->render_file_buttons );
	$form->appendChild( $self->render_buttons );
	
	return $form;
}


sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url.$self->workflow->get_state_params;
}

sub render_delete_button
{
	my ($self, $fieldname) = @_;

	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	push @{$buttons{_order}}, "delete_$fieldname";
	$buttons{cancel} = $self->phrase( "delete_file" );

	return $self->{session}->render_action_buttons( %buttons );
}

sub render_file_buttons
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;
	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

##this could probably be done more cleverly...  We're replicating tests that we did in the allow_<func> subs.
	my $button_count = 0;
	if ($self->{processor}->{coversheet}->get_value('status') eq 'draft') #we can only delete pages in a draft coversheet
	{
		foreach my $fieldname (qw/ frontfile backfile /)
		{
			if ($self->{processor}->{coversheet}->get_page_type($fieldname) ne 'none')
			{
				push @{$buttons{_order}}, "delete_$fieldname";
				$buttons{"delete_$fieldname"} = $self->phrase( "delete_$fieldname" );
				$button_count++;
			}
		}
	}
	else #otherwise we have to approve pages
	{
		my $new_page_exists = 0;
		my $can_approve = 1;
		foreach my $fieldname (qw/ frontfile backfile /)
		{
			if ($self->{processor}->{coversheet}->get_page_type('proposed_' . $fieldname) ne 'none')
			{
				$new_page_exists = 1;
				unless ($self->{processor}->{coversheet}->can_approve($self->{session}->current_user, $fieldname))
				{
					$can_approve = 0;
				}
			}
		}
		if ($new_page_exists and $can_approve)
		{
			push @{$buttons{_order}}, "approve_newpages";
			$buttons{"approve_newpages"} = $self->phrase( "approve_newpages" );
			$button_count++;
		}
	}
	$frag->appendChild($self->{session}->render_action_buttons( %buttons )) if $button_count;
	return $frag;

}

sub render_buttons
{
	my( $self ) = @_;

	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	if( defined $self->workflow->get_prev_stage_id or defined $self->workflow->get_next_stage_id )
	{
		print STDERR "Multistage coversheet workflows are unsupported\n";
	}

	push @{$buttons{_order}}, "update", "exit" ;
	$buttons{'exit'} = $self->phrase( "exit" );
	$buttons{update} = $self->phrase( "update" );

	return $self->{session}->render_action_buttons( %buttons );
}

1;


