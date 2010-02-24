
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

	my $shelf =  $self->{processor}->{shelf};

	if ($shelf)
	{
		my $public = $shelf->get_value( "public" );
		if( $public ne "TRUE" )
		{
			my $user = $self->{session}->current_user;
			unless (defined $user and $shelf->has_reader($user))
			{
				$self->{processor}->{screenid} = "Error";
				$self->{processor}->add_message( "error",
					$self->html_phrase( "not_public" ) );
				return;
			}
		}
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

		$self->{session}->not_found;
		$self->{session}->terminate;
		exit;
	}

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

	$chunk->appendChild($shelf->render_export_bar);

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



sub render_export_bar
{
#        my( $session, $esc_path_values, $view ) = @_;
	my ($self) = @_;

	my $session = $self->{session};
	my $shelfid = $self->{processor}->{shelfid};


        my %opts =  (
                        type=>"Export",
                        can_accept=>"list/eprint",
                        is_visible=>"all",
        );
        my @plugins = $session->plugin_list( %opts );

        if( scalar @plugins == 0 )
        {
                return $session->make_doc_fragment;
        }

        my $export_url = $session->get_repository->get_conf( "perl_url" )."/exportshelf";
#        my $values = join( "/", @{$esc_path_values} );

        my $feeds = $session->make_doc_fragment;
        my $tools = $session->make_doc_fragment;
        my $options = {};
        foreach my $plugin_id ( @plugins )
        {
                $plugin_id =~ m/^[^:]+::(.*)$/;
                my $id = $1;
                my $plugin = $session->plugin( $plugin_id );
                my $dom_name = $plugin->render_name;
                if( $plugin->is_feed || $plugin->is_tool )
                {
                        my $type = "feed";
                        $type = "tool" if( $plugin->is_tool );
                        my $span = $session->make_element( "span", class=>"ep_search_$type" );

#                        my $fn = join( "_", @{$esc_path_values} );
			my $fn = 'shelf_' . $shelfid; #use title of shelf?
#                        my $url = $export_url."/".$view->{id}."/$values/$id/$fn".$plugin->param("suffix");
                        my $url = $export_url."/".$shelfid."/$id/$fn".$plugin->param("suffix");

                        my $a1 = $session->render_link( $url );
                        my $icon = $session->make_element( "img", src=>$plugin->icon_url(), alt=>"[$type]", border=>0 );
                        $a1->appendChild( $icon );
                        my $a2 = $session->render_link( $url );
                        $a2->appendChild( $dom_name );
                        $span->appendChild( $a1 );
                        $span->appendChild( $session->make_text( " " ) );
                        $span->appendChild( $a2 );

                        if( $type eq "tool" )
                        {
                                $tools->appendChild( $session->make_text( " " ) );
                                $tools->appendChild( $span );
                        }
                        if( $type eq "feed" )
                        {
                                $feeds->appendChild( $session->make_text( " " ) );
                                $feeds->appendChild( $span );
                        }
                }
                else
                {
                        my $option = $session->make_element( "option", value=>$id );
                        $option->appendChild( $dom_name );
                        $options->{EPrints::XML::to_string($dom_name, undef, 1 )} = $option;
                }
        }

        my $select = $session->make_element( "select", name=>"format" );
        foreach my $optname ( sort keys %{$options} )
        {
                $select->appendChild( $options->{$optname} );
        }
        my $button = $session->make_doc_fragment;
        $button->appendChild( $session->render_button(
                        name=>"_action_export_redir",
                        value=>$session->phrase( "lib/searchexpression:export_button" ) ) );
        $button->appendChild(
                $session->render_hidden_field( "shelfid", $shelfid ) );

        my $form = $session->render_form( "GET", $export_url );
        $form->appendChild( $session->html_phrase( "Update/Views:export_section",
                                        feeds => $feeds,
                                        tools => $tools,
                                        menu => $select,
                                        button => $button ));

        return $form;
}





1;
