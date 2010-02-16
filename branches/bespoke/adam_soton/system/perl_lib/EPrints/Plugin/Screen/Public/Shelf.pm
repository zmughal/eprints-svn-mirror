
package EPrints::Plugin::Screen::Public::Shelf;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;


sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ export_redir export /]; 

	$self->{appears} = [];

	return $self;
}

sub register_furniture
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub render_toolbar
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub from
{
	my( $self ) = @_;

        my $public = $self->{processor}->{shelf}->get_value( "public" );
	if( $public ne "TRUE" )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error",
			$self->html_phrase( "not_public" ) );
		return;
	}

	$self->SUPER::from;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return 1;
}

sub properties_from
{
	my( $self ) = @_;


	my $shelfid = $self->{session}->param( "shelfid" );
	$self->{processor}->{shelfid} = $shelfid;
	$self->{processor}->{shelf} = new EPrints::DataObj::Shelf( $self->{session}, $shelfid );

	if( !defined $self->{processor}->{shelf} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", 
			$self->html_phrase(
				"no_such_shelf",
				id => $self->{session}->make_text( 
						$self->{processor}->{shelfid} ) ) );
		return;
	}

}

sub render
{
	my( $self ) = @_;

	my $shelf = $self->{processor}->{shelf};
	my $session = $self->{session};

	my $chunk = $session->make_doc_fragment;

	my $h2 = $session->make_element('h2');
	$h2->appendChild($shelf->render_citation);
	$chunk->appendChild($h2);

	if ($shelf->is_set('description'))
	{
		my $p = $session->make_element('p');
		$p->appendChild($shelf->render_value('description'));
		$chunk->appendChild($p);
	}

	my $table = $session->make_element('table');
	$chunk->appendChild($table);

	my $n = 1;
	foreach my $item (@{$shelf->get_items})
	{
		my $tr = $session->make_element('tr');
		my $td = $session->make_element('td');
		$td->appendChild($item->render_citation_link('result', n => [$n++, "INTEGER"]));
		$tr->appendChild($td);
		$table->appendChild($tr);
	} 

	return $chunk;
}   


1;
