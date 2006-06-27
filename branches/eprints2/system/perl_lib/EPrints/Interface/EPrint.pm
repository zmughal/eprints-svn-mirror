package EPrints::Interface::EPrint;


sub screen
{
	my( $self ) = @_;

	my $screen = $self->{screenid};
	my $class = "EPrints::Interface::EPrint::\u$screen";

	eval '
		use '.$class.';
		$self->{screen} = $class;
	';

	if( $@ ) 
	{
		print STDERR $@;
	}

	return $self->{screen};
}

sub interface
{
	# Used for phrases
	return "cgi/users/edit_eprint";
}

sub process
{
	my( $class, $session ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{messages} = [];

	$self->{session} = $session;

	$self->{eprintid} = $session->param( "eprintid" );

	$self->{eprint} = new EPrints::DataObj::EPrint( $session, $self->{eprintid} );

	if( !defined $self->{eprint} )
	{
		$session->render_error( $session->html_phrase(
			"cgi/users/edit_eprint:cant_find_it",
			id=>$session->make_text( $self->{eprintid} ) ) );
		return;
	}

	$self->{dataset} = $self->{eprint}->get_dataset;

	$self->{screenid} = $session->param( "screen" );
	$self->{screenid} = "control" unless defined $self->{screenid};
	$self->{action} = $session->param( "action" );

	$self->screen->from( $self );
		# do nothing

#		$self->add_message( "warning", $self->{session}->make_text( "came from unknown screen: ".$self->{screenid} ) ); #cjg lang


	my $content = $self->screen->render( $self );
#		$self->add_message( "warning", $self->{session}->make_text( "wanted to render unknown screen: ".$self->{screenid} ) ); #cjg lang
#		$content = $self->render_screen_control;

	$self->{page} = $self->{session}->make_doc_fragment;

	$self->{page}->appendChild( $self->render_messages );

	$self->{page}->appendChild( $self->{eprint}->render_citation );

	$self->{page}->appendChild( $content );

	$session->build_page( $self->{title}, $self->{page} );
	$session->send_page();
}

sub add_message
{
	my( $self, $type, $message ) = @_;

	push @{$self->{messages}},{type=>$type,content=>$message};
}

sub render_messages
{	
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	foreach my $message ( @{$self->{messages}} )
	{
		my $style = "border: solid 1px #0f0; background-color: #cfc; padding: 1em; margin-top: 1em";
		if( $message->{type} eq "warning" )
		{
			$style = "border: solid 1px #f80; background-color: #fec; padding: 1em; margin-top: 1em";
		}
		if( $message->{type} eq "error" )
		{
			$style = "border: solid 1px #f00; background-color: #fcc; padding: 1em; margin-top: 1em";
		}
		my $div = $self->{session}->make_element( "div", style=>$style );
		$div->appendChild( $message->{content} );
		$chunk->appendChild( $div );
	}

	return $chunk;
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "eprintid", $self->{eprintid} ) );
	$chunk->appendChild( $self->{session}->render_hidden_field( "screen", $self->{screenid} ) );

	return $chunk;
}

	

sub action_not_allowed
{
	my( $self ) = @_;

	$self->add_message( "error", $self->{session}->make_text( "Action not allowed." ) ); #cjg lang
}
	
sub make_action_bar
{
	my( $self, @actions ) = @_;

	my @list = ();
	foreach( @actions )
	{
		next unless( $self->allow_action( $_ ) );
		my $url = "?eprintid=".$self->{eprintid}."&screen=".$self->{screenid}."&action=".$_;
		my $a = $self->{session}->render_link( $url );
		$a->appendChild( $self->{session}->html_phrase( $self->interface.":action_".$_ ) );
		push @list , $a;
	}


	my $f = $self->{session}->make_doc_fragment;
	my $first = 1;
	foreach my $item ( @list )
	{
		if( $first )
		{
			$first = 0;
		}
		else
		{
			$f->appendChild( $self->{session}->make_text( " | " ) );
		}
		$f->appendChild( $item );
	}
	return $f;

}


sub allow_action 
{
	my( $self, $action ) = @_;

	my $eprint_status = $self->{eprint}->get_value( "eprint_status" );
	
	# Can we skip the buffer?
	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" ) || 0;
	
	#view_history
	#view_full
	#view_summary

    # inbox buffer archive deletion
	#   *     *       *       *      edit
	#   *     *                      remove - and send message to depositing user
	#         *                      move to inbox - and send message to user
	#   *             *              move to buffer  - "
	#         *               *      move to archive  - "
	#                 *              move to deletion  - "
	#                 *       *      clone(new version) to buffer
	#   *     *       *       *      copy(as template) to buffer


	if( $eprint_status eq "inbox" )
	{
		# moj: This is here as an abstraction of move_inbox_archive/move_inbox_buffer
		return 1 if( $action eq "deposit" );
		return 1 if( $action eq "edit_eprint" );
		return 1 if( $action eq "request_eprint_deletion" );
		if( $sb )
		{
			return 1 if( $action eq "move_eprint_inbox_archive" );
		}
		else
		{
			return 1 if( $action eq "move_eprint_inbox_buffer" );
		}
		return 1 if( $action eq "derive_eprint_version" );
	}
	elsif( $eprint_status eq "buffer" )
	{
		return 1 if( $action eq "edit_eprint" );
		return 1 if( $action eq "request_eprint_deletion" );
		return 1 if( $action eq "move_eprint_buffer_inbox" && defined $self->{eprint}->get_user() );
		return 1 if( $action eq "move_eprint_buffer_archive" );
		return 1 if( $action eq "derive_eprint_version" );
	}
	elsif( $eprint_status eq "archive" )
	{
		return 1 if( $action eq "edit_eprint" );
		if( $sb )
		{
			return 1 if( $action eq "move_eprint_archive_inbox" );
		}
		else
		{
			return 1 if( $action eq "move_eprint_archive_buffer" );
		}
		return 1 if( $action eq "move_eprint_archive_deletion" );
		return 1 if( $action eq "derive_eprint_clone" );
		return 1 if( $action eq "derive_eprint_version" );
	}
	elsif( $eprint_status eq "deletion" )
	{
		return 1 if( $action eq "edit_eprint" );
		return 1 if( $action eq "move_eprint_deletion_archive" );
		return 1 if( $action eq "derive_eprint_clone" );
		return 1 if( $action eq "derive_eprint_version" );
	}

	return 1 if( $action eq "view_history" );
	return 1 if( $action eq "view_full" );
	return 1 if( $action eq "view_summary" );
	return 1 if( $action eq "view_export" );
	return 1 if( $action eq "view_staffexport" );
	return 1 if( $action eq "view_edit" );
	return 1 if( $action eq "view_staffedit" );
	
	return 1 if( $action eq "view_buffer" );

	return 0;
# FORMS
# reject-with-email
# remove-with-email
# deposit
# request_delete 

# ACTIONS
# 6 move (8 move,actually)
# destroy
# link to buffer page
# use as template
# new version

# 3 views
# summary, full, history

# edit eprint!

}

1;
