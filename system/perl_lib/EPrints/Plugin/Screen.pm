package EPrints::Plugin::Screen;

# Top level screen.
# Abstract.
# 

use strict;

our @ISA = qw/ EPrints::Plugin /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{session} = $self->{processor}->{session};
	$self->{actions} = [];

	# flag to indicate that it takes some effort to make this screen, so
	# don't make it up as a tab. eg. EPrint::History.
	$self->{expensive} = 0; 

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	my $user = $self->{session}->current_user;
	if( defined $user )
	{
		$self->{processor}->{user} = $user;
		$self->{processor}->{userid} = $user->get_value( "userid" );
	}

}

sub render
{
	my( $self ) = @_;

	return $self->html_phrase( "no_render_subclass", screen => $self );
}

sub render_links
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub register_furniture
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub render_toolbar
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", class=>"ep_toolbar" );

	my @core = $self->list_items( "key_tools" );
	my @other = $self->list_items( "other_tools" );

	my $first = 1;
	foreach my $tool ( @core )
	{
		if( $first )
		{
			$first = 0;
		}
		else
		{
			$div->appendChild( $self->{session}->html_phrase( "Plugin/Screen:tool_divide" ) );
		}
		my $a = $self->{session}->render_link( "?screen=".substr($tool->{screen_id},8) );
		$a->appendChild( $tool->{screen}->render_title );
		$div->appendChild( $a );
	}

	if( scalar @other == 1 )
	{
		$div->appendChild( $self->{session}->html_phrase( "Plugin/Screen:tool_divide" ) );	
		my $tool = $other[0];
		my $a = $self->{session}->render_link( "?screen=".substr($tool->{screen_id},8) );
		$a->appendChild( $tool->{screen}->render_title );
		$div->appendChild( $a );
	}
	elsif( scalar @other > 1 )
	{
		$div->appendChild( $self->{session}->html_phrase( "Plugin/Screen:tool_divide" ) );	
		my $more = $self->{session}->make_element( "a", id=>"ep_user_menu_more", class=>"ep_only_js", href=>"#", onClick => "EPJS_toggle_type('ep_user_menu_more',true,'inline');EPJS_toggle_type('ep_user_menu_extra',false,'inline');return false", );
		$more->appendChild( $self->{session}->html_phrase( "Plugin/Screen:more" ) );	
		$div->appendChild( $more );

		my $span = $self->{session}->make_element( "span", id=>"ep_user_menu_extra", class=>"ep_no_js" );
		$div->appendChild( $span );

		$first = 1;
		foreach my $tool ( @other )
		{
			if( $first )
			{
				$first = 0;
			}
			else
			{
				$span->appendChild( 
					$self->{session}->html_phrase( "Plugin/Screen:tool_divide" ) );
			}
			my $a = $self->{session}->render_link( "?screen=".substr($tool->{screen_id},8) );
			$a->appendChild( $tool->{screen}->render_title );
			$span->appendChild( $a );
		}
	
	}
		
	return $div;
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( 
		$self->{session}->render_hidden_field( 
			"screen", 
			substr($self->{id},8) ) );

	return $chunk;
}

sub wishes_to_export
{
	my( $self ) = @_;

	return 0;
}

sub export
{
	my( $self ) = @_;

	print "Needs to be subclassed\n";
}
sub export_mimetype
{
	my( $self ) = @_;

	return "text/plain";
}

	
sub render_form
{
	my( $self ) = @_;

	my $form = $self->{session}->render_form( "post", $self->{processor}->{url}."#t" );

	$form->appendChild( $self->render_hidden_bits );

	return $form;
}

sub about_to_render 
{
	my( $self ) = @_;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 1;
}

sub allow_action
{
	my( $self, $action_id ) = @_;
	my $ok = 0;
	foreach my $an_action ( @{$self->{actions}} )
	{
		if( $an_action eq $action_id )
		{
			$ok = 1;
			last;
		}
	}

	return( 0 ) if( !$ok );

	my $fn = "allow_".$action_id;
	return $self->$fn;
}

sub from
{
	my( $self ) = @_;

	my $action_id = $self->{processor}->{action};
	
	return if( $action_id eq "" );

	return if( $action_id eq "null" );

	# If you hit reload after login you can cause a
	# login action, so we'll just ignore it.
	return if( $action_id eq "login" );

	my $ok = 0;
	foreach my $an_action ( @{$self->{actions}} )
	{
		if( $an_action eq $action_id )
		{
			$ok = 1;
			last;
		}
	}

	if( !$ok )
	{
		$self->{processor}->add_message( "error",
			$self->{session}->html_phrase( 
	      			"Plugin/Screen:unknown_action",
				action=>$self->{session}->make_text( $action_id ),
				screen=>$self->{session}->make_text( $self->{processor}->{screenid} ) ) );
		return;
	}

	if( $self->allow_action( $action_id ) )
	{
		my $fn = "action_".$action_id;
		$self->$fn;
	}
	else
	{
		$self->{processor}->action_not_allowed( 
			$self->html_phrase( "action:$action_id:title" ) );
	}
}

