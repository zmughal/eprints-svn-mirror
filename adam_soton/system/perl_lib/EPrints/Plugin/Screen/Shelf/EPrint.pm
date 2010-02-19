
package EPrints::Plugin::Screen::Shelf::EPrint;

use EPrints::Plugin::Screen::Shelf;

@ISA = ( 'EPrints::Plugin::Screen::Shelf' );

use strict;

sub properties_from
{
	my( $self ) = @_;


	$self->{processor}->{eprintid} = $self->{session}->param( "eprintid" );
	$self->{processor}->{eprint} = new EPrints::DataObj::EPrint( $self->{session}, $self->{processor}->{eprintid} );

	if( !defined $self->{processor}->{eprint} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{session}->html_phrase(
			"cgi/users/edit_eprint:cant_find_it",
			id=>$self->{session}->make_text( $self->{processor}->{eprintid} ) ) );
		return;
	}

	$self->{processor}->{'_buffer_order'} =  $self->{session}->param( '_buffer_order' );
	$self->{processor}->{'_buffer_offset'} =  $self->{session}->param( '_buffer_offset' );

	$self->SUPER::properties_from;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url .
		"&eprintid=".$self->{processor}->{eprintid} .
		"&_buffer_order=".$self->{processor}->{'_buffer_order'} .
		"&_buffer_offset=".$self->{processor}->{'_buffer_offset'}; 
}


sub render_hidden_bits
{
        my( $self ) = @_;

        my $chunk = $self->{session}->make_doc_fragment;

        $chunk->appendChild( $self->{session}->render_hidden_field( "eprintid", $self->{processor}->{eprintid} ) );
        $chunk->appendChild( $self->{session}->render_hidden_field( "_buffer_order", $self->{processor}->{_buffer_order} ) );
        $chunk->appendChild( $self->{session}->render_hidden_field( "_buffer_offset", $self->{processor}->{_buffer_offset} ) );
	

        $chunk->appendChild( $self->SUPER::render_hidden_bits );

        return $chunk;
}


1;

