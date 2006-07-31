package EPrints::Interface::Processor;

use strict;

sub process
{
	my( $class, %opts ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{messages} = [];
	$self->{after_messages} = [];
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
	$self->{screenid} = "FirstTool" unless EPrints::Utils::is_set( $self->{screenid} );

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

	# used to swap to a different screen if appropriate
	$self->screen->about_to_render;
	
	# rendering

	if( !$self->screen->can_be_viewed )
	{
		$self->{screenid} = "Error";
		$self->add_message( "error", $self->{session}->html_phrase( 
			"cgi/users/edit_eprint:screen_not_allowed" ) );
	}
	
	$self->screen->register_furniture;

	my $content = $self->screen->render;

	$self->{page} = $self->{session}->make_doc_fragment;

	foreach my $chunk ( @{$self->{before_messages}} )
	{
		$self->{page}->appendChild( $chunk );
	}
	$self->{page}->appendChild( $self->render_messages );
	foreach my $chunk ( @{$self->{after_messages}} )
	{
		$self->{page}->appendChild( $chunk );
	}

	$self->{page}->appendChild( $content );

	$self->{session}->build_page( $self->{title}, $self->{page} );
	$self->{session}->send_page();
}

sub before_messages
{
	my( $self, $chunk ) = @_;

	push @{$self->{before_messages}},$chunk;
}

sub after_messages
{
	my( $self, $chunk ) = @_;

	push @{$self->{after_messages}},$chunk;
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
	my $plugin_id = "Screen::".$screen;
	$self->{screen} = $self->{session}->plugin( $plugin_id, processor=>$self );

	if( !defined $self->{screen} )
	{
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
		my $div = $self->{session}->make_element( "div", class=>"ep_msg_".$message->{type}, id=>$id );
		my $content_div = $self->{session}->make_element( "div", class=>"ep_msg_".$message->{type}."_content" );
		my $table = $self->{session}->make_element( "table" );
		my $tr = $self->{session}->make_element( "tr" );
		$table->appendChild( $tr );
		my $td1 = $self->{session}->make_element( "td" );
		$td1->appendChild( $self->{session}->make_element( "img", src=>"/images/style/".$message->{type}.".png", alt=>$self->{session}->phrase( "cgi/users/edit_eprint:message_".$message->{type} ) ) );
		$tr->appendChild( $td1 );
		my $td2 = $self->{session}->make_element( "td" );
		$tr->appendChild( $td2 );
		$td2->appendChild( $message->{content} );
		$content_div->appendChild( $table );
#		$div->appendChild( $title_div );
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
			"priv:action/$action" ) ) );
}

# 0 = not allowed
# 1 = for anybody
# 2 = for registered user
# 4 = for owner of item
# 8 = for editor of item

