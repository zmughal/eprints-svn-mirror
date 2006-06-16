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
	


sub allow_action 
{
	my( $self, $action ) = @_;

	#view_history
	#view_full
	#view_summary
	return 0 if( $action eq "deposit" && $self->{eprint}->get_value( "eprint_status" ) ne "inbox" );

	return 1;
	return 1 if( $action eq "view_summary" );
# FORMS
# reject-with-email
# remove-with-email
# deposit
# request_delete 

# ACTIONS
# 6 move (8 move,actually)
# destory
# link to buffer page
# use as template
# new version

# 3 views
# summary, full, history

# edit eprint!

}

1;
