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

	if( $self->{processor}->{action} eq "" )
	{
		return;
	}

	if( defined $self->{actions}->{$self->{processor}->{action}} )
	{
		my $fn = "action_".$self->{processor}->{action};
		$self->$fn;
		return;
	}

	$self->{processor}->add_message( "error",
		$self->{session}->html_phrase(
	      		"cgi/users/edit_eprint:unknown_action",
			action=>$self->{session}->make_text( $self->{processor}->{action} ),
			screen=>$self->{session}->make_text( $self->{processor}->{screenid} ) ) );
}

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_text( "Error. \$screen->render should be sub-classed for $self." );
}


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
	my @core = ();
	my @other = ();
	foreach my $tool ( $self->get_allowed_tools )
	{
		if( $tool->{core} )
		{
			push @core, $tool;
		}
		else
		{
			push @other, $tool;
		}
	}

	my $first;

	$first = 1;
	foreach my $tool ( @core )
	{
		if( $first )
		{
			$first = 0;
		}
		else
		{
			$div->appendChild( $self->{session}->html_phrase( "tool:divide" ) );
		}
		my $a = $self->{session}->render_link( "?screen=".$tool->{screen} );
		$a->appendChild( $self->{session}->html_phrase( "tool:".$tool->{id} ) );
		$div->appendChild( $a );
	}

	if( scalar @other )
	{
		$div->appendChild( $self->{session}->html_phrase( "tool:divide" ) );
		my $more = $self->{session}->make_element( "a", id=>"ep_user_menu_more", class=>"ep_only_js", href=>"#", onClick => "EPJS_toggle('ep_user_menu_more',true,'inline');EPJS_toggle('ep_user_menu_extra',false,'inline');return false", );
		$more->appendChild( $self->{session}->html_phrase( "tool:all" ) );
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
					$self->{session}->html_phrase( "tool:divide" ) );
			}
			my $a = $self->{session}->render_link( "?screen=".$tool->{screen} );
			$a->appendChild( $self->{session}->html_phrase( "tool:".$tool->{id} ) );
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
			$self->{processor}->{screenid} ) );

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

sub show_in
{
	return();
}



sub get_position
{
	my( $self, $list_id ) = @_;

	my %s = $self->show_in;

	return $s{$list_id};
}	

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "show_in" )
	{
		my %shown_in = $self->show_in;
		return defined $shown_in{$param};
	}

	return $self->SUPER::matches( $test, $param );
}

sub render_title
{
	my( $self ) = @_;

	return $self->{session}->make_text( $self->{id} );
}

1;