# for_user and on_item required for some privs	
sub allow
{
	my( $self, $priv, $on_item, $for_user ) = @_;

	if( !defined $for_user )
	{
		$for_user = $self->{session}->current_user;
	}

	if( $priv=~s/^action\/// )
	{
		return $self->allow_action( $priv, $on_item, $for_user );
	}

	if( $priv=~s/^view\/// )
	{
		return $self->allow_view( $priv, $on_item, $for_user );
	}

	return 0;
}

sub allow_action
{
	my( $self, $action, $on_item, $for_user ) = @_;

	if( $action=~s/^eprint\/// )
	{
		return $self->allow_eprint_action( $action, $on_item, $for_user );
	}
	
	if( $action eq "deposit" )
	{
		return $for_user->has_priv( "deposit" );
	}

	return 0;
}

sub allow_eprint_action
{
	my( $self, $action, $on_item, $for_user ) = @_;
	
	# all actions are action/eprint/...

	# need to do before we get the status as the eprint does not 
	# exist yet for "create"
	return 4 if( $action eq "create" );

	if( !defined $on_item )
	{
		$on_item = $self->{eprint};
	}

	my $status = $on_item->get_value( "eprint_status" );
	
	# Can we skip the buffer?
	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" ) || 0;


	my $r = 0;
	if( $for_user->is_owner( $on_item ) )
	{	
		if( $status eq "inbox" )
		{
			$r |= 4 if( $action eq "deposit" );
			$r |= 4 if( $action eq "edit" );
			$r |= 4 if( $action eq "remove" );
		}
		if( $status eq "buffer" )
		{
			$r |= 4 if( $action eq "move_buffer_inbox" );
			$r |= 4 if( $action eq "request_deletion" );
		}
		if( $status eq "archive" )
		{
			$r |= 4 if( $action eq "request_deletion" );
		}
		$r |= 4 if( $action eq "derive_clone" );
		$r |= 4 if( $action eq "derive_version" );
	}

	if( $for_user->can_edit( $on_item ) )
	{	
		if( $status eq "inbox" )
		{
			$r |= 8 if( $action eq "remove_with_email" );
			$r |= 8 if( $action eq "move_inbox_archive" );
			$r |= 8 if( $action eq "move_inbox_buffer" );
		}
		if( $status eq "buffer" )
		{
			$r |= 8 if( $action eq "remove_with_email" );
			$r |= 8 if( $action eq "reject_with_email" );
			$r |= 8 if( $action eq "move_buffer_inbox" && defined $on_item->get_user );
			$r |= 8 if( $action eq "move_buffer_archive" );
		}
		if( $status eq "archive" )
		{
			$r |= 8 if( $action eq "move_archive_inbox" && defined $on_item->get_user );
			$r |= 8 if( $action eq "move_archive_buffer" );
			$r |= 8 if( $action eq "move_archive_deletion" );
		}
		if( $status eq "deletion" )
		{
			$r |= 8 if( $action eq "move_deletion_archive" );
		}

		$r |= 8 if( $action eq "derive_clone" );
		$r |= 8 if( $action eq "derive_version" );
		$r |= 8 if( $action eq "edit_staff" );
	}

	$r |= 2 if( $action eq "derive_clone" );
	$r |= 2 if( $action eq "derive_version" );

	return $r;
}

sub allow_view
{
	my( $self, $view, $on_item, $for_user ) = @_;

	if( $view=~s/^eprint\/// )
	{
		return $self->allow_eprint_view( $view, $on_item, $for_user );
	}

	return 0;
}

sub allow_eprint_view
{
	my( $self, $view, $on_item, $for_user ) = @_;

	if( !defined $on_item )
	{
		$on_item = $self->{eprint};
	}

	my $status = $on_item->get_value( "eprint_status" );

	my $r = 0;

	if( $for_user->is_owner( $on_item ) )
	{
		$r |= 4 if( $view eq "edit" && $self->allow("action/eprint/edit", $on_item, $for_user ) );
		$r |= 4 if( $view eq "export" );
		$r |= 4 if( $view eq "full" );
		$r |= 4 if( $view eq "summary" );
		$r |= 4 if( $view eq "actions" );
		$r |= 4 if( $view eq "view" );
		$r |= 4 if( $view eq "view/owner" );
	}

	if( $for_user->can_edit( $on_item ) )
	{
		$r |= 8 if( $view eq "edit_staff" && $self->allow("action/eprint/edit_staff", $on_item, $for_user ) );
		$r |= 8 if( $view eq "export_staff" );
		$r |= 8 if( $view eq "history" );
		$r |= 8 if( $view eq "full" );
		$r |= 8 if( $view eq "summary" );
		$r |= 8 if( $view eq "actions" );
		$r |= 8 if( $view eq "view" );
		$r |= 8 if( $view eq "view/editor" );
	}

	if( $status eq "archive" )
	{
		$r |= 2 if( $view eq "view" );
		$r |= 2 if( $view eq "view/other" );
		$r |= 2 if( $view eq "export" );
		$r |= 2 if( $view eq "summary" );
		$r |= 2 if( $view eq "actions" );
	}

	return $r;
}


1;
