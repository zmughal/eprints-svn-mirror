
package EPrints::Plugin::Screen::Shelf::View;

use EPrints::Plugin::Screen::Shelf;

@ISA = ( 'EPrints::Plugin::Screen::Shelf' );

use strict;

sub new
{
        my( $class, %params ) = @_;

        my $self = $class->SUPER::new(%params);

        $self->{icon} = "action_view.png";

        $self->{appears} = [
                {
                        place => "shelf_item_actions",
                        position => 50,
                },
        ];

        return $self;
}

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

