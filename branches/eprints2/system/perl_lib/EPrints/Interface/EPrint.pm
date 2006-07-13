package EPrints::Interface::EPrint;

use EPrints::Interface::EPrint::Edit;
#use EPrints::Interface::EPrint::Deposit;
use EPrints::Interface::EPrint::Control;

use strict;

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
		if( $screen ne "control" )
		{
			$self->add_message( 
				"error", 
				$self->{session}->html_phrase( 
					"cgi/users/edit_eprint:unknown_screen",
					screen=>$self->{session}->make_text( $screen ) ) );
			$self->{screenid} = "control";
			return $self->screen;
		}
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
	my( $class, %opts ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{messages} = [];
	$self->{before_messages} = [];

	if( !defined $opts{session} ) 
	{
		EPrints::abort( "session not passed to EPrints::Interface::EPrint->process" );
	}
	foreach my $k ( keys %opts )
	{
		$self->{$k} = $opts{$k};
	}

	$self->{eprintid} = $self->{session}->param( "eprintid" );
	$self->{eprint} = new EPrints::DataObj::EPrint( $self->{session}, $self->{eprintid} );

	if( !defined $self->{eprint} )
	{
		$self->{session}->render_error( $self->{session}->html_phrase(
			"cgi/users/edit_eprint:cant_find_it",
			id=>$self->{session}->make_text( $self->{eprintid} ) ) );
		return;
	}

	$self->{dataset} = $self->{eprint}->get_dataset;

	$self->{screenid} = $self->{session}->param( "screen" );
	$self->{screenid} = "control" unless defined $self->{screenid};
	$self->{action} = $self->{session}->get_action_button;

	$self->screen->from( $self );

	if( defined $self->{redirect} )
	{
		$self->{session}->redirect( $self->{redirect} );
		return;
	}

	my $content = $self->screen->render( $self );

	$self->{page} = $self->{session}->make_doc_fragment;

	my $citation = $self->{session}->render_toolbox( 
		$self->{session}->make_text( "Current item" ),
		$self->{eprint}->render_citation  );
	$self->{page}->appendChild( $citation );
	foreach my $chunk ( @{$self->{before_messages}} )
	{
		$self->{page}->appendChild( $chunk );
	}
	$self->{page}->appendChild( $self->render_messages );

	$self->{page}->appendChild( $content );

	$self->{session}->build_page( $self->{title}, $self->{page} );
	$self->{session}->send_page();
}

sub before_messages
{
	my( $self, $chunk ) = @_;

	push @{$self->{before_messages}},$chunk;
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
		my $id = "m".$self->{session}->get_next_id;
		my $div = $self->{session}->make_element( "div", class=>"ep_".$message->{type}, id=>$id );
		my $title_div = $self->{session}->make_element( "div", class=>"ep_".$message->{type}."_title" );
		my $close_a =  $self->{session}->make_element( "a", onclick=>'document.getElementById( "'.$id.'" ).style.display = "none"; return false;', href=>'#' );
		my $close = $self->{session}->make_element( "img", src=>"/images/style/close.gif", class=>"ep_close_icon js_only" );
		$close_a->appendChild( $close );
		my $content_div = $self->{session}->make_element( "div", class=>"ep_".$message->{type}."_content" );
		$title_div->appendChild( $close_a );
		$title_div->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:message_".$message->{type} ) );
		my $table = $self->{session}->make_element( "table" );
		my $tr = $self->{session}->make_element( "tr" );
		$table->appendChild( $tr );
		my $td1 = $self->{session}->make_element( "td" );
		$td1->appendChild( $self->{session}->make_element( "img", src=>"/images/style/".$message->{type}.".png" ) );
		$tr->appendChild( $td1 );
		my $td2 = $self->{session}->make_element( "td" );
		$tr->appendChild( $td2 );
		$td2->appendChild( $message->{content} );
		$content_div->appendChild( $table );
		$div->appendChild( $title_div );
		$div->appendChild( $content_div );
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
	my( $self, $action ) = @_;

	$self->add_message( "error", $self->{session}->html_phrase( 
		"cgi/users/edit_eprint:action_not_allowed",
		action=>$self->{session}->html_phrase(
			"cgi/users/edit_eprint:action_$action" ) ) );
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

	my $status = $self->{eprint}->get_value( "eprint_status" );
	
	# Can we skip the buffer?
	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" ) || 0;

	if( $action eq "deposit" )
	{
		return 1 if( $status eq "inbox" && !$self->{staff} );
	}
	if( $action eq "edit_eprint" )
	{
		return 1 if( $status eq "inbox" && !$self->{staff} );
		return 1 if( $self->{staff} );
	}
	if( $action eq "remove" )
	{
		return 1 if( $status eq "inbox" && !$self->{staff} );
		return 1 if( $status eq "buffer" && $self->{staff} );
	}
	if( $action eq "reject_with_email" )
	{
		return 1 if( $status eq "buffer" && $self->{staff} );
	}
	if( $action eq "remove_with_email" )
	{
		return 1 if( $status eq "buffer" && $self->{staff} );
		return 1 if( $status eq "inbox" && $self->{staff} );
	}

	if( $action eq "move_eprint_inbox_archive" )
	{
		#return 1 if( $self->{staff} && $status eq "inbox"); 
	}
	if( $action eq "move_eprint_archive_inbox" )
	{
		#return 1 if( $self->{staff} && $status eq "archive"); 
	}

	if( $action eq "move_eprint_inbox_buffer" )
	{
		return 1 if( $self->{staff} && $status eq "inbox"); 
	}
	if( $action eq "move_eprint_buffer_inbox" )
	{
		# allowing users to do this too? is that OK?
		return 1 if( defined $self->{eprint}->get_user() && $status eq "buffer");
	}

	if( $action eq "move_eprint_buffer_archive" )
	{
		return 1 if( $self->{staff} && $status eq "buffer"); 
	}
	if( $action eq "move_eprint_archive_buffer" )
	{
		return 1 if( $self->{staff} && $status eq "archive" ); 
	}

	if( $action eq "move_eprint_archive_deletion" && $status eq "archive")
	{
		return 1 if( $self->{staff} ); 
	}
	if( $action eq "move_eprint_deletion_archive" && $status eq "deletion")
	{
		return 1 if( $self->{staff} ); 
	}

	if( $action eq "derive_eprint_clone" )
	{
		return 1;
	}
	if( $action eq "derive_eprint_version" )
	{
		return 1;
	}

	if( $action eq "request_eprint_deletion" )
	{
		return 1 if( !$self->{staff} && $status ne "inbox" );
	}

	return 0;
}

