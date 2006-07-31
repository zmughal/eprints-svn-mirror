
package EPrints::Plugin::Screen::Review;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub render
{
	my( $self ) = @_;

	my $user = $self->{session}->current_user;

	$self->{processor}->{title} = $self->{session}->html_phrase( "cgi/users/buffer:overview_title" ), 

	my( $page, $p, $table, $tr, $td, $th, $link );

	$page = $self->{session}->make_doc_fragment();

	# Get EPrints in the submission buffer
	my $list = $user->get_editable_eprints();
	
	if( $list->count == 0 )
	{
		# No EPrints
		$page->appendChild( $self->{session}->html_phrase( 
			"cgi/users/buffer:no_entries",
			scope=>$user->render_value( "editperms" ) ) );
		return $page;
	}

	$page->appendChild( $self->{session}->html_phrase( 
		"cgi/users/buffer:buffer_blurb",
		scope=>$user->render_value( "editperms" ) ) );

	$table = $self->{session}->make_element( "table", border=>0, cellpadding=>4, cellspacing=>0 );
	$page->appendChild( $table );
	$tr = $self->{session}->make_element( "tr", class=>"header_plain" );
	$table->appendChild( $tr );
	
	$th = $self->{session}->make_element( "th" );
	$th->appendChild( $self->{session}->html_phrase( "cgi/users/buffer:title" ) );
	$tr->appendChild( $th );

	$th = $self->{session}->make_element( "th" );
	$th->appendChild( $self->{session}->html_phrase( "cgi/users/buffer:sub_by" ) );
	$tr->appendChild( $th );

	$th = $self->{session}->make_element( "th" );
	$th->appendChild( $self->{session}->html_phrase( "cgi/users/buffer:sub_date" ) );
	$tr->appendChild( $th );

	my $info = {row => 1};

	$list->map( sub {
		my( $session, $dataset, $e, $info ) = @_;

		$tr = $session->make_element( "tr", class=>"row_".($info->{row}%2?"b":"a") );
		$table->appendChild( $tr );

		# Title
		$td = $session->make_element( "td", class=>"first_col" );
		$tr->appendChild( $td );
		$link = $session->render_link( "?screen=EPrint::View::Editor&eprintid=".$e->get_value("eprintid") );
		$link->appendChild( $e->render_description() );
		$td->appendChild( $link );
		
		# Link to user
		my $user = new EPrints::User( $session, $e->get_value( "userid" ) );
		
		$td = $session->make_element( "td", class=>"middle_col" );
		$tr->appendChild( $td );
		if( defined $user )
		{
#cjg Has view-user priv?
			$td->appendChild( $user->render_citation_link( undef, 1 ) );
		}
		else
		{
			$td->appendChild( $session->html_phrase( "cgi/users/buffer:invalid" ) );
		}
	
		my $buffds = $session->get_repository->get_dataset( "buffer" );	
		
		$td = $session->make_element( "td", class=>"last_col" );
		$tr->appendChild( $td );
		$td->appendChild( $buffds->get_field( "datestamp" )->render_value( $session, $e->get_value( "datestamp" ) ) );
		++$info->{row};
	}, $info );

	return $page;
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
