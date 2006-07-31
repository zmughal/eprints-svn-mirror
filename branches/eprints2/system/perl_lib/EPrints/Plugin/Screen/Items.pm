
package EPrints::Plugin::Screen::Items;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;


sub from
{
	my( $self ) = @_;

	my $user = $self->{session}->current_user;

	if( $self->{processor}->{action} eq "create" )
	{
		if( !$self->{processor}->allow( "action/eprint/create" ) )
		{
			$self->{processor}->action_not_allowed( $a );
			return;
		}

		my $ds = $self->{processor}->{session}->get_repository->get_dataset( "inbox" );

		$self->{processor}->{eprint} = $ds->create_object( $self->{session}, { 
			userid => $user->get_value( "userid" ) } );

		if( !defined $self->{processor}->{eprint} )
		{
			my $db_error = $self->{session}->get_database->error;
			$self->{processor}->{session}->get_repository->log( "Database Error: $db_error" );
			$self->{processor}->add_message( 
				"error",
				$self->{processor}->{session}->make_text( "Database Error" ) );
			return;
		}

		$self->{processor}->{eprintid} = $self->{processor}->{eprint}->get_id;
		$self->{processor}->{screenid} = "EPrint::Edit";

		return;
	}

	return;
}





sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	my $user = $self->{session}->current_user;

	$self->{processor}->{title} = $self->{session}->make_text("Items");

	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" );	

	my $dt;
	my $dd;

	my $dl =  $self->{session}->make_element( "dl" );

	$dt = $self->{session}->make_element( "dt" );
	$dd = $self->{session}->make_element( "dd" );
	$a = $self->{session}->render_link( "?screen=Items&_action_create=1" );
	$a->appendChild( $self->{session}->html_phrase( "cgi/users/home:new_item_link" ) );
	$dt->appendChild( $a );
	$dd->appendChild( $self->{session}->html_phrase( "cgi/users/home:new_item_info" ) );
	$dl->appendChild( $dt );
	$dl->appendChild( $dd );

	$dt = $self->{session}->make_element( "dt" );
	$dd = $self->{session}->make_element( "dd" );
	$a = $self->{session}->render_link( "?screen=Items::Import" );
	$a->appendChild( $self->{session}->html_phrase( "cgi/users/home:import_item_link" ) );
	$dt->appendChild( $a );
	$dd->appendChild( $self->{session}->html_phrase( "cgi/users/home:import_item_info" ) );
	$dl->appendChild( $dt );
	$dl->appendChild( $dd );


	$chunk->appendChild( $dl );	


	### Get the items in the buffer
	my $ds = $self->{session}->get_repository->get_dataset( "eprint" );
	my $list = $self->{session}->current_user->get_owned_eprints( $ds );
	$list = $list->reorder( "-status_changed" );


	if( $list->count == 0 )
	{
		$chunk->appendChild( $self->{session}->html_phrase( "cgi/users/home:no_pending" ) );
		return $chunk;
	}

	my $table = $self->{session}->make_element( "table", cellspacing=>0 );
	$chunk->appendChild( $table );
	$list->map( sub {
		my( $session, $dataset, $e ) = @_; 

		my $tr = $session->make_element( "tr" );

		my $style = "";
		my $status = $e->get_value( "eprint_status" );

		if( $status eq "inbox" )
		{
			$style="background-color: #ffc;";
		}
		if( $status eq "buffer" )
		{
			$style="background-color: #ddf;";
		}
		if( $status eq "archive" )
		{
			$style="background-color: #cfc;";
		}
		if( $status eq "deletion" )
		{
			$style="background-color: #ccc;";
		}
		$style.=" border-bottom: 1px solid #888; padding: 4px;";

		my $td;

		$td = $session->make_element( "td", style=>$style." text-align: center;" );
		$tr->appendChild( $td );
		$td->appendChild( $e->render_value( "eprint_status" ) );

		$td = $session->make_element( "td", style=>$style );
		$tr->appendChild( $td );
		$td->appendChild( $e->render_value( "status_changed" ) );

		$td = $session->make_element( "td", style=>$style );
		$tr->appendChild( $td );
		my $a = $session->render_link( "?eprintid=".$e->get_id."&screen=EPrint::View::Owner" );
		$a->appendChild( $e->render_description() );
		$td->appendChild( $a );
		
		$table->appendChild( $tr );
	} );


	return $chunk;
}


sub can_be_viewed
{
	my( $self ) = @_;

	my $r = $self->{processor}->allow( "action/deposit" );
	return 0 unless $r;

	return $self->SUPER::can_be_viewed;
}

1;