sub allow_view
{
	my( $self, $view ) = @_;

	if( $self->{staff} )
	{
		return 1 if( $view eq "staffexport" );
		return 1 if( $view eq "staffedit" );
		return 1 if( $view eq "buffer" );
		return 1 if( $view eq "history" );
	}
	else
	{
		if( $view eq "edit" )
		{
			return( $self->allow_action( "edit_eprint" ) );
		}
		return 1 if( $view eq "export" );
	}

	return 1 if( $view eq "full" );
	return 1 if( $view eq "summary" );
	return 1 if( $view eq "actions" );

	return 0;
}

sub workflow
{
	my( $interface ) = @_;

	if( !defined $interface->{workflow} )
	{
		my %opts = ( item=> $interface->{eprint}, session=>$interface->{session} );
		if( $interface->{staff} ) { $opts{STAFF_ONLY} = "TRUE"; }
 		$interface->{workflow} = EPrints::Workflow->new( $interface->{session}, "default", %opts );
	}

	return $interface->{workflow};
}

sub render_form
{
	my( $self ) = @_;

	my $form = $self->{session}->render_form( "post", $self->{url}."#t" );
	$form->appendChild( $self->{session}->render_hidden_field( "eprintid", $self->{eprintid} ) );
	$form->appendChild( $self->{session}->render_hidden_field( "screen", $self->{screenid} ) );
	return $form;
}



sub render_blister
{
	my( $interface, $sel_stage_id, $with_deposit ) = @_;

	my $eprint = $interface->{eprint};
	my $session = $interface->{session};
	my $staff = 0;

	my $workflow = $interface->workflow;
	my $table = $session->make_element( "table", cellspacing=>0, class=>"ep_blister_bar" );
	my $tr = $session->make_element( "tr" );
	$table->appendChild( $tr );
	my $first = 1;
	foreach my $stage_id ( $workflow->get_stage_ids )
	{
		if( !$first )  { $tr->appendChild( $session->make_element( "td", class=>"ep_blister_join" ) ); }
		my $td;
		if( $stage_id eq $sel_stage_id )
		{
			$td = $session->make_element( "td", class=>"ep_blister_node_selected" );
		}
		else
		{
			$td = $session->make_element( "td", class=>"ep_blister_node" );
		}
		my $a = $session->render_link( "eprint?eprintid=".$interface->{eprintid}."&screen=edit&stage=$stage_id" );
		$td->appendChild( $a );
		$a->appendChild( $session->html_phrase( "metapage_title_".$stage_id ) );
		$tr->appendChild( $td );
		$first = 0;
	}

	if( $with_deposit )
	{
		$tr->appendChild( $session->make_element( "td", class=>"ep_blister_join" ) );
		my $td;
		if( $sel_stage_id eq "deposit" ) 
		{
			$td = $session->make_element( "td", class=>"ep_blister_node_selected" );
		}
		else
		{
			$td = $session->make_element( "td", class=>"ep_blister_node" );
		}
		my $a = $session->render_link( "eprint?eprintid=".$interface->{eprintid}."&screen=deposit" );
		$td->appendChild( $a );
		$a->appendChild( $session->make_text( "Deposit" ) );
		$tr->appendChild( $td );
	}

	return $interface->{session}->render_toolbox( 
			$interface->{session}->make_text( "Deposit progress" ),
			$table );
}


1;
