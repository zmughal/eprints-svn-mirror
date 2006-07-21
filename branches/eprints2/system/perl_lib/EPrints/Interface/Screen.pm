package EPrints::Interface::Screen;

# Top level screen.
# Abstract.
# 

sub new
{
	my( $class, $processor ) = @_;

	return bless { session=>$processor->{session}, processor=>$processor }, $class;
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

	my @options = ( 'deposit','user profile','subscriptions','editorial review' );
	my %links = ( 
		deposit=>"control?screen=Home",
		"user profile"=>"control?screen=Home",
		subscriptions=>"control?screen=Home",
		'editorial review'=>"control?screen=Review" );
	foreach( @options )
	{
		my $a = $self->{session}->render_link( $links{$_} );
		$a->appendChild( $self->{session}->make_text( "\u$_" ) );
		$div->appendChild( $a );
		$div->appendChild( $self->{session}->make_text( " | " ) );
	}
	my $more = $self->{session}->make_element( "a", id=>"ep_user_menu_more", class=>"ep_js_only", href=>"#", onClick => "Element.toggle('ep_user_menu_more');Element.toggle('ep_user_menu_extra');return false", );
	$more->appendChild( $self->{session}->make_text( "all tools..." ) );
	$div->appendChild( $more );

	my $span = $self->{session}->make_element( "span", id=>"ep_user_menu_extra", style=>"display: none", class=>"ep_no_js" );
	$div->appendChild( $span );
	foreach( @options, @options, @options, @options )
	{
		my $a = $self->{session}->render_link( $links{$_} );
		$a->appendChild( $self->{session}->make_text( "\u$_" ) );
		$span->appendChild( $a );
		$span->appendChild( $self->{session}->make_text( " | " ) );
	}

	
		
	$f->appendChild( $div );

	$self->{processor}->before_messages( $f );
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "screen", $self->{processor}->{screenid} ) );

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

	return 1;
}

1;
