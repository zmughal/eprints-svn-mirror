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
			action=>$self->{session}->make_text( $self->{processor}->{action} ) ) );
}

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_text( "Error. \$screen->render should be sub-classed for $self." );
}

sub register_furniture
{
	my( $self ) = @_;

	# do nothing for now
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
print STDERR ">>>".$self->{processor}->{url}."<<<\n";
	my $form = $self->{session}->render_form( "post", $self->{processor}->{url}."#t" );

	$form->appendChild( $self->render_hidden_bits );

	return $form;
}


1;
