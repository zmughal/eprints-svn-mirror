
package EPrints::Plugin::Screen::Shelf;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{shelfid} = $self->{session}->param( "shelfid" );
	$self->{processor}->{shelf} = new EPrints::DataObj::Shelf( $self->{session}, $self->{processor}->{shelfid} );

	if( !defined $self->{processor}->{shelf} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{session}->html_phrase(
			"cgi/users/edit_shelf:cant_find_it",
			id=>$self->{session}->make_text( $self->{processor}->{shelfid} ) ) );
		return;
	}

	$self->{processor}->{dataset} = $self->{processor}->{shelf}->get_dataset;

	$self->SUPER::properties_from;
}


sub allow
{
	my( $self, $priv ) = @_;

	return 0 unless defined $self->{processor}->{shelf};

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

	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "title" ) );
	$f->appendChild( $self->{session}->make_text( ": " ) );

	my $title = $self->{processor}->{shelf}->render_citation( "screen" );

	$f->appendChild( $title );

	return $f;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&shelfid=".$self->{processor}->{shelfid};
}

sub register_error
{
	my( $self ) = @_;

	if( $self->{processor}->{shelf}->has_owner( $self->{session}->current_user ) )
	{
		$self->{processor}->add_message( "error", $self->{session}->html_phrase( 
			"Plugin/Screen/Shelf:owner_denied",
			screen=>$self->{session}->make_text( $self->{processor}->{screenid} ) ) );
	}
	else
	{
		$self->SUPER::register_error;
	}
}


sub workflow
{
	my( $self, $staff ) = @_;

	my $cache_id = "workflow";
	$cache_id.= "_staff" if( $staff ); 

	if( !defined $self->{processor}->{$cache_id} )
	{
		my %opts = ( item=> $self->{processor}->{shelf}, session=>$self->{session} );
		$opts{STAFF_ONLY} = [$staff ? "TRUE" : "FALSE","BOOLEAN"];
 		$self->{processor}->{$cache_id} = EPrints::Workflow->new( $self->{session}, $self->workflow_id, %opts );
	}

	return $self->{processor}->{$cache_id};
}

sub workflow_id
{
	return "default";
}

sub uncache_workflow
{
	my( $self ) = @_;

	delete $self->{session}->{id_counter};
	delete $self->{processor}->{workflow};
	delete $self->{processor}->{workflow_staff};
}

sub render_blister
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment; #we've only got one page, we don't need the blisters.

}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "shelfid", $self->{processor}->{shelfid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}
1;

