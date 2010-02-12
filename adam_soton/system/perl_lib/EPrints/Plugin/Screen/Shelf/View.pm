
package EPrints::Plugin::Screen::Shelf::View;

use EPrints::Plugin::Screen::Shelf;

@ISA = ( 'EPrints::Plugin::Screen::Shelf' );

use strict;

sub can_be_viewed
{
	my( $self ) = @_;

	return 1;
}

sub render
{
	my( $self ) = @_;

	my $shelf = $self->{processor}->{shelf};
	my $session = $self->{session};

	my $chunk = $session->make_doc_fragment;
	my $table = $session->make_element('table');
	$chunk->appendChild($table);

	foreach my $item (@{$shelf->get_items})
	{
		my $tr = $session->make_element('tr');
		my $td = $session->make_element('td');
		$td->appendChild($item->render_citation_link);
		$tr->appendChild($td);
		$table->appendChild($tr);
	}

	return $chunk;
}

1;