sub allow
{
	my( $self, $priv ) = @_;

	return 1 if( $self->{session}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{session}->current_user );
	return $self->{session}->current_user->allow( $priv );
}


# these methods all could be properties really


sub matches 
{
	my( $self, $test, $param ) = @_;

	return $self->SUPER::matches( $test, $param );
}

sub render_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

sub list_items
{
	my( $self, $list_id ) = @_;

	my @screens = $self->{session}->plugin_list( type => "Screen" );
	my @list_items = ();
	foreach my $screen_id ( @screens )
	{	
		my $screen = $self->{session}->plugin( 
			$screen_id, 
			processor => $self->{processor} );
		next if( !defined $screen->{appears} );

		my @things_in_list = ();
		foreach my $opt ( @{$screen->{appears}} )
		{
			next if( $opt->{place} ne $list_id );
			push @things_in_list, $opt;
		}
		next if( scalar @things_in_list == 0 );

		# must be done after checking things in the list
		# to prevent actions looping.
		next if( !$screen->can_be_viewed );
	
		foreach my $opt ( @things_in_list )
		{	
			my $p = $opt->{position};
			$p = 999999 if( !defined $p );
			if( defined $opt->{action} )
			{
 				next if( !$screen->allow_action( $opt->{action} ) );
			}

			push @list_items, {
				screen => $screen,
				screen_id => $screen_id,
				action => $opt->{action},
				position => $p,
			};
		}
	}

	return sort { $a->{position} <=> $b->{position} } @list_items;
}	

sub action_allowed
{
	my( $self, $item ) = @_;
	my $who_allowed;
	if( defined $item->{action} )
	{
 		$who_allowed = $item->{screen}->allow_action( $item->{action} );
	}
	else
	{
		$who_allowed = $item->{screen}->can_be_viewed;
	}

	return 0 unless( $who_allowed & $self->who_filter );
	return 1;
}

sub action_list
{
	my( $self, $list_id ) = @_;

	my @list = ();
	foreach my $item ( $self->list_items( $list_id ) )
	{
		next unless $self->action_allowed( $item );

		push @list, $item;
	}

	return @list;
}


sub who_filter { return 255; }

sub get_description
{
	my( $self, $params ) = @_;
	my $description;
	if( defined $params->{action} )
	{
		my $action = $params->{action};
		$description = $params->{screen}->html_phrase( "action:$action:description" );
	}
	else
	{
		$description = $params->{screen}->html_phrase( "description" );
	}
	return $description;
}

sub render_action_button
{
	my( $self, $params ) = @_;
	
	my $session = $self->{session};
		
	my $form = $session->render_form( "form" );

	$form->appendChild( $session->render_hidden_field( "screen", substr( $params->{screen_id}, 8 ) ) );
	foreach my $id ( @{$params->{hidden}} )
	{
		$form->appendChild( $session->render_hidden_field( $id, $self->{processor}->{$id} ) );
	}
	my( $action, $title );
	if( defined $params->{action} )
	{
		$action = $params->{action};
		$title = $params->{screen}->phrase( "action:$action:title" );
	}
	else
	{
		$action = "null";
		$title = $params->{screen}->phrase( "title" );
	}
	$form->appendChild( 
		$session->render_button(
			class=>"ep_form_action_button",
			name=>"_action_$action", 
			value=>$title ));
	return $form;
}

sub render_action_button_if_allowed
{
	my( $self, $params, $hidden ) = @_;

	if( $self->action_allowed( $params ) )
	{
		return $self->render_action_button( { %$params, hidden => $hidden } ); 
	}
	else
	{
		return $self->{session}->make_doc_fragment;
	}
}

sub render_action_list
{
	my( $self, $list_id, $hidden ) = @_;

	my $session = $self->{session};

	# TODO css me!
	my $table = $session->make_element( "table", style=>"margin: auto" );
	foreach my $params ( $self->action_list( $list_id ) )
	{
		my $tr = $session->make_element( "tr" );
		$table->appendChild( $tr );

		# TODO css me!
		my $td = $session->make_element( "td", style=>"text-align: right; padding: 0.25em 0 0.25em 0" );
		$tr->appendChild( $td );
		$td->appendChild( $self->render_action_button( { %$params, hidden => $hidden } ) );

		my $td2 = $session->make_element( "td" );
		$tr->appendChild( $td2 );

		$td2->appendChild( $session->make_text( " - " ) );

		my $td3 = $session->make_element( "td" );
		$tr->appendChild( $td3 );
		$td3->appendChild( $self->get_description( $params ) );
	}

	return $table;
}


sub render_action_list_bar
{
	my( $self, $list_id, $hidden ) = @_;

	my $session = $self->{session};

	my $div = $self->{session}->make_element( "div", style=>" margin-bottom: 4px; margin-top: 4px; " );
	my $table = $session->make_element( "table", style=>"margin:auto" );
	$div->appendChild( $table );
	my $tr = $session->make_element( "tr" );
	$table->appendChild( $tr );
	foreach my $params ( $self->action_list( $list_id ) )
	{
		my $td = $session->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( $self->render_action_button( { %$params, hidden => $hidden } ) );
	}

	return $div;
}


1;

		
		
