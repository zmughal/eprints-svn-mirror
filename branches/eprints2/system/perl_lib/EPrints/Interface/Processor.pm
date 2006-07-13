package EPrints::Interface::Processor;

use EPrints::Interface::Screen::EPrint;
use EPrints::Interface::Screen::EPrint::Edit;
use EPrints::Interface::Screen::EPrint::Deposit;

use strict;

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

	$self->{screenid} = $self->{session}->param( "screen" );
	$self->{screenid} = "Home" unless defined( $self->{screenid} );

	# This loads the properties of what the screen is about,
	# Rather than parameters for the action, if any.
	$self->screen->properties_from; 
	
	$self->{action} = $self->{session}->get_action_button;

	$self->screen->from;

	if( defined $self->{redirect} )
	{
		$self->{session}->redirect( $self->{redirect} );
		return;
	}

	$self->screen->register_furniture;

	my $content = $self->screen->render;

	$self->{page} = $self->{session}->make_doc_fragment;

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


sub screen
{
	my( $self ) = @_;

	my $screen = $self->{screenid};
	my $class = "EPrints::Interface::Screen::$screen";

	eval '
		use '.$class.';
		$self->{screen} = $class->new( $self );
	';

	if( $@ ) 
	{
		print STDERR $@;
		if( $screen ne "Error" )
		{
			$self->add_message( 
				"error", 
				$self->{session}->html_phrase( 
					"cgi/users/edit_eprint:unknown_screen",
					screen=>$self->{session}->make_text( $screen ) ) );
			$self->{screenid} = "Error";
			return $self->screen;
		}
	}

	return $self->{screen};
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


sub action_not_allowed
{
	my( $self, $action ) = @_;

	$self->add_message( "error", $self->{session}->html_phrase( 
		"cgi/users/edit_eprint:action_not_allowed",
		action=>$self->{session}->html_phrase(
			"cgi/users/edit_eprint:action_$action" ) ) );
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


1;
