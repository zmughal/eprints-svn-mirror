
package EPrints::Plugin::Screen::EPrint;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

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

	$self->{processor}->{dataset} = $self->{processor}->{eprint}->get_dataset;

	$self->SUPER::properties_from;
}

sub allow
{
	my( $self, $priv ) = @_;

	return 0 unless defined $self->{processor}->{eprint};

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	$priv =~ s/^eprint\//eprint\/$status\//;	

	return 1 if( $self->{session}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{session}->current_user );
	return $self->{session}->current_user->allow( $priv, $self->{processor}->{eprint} );
}

sub render_tab_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

sub render_title
{
	my( $self ) = @_;

	my $priv = $self->allow( "eprint/view" );
	my $owner  = $priv & 4;
	my $editor = $priv & 8;

	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "title" ) );
	$f->appendChild( $self->{session}->make_text( ": " ) );

	my $title = $self->{processor}->{eprint}->render_citation( "screen" );
	if( $owner && $editor )
	{
		$f->appendChild( $title );
	}
	else
	{
		my $a = $self->{session}->render_link( "?screen=EPrint::View&eprintid=".$self->{processor}->{eprintid} );
		$a->appendChild( $title );
		$f->appendChild( $a );
	}
	return $f;
}


sub register_furniture
{
	my( $self ) = @_;

	$self->SUPER::register_furniture;


	my $priv = $self->allow( "eprint/view" );
	my $owner  = $priv & 4;
	my $editor = $priv & 8;

	unless( $owner && $editor )
	{
		return $self->{session}->make_doc_fragment;
	}

	my $div = $self->{session}->make_element( "div",class=>"ep_block" );
	my $a_owner = $self->{session}->render_link( "?screen=EPrint::View::Owner&eprintid=".$self->{processor}->{eprintid} );
	my $a_editor = $self->{session}->render_link( "?screen=EPrint::View::Editor&eprintid=".$self->{processor}->{eprintid} );
	$div->appendChild( $self->{session}->html_phrase(
		"cgi/users/edit_eprint:view_as_either",
		owner_link=>$a_owner,
		editor_link=>$a_editor ) );

	if( defined $self->{staff} )
	{
		$div->appendChild( $self->{session}->make_text( " " ) );
		if( $self->{staff} == 0 )
		{
			$div->appendChild( $self->{session}->html_phrase(
				"cgi/users/edit_eprint:as_depositor" ));
		}
		else
		{
			$div->appendChild( $self->{session}->html_phrase(
				"cgi/users/edit_eprint:as_editor" ));
		}
		
	}

	$self->{processor}->before_messages( $div );
}


sub workflow
{
	my( $self, $staff ) = @_;

	my $cache_id = "workflow";
	$cache_id.= "_staff" if( $staff ); 

	if( !defined $self->{processor}->{$cache_id} )
	{
		my %opts = ( item=> $self->{processor}->{eprint}, session=>$self->{session} );
		if( $staff ) { $opts{STAFF_ONLY} = ["TRUE","BOOLEAN"]; }
 		$self->{processor}->{$cache_id} = EPrints::Workflow->new( $self->{session}, "default", %opts );
	}

	return $self->{processor}->{$cache_id};
}


sub render_blister
{
	my( $self, $sel_stage_id, $staff_mode ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $session = $self->{session};
	my $staff = 0;

	my $workflow = $self->workflow;
	my $table = $session->make_element( "table", cellpadding=>0, cellspacing=>0, class=>"ep_blister_bar" );
	my $tr = $session->make_element( "tr" );
	$table->appendChild( $tr );
	my $first = 1;
	my @stages = $workflow->get_stage_ids;
	if( !$staff_mode )
	{
		push @stages, "deposit";
	}
	foreach my $stage_id ( @stages )
	{
		if( !$first )  
		{ 
			my $td = $session->make_element( "td", class=>"ep_blister_join" );
			$tr->appendChild( $td );
		}
		
		my $td;
		$td = $session->make_element( "td" );
		my $class = "ep_blister_node";
		if( $stage_id eq $sel_stage_id ) 
		{ 
			$class="ep_blister_node_selected"; 
		}
		my $phrase;
		if( $stage_id eq "deposit" )
		{
			$phrase = $session->phrase( "Plugin/Screen/EPrint:deposit" );
		}
		else
		{
			$phrase = $session->phrase( "metapage_title_".$stage_id );
		}
		my $button = $session->render_button(
			name  => "_action_jump_$stage_id", 
			value => $phrase,
			class => $class );

		$td->appendChild( $button );
		$tr->appendChild( $td );
		$first = 0;
	}

	return $table;
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "eprintid", $self->{processor}->{eprintid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}
1;

