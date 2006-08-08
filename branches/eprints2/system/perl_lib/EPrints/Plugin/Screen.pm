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
	$self->{actions} = {};

	# flag to indicate that it takes some effort to make this screen, so
	# don't make it up as a tab. eg. EPrint::History.
	$self->{expensive} = 0; 

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	# no properties assumed at top levels
}

sub from
{
	my( $self ) = @_;

	my $action = $self->{processor}->{action};
	
	return if( $action eq "" );

	return if( $action eq "null" );

	my $act_priv = $self->{actions}->{$action};
	if( defined $act_priv )
	{
		if( !$self->{processor}->allow( $act_priv ) )
		{
			$self->{processor}->action_not_allowed( 
				$self->html_phrase( "action:$action:title" ) );
		}
		else
		{
			my $fn = "action_".$action;
			$self->$fn;
		}
		return;
	}

	$self->{processor}->add_message( "error",
		$self->{session}->html_phrase( 
	      		"Plugin/Screen:unknown_action",
			action=>$self->{session}->make_text( $action ),
			screen=>$self->{session}->make_text( $self->{processor}->{screenid} ) ) );
}

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_text( "Error. \$screen->render should be sub-classed for $self." );
}


## remove this!
sub get_allowed_tools
{
	my $tools = [
		{
			      id => "eprints",
			    priv => "view/eprints",
			position => 100,
	 		    core => 1,
			  screen => "Items",
		},
		{
			      id => "user",
			    priv => "view/user",
			position => 200,
	 		    core => 1,
			  screen => "User",
		},
		{
			      id => "subscription",
			    priv => "view/subscription",
			position => 300,
	 		    core => 1,
			  screen => "Subscription",
		},
		{
			      id => "edreview",
			    priv => "view/editor",
			position => 400,
	 		    core => 1,
			  screen => "Review",
		},
		{
			      id => "status",
			    priv => "view/status",
			position => 1100,
	 		    core => 0,
			  screen => "Status",
		},
		{
			      id => "search_eprint",
			    priv => "view/search/eprint",
			position => 1200,
	 		    core => 0,
			  screen => "Search::EPrint",
		},
		{
			      id => "search_user",
			    priv => "view/search/user",
			position => 1300,
	 		    core => 0,
			  screen => "Search::User",
		},
		{
			      id => "add_user",
			    priv => "view/add_user",
			position => 1400,
	 		    core => 0,
			  screen => "AddUser",
		},
		{
			      id => "subject",
			    priv => "view/subject_tool",
			position => 1500,
	 		    core => 0,
			  screen => "Subject",
		},
	];

	return sort { $a->{position} <=> $b->{position} } @{$tools};
}

sub register_furniture
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;

	#my $div = $self->{session}->make_element( "div", style=>"padding-bottom: 4px; border-bottom: solid 1px black; margin-bottom: 8px;" );
	my $div = $self->{session}->make_element( "div", style=>"margin-bottom: 8px; text-align: center;
        background-image: url(/images/style/toolbox.png);
        border-top: solid 1px #d8dbef;
        border-bottom: solid 1px #d8dbef;
	padding-top:4px;
	padding-bottom:4px;
 " );

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
		my $more = $self->{session}->make_element( "a", id=>"ep_user_menu_more", class=>"ep_only_js", href=>"#", onClick => "EPJS_toggle('ep_user_menu_more',true,'inline');EPJS_toggle('ep_user_menu_extra',false,'inline');return false", );
		$more->appendChild( $self->{session}->html_phrase( "Plugin/Screen:tool_divide" ) );	
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
		
	$f->appendChild( $div );

	$self->{processor}->before_messages( $f );
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

	return 1 unless defined $self->{priv};

	return $self->{processor}->allow( $self->{priv} );
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
		next if( defined $screen->{priv} && !$self->allow( $screen->{priv} ) );

		foreach my $opt ( @{$screen->{appears}} )
		{
			next if( $opt->{place} ne $list_id );
			my $p = $opt->{position};
			$p = 999999 if( !defined $p );
			if( defined $opt->{action} )
			{
 				next if( !$self->allow( $screen->{actions}->{$opt->{action}} ) );
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

sub allow
{
	my( $self, $priv ) = @_;

	my $allow_code = $self->{processor}->allow( $priv );

	return $allow_code;
}


		
1;
