
package EPrints::Interface::Screen::Home;

use EPrints::Interface::Screen;

@ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub new
{
	my( $class, $processor ) = @_;

	$class->SUPER::new( $processor );
}

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	my $user = $self->{session}->current_user;

	$self->{processor}->{title} = $self->{session}->make_text("Home");

	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" );	

	my $dt;
	my $dd;

	my $dl =  $self->{session}->make_element( "dl" );

	$dt = $self->{session}->make_element( "dt" );
	$dd = $self->{session}->make_element( "dd" );
	$a = $self->{session}->render_link( "?XXX" );
	$a->appendChild( $self->{session}->html_phrase( "cgi/users/home:new_item_link" ) );
	$dt->appendChild( $a );
	$dd->appendChild( $self->{session}->html_phrase( "cgi/users/home:new_item_info" ) );
	$dl->appendChild( $dt );
	$dl->appendChild( $dd );

	$dt = $self->{session}->make_element( "dt" );
	$dd = $self->{session}->make_element( "dd" );
	$a = $self->{session}->render_link( "?XXX" );
	$a->appendChild( $self->{session}->html_phrase( "cgi/users/home:import_item_link" ) );
	$dt->appendChild( $a );
	$dd->appendChild( $self->{session}->html_phrase( "cgi/users/home:import_item_info" ) );
	$dl->appendChild( $dt );
	$dl->appendChild( $dd );


	$chunk->appendChild( $dl );	


	### Get the items in the buffer
	my $ds = $self->{session}->get_repository->get_dataset( "eprint" );
	my $list = $self->{session}->current_user->get_owned_eprints( $ds );

	if( $list->count == 0 )
	{
		$chunk->appendChild( $self->{session}->html_phrase( "cgi/users/home:no_pending" ) );
	}
	else
	{
		my $div = $self->{session}->make_element( "div" );
		$chunk->appendChild( $div );
		$list->map( sub {
			my( $session, $dataset, $e ) = @_; 

			my $div2 = $session->make_element( "div", style=>"padding-top: 0.5em" );
			my $a = $session->render_link( "?eprintid=".$e->get_id."&screen=EPrint::View::Owner" );
			$a->appendChild( $e->render_description() );
			$div2->appendChild( $a );
			$div2->appendChild( $session->html_phrase( 
				"cgi/users/home:deposited_at",
				time=>$e->render_value( "status_changed" ) ) );
			$div->appendChild( $div2 );
		} );
	}


	return $chunk;
}

# ignore the form. We're screwed at this point, and are just reporting.
sub from
{
	my( $self ) = @_;

	return;
}




sub can_be_viewed
{
	my( $self ) = @_;

	my $r = $self->{processor}->allow( "action/deposit" );
	return 0 unless $r;

	return $self->SUPER::can_be_viewed;
}

1;
