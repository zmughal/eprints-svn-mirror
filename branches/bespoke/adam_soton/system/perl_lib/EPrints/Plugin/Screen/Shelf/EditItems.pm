
package EPrints::Plugin::Screen::Shelf::EditItems;

use EPrints::Plugin::Screen::Shelf;

@ISA = ( 'EPrints::Plugin::Screen::Shelf' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_shelf_contents.png";

	$self->{appears} = [
                {
                        place => "shelf_item_actions",
                        position => 300,
                },
                {
                        place => "shelf_view_actions",
                        position => 300,
                },
	];

	return $self;
}

sub properties_from
{
        my( $self ) = @_;

        $self->{processor}->{_buffer_order} = $self->{session}->param( '_buffer_order' ) if $self->{session}->param( '_buffer_order' );
        $self->{processor}->{_buffer_offset} = $self->{session}->param( '_buffer_offset' ) if $self->{session}->param( '_buffer_offset' );

        $self->SUPER::properties_from;
}


sub redirect_to_me_url
{
        my( $self ) = @_;

        return $self->SUPER::redirect_to_me_url .
	"&_buffer_order=" . $self->{session}->param( '_buffer_order' ) . 
	"&_buffer_offset=" . $self->{session}->param( '_buffer_offset' );
}

sub can_be_viewed
{
	my( $self ) = @_;

        return (
                $self->{processor}->{shelf}->has_editor($self->{processor}->{user})
        );
}

sub allow_reorder
{
	my ($self) = @_;

	return $self->can_be_viewed;
}

sub action_reorder
{

	
}


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $shelf = $self->{processor}->{shelf};

	my $chunk = $session->make_doc_fragment;

	if( $session->get_lang->has_phrase( $self->html_phrase_id( "intro" ) ) )
	{
		my $intro_div_outer = $session->make_element( "div", class => "ep_toolbox" );
		my $intro_div = $session->make_element( "div", class => "ep_toolbox_content" );
		$intro_div->appendChild( $self->html_phrase( "intro" ) );
		$intro_div_outer->appendChild( $intro_div );
		$chunk->appendChild( $intro_div_outer );
	}

	my $imagesurl = $session->get_repository->get_conf( "rel_path" )."/style/images";

	my %options;
 	$options{session} = $session;
	$options{id} = "ep_review_instructions";
	$options{title} = $session->html_phrase( "Plugin/Screen/Shelf/EditItems:help_title" );
	$options{content} = $session->html_phrase( "Plugin/Screen/Shelf/EditItemsItems:help" );
	$options{collapsed} = 1;
	$options{show_icon_url} = "$imagesurl/help.gif";
	my $box = $session->make_element( "div", style=>"text-align: left" );
	$box->appendChild( EPrints::Box::render( %options ) );
	$chunk->appendChild( $box );

	### Get the items owned by the current user
	my $ds = $session->get_repository->get_dataset( "eprint" );

	my $list = EPrints::List->new(
		session => $session,
		dataset => $ds,
		ids => $shelf->get_value('items'),
	);

	if ($list->count < 1)
	{
		$chunk->appendChild($session->render_message('warning', $self->html_phrase('shelf_empty')));
		return $chunk;
	}

	#controls
	my $controls = $session->make_element('table');
	my $tr = $session->make_element('tr');
	$controls->appendChild($tr);

	my $td = $session->make_element('td');
	$tr->appendChild($td);
	$td->appendChild(
		$session->render_button(
			class=>"ep_form_action_button",
			name=>"_action_null",
			value => $session->phrase( 'Plugin/Screen/Shelf/RemoveSelectedItems:title' ) ) );

	$td =  $session->make_element('td');
	$tr->appendChild($td);

        $td->appendChild( $session->render_button(
		class=>"ep_form_action_button",
		name=>"_action_reorder",
		value => $self->phrase( "reorder" ) 
	) );

	my $eprint_ds = $session->get_repository->get_dataset('eprint');
	my ( $sortids, $sort_labels );
	foreach my $fieldid (@{$session->get_repository->get_conf('shelf_order_fields')})
	{
		push @{$sortids}, $fieldid;
		push @{$sortids}, '-' . $fieldid;

		my $fieldname = EPrints::Utils::tree_to_utf8($eprint_ds->get_field($fieldid)->render_name($session));

		$sort_labels->{$fieldid} = $fieldname;
		$sort_labels->{'-'.$fieldid} = "$fieldname (desc)";

	}

        $td->appendChild( $session->render_option_list(
                name => 'order',
                height => 1,
                multiple => 0,
                'values' => $sortids,
                labels => $sort_labels ) );


	# Paginate list
	my %opts = (
		params => {
			screen => "Shelf::EditItems",
			shelfid => $self->{processor}->{shelfid},
		},
		below_results => $controls,
		render_result => sub {
			my( $session, $e ) = @_;

			my $tr = $session->make_element( "tr" );

			my $td = $session->make_element( 'td', class=>"ep_columns_cell ep_columns_cell_first" );
			$td->appendChild(
				$session->render_noenter_input_field(
				type => "checkbox",
				name => "eprintids",
				value => $e->get_id )
			);

			$tr->appendChild($td); #table cell for tickbox

			my $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_$_"  );
			$tr->appendChild( $td );
			$td->appendChild( $e->render_citation_link );

                        $self->{processor}->{eprint} = $e;
                        $self->{processor}->{eprintid} = $e->get_id;
                        $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_last", align=>"left" );
                        $tr->appendChild( $td );
                        $td->appendChild(
				$self->render_action_list_icons( "shelf_items_eprint_actions", ['shelfid','eprintid','_buffer_order','_buffer_offset'] ) );
                        delete $self->{processor}->{eprint};

			return $tr;
		},
	);


	# Add form
	my $div = $session->make_element( "div", class=>"ep_shelf_actions" );
	my $form = $session->render_form( "post" );
	$form->appendChild( $session->render_hidden_field( "screen", "Shelf::EditItemsActions" ) );
	$form->appendChild($self->render_hidden_bits); 

	my $table = $session->make_element('table');

	$table->appendChild(EPrints::Paginate->paginate_list( $session, "_buffer", $list, %opts ));
	$form->appendChild($table);

	$chunk->appendChild($form);



	return $chunk;
}

#overridden to show buttons as images rather than forms as the whole table will be a form.
sub render_action_list_icons
{
        my( $self, $list_id, $hidden ) = @_;

        my $session = $self->{session};

        my $div = $self->{session}->make_element( "div", class=>"ep_act_icons" );
        my $table = $session->make_element( "table" );
        $div->appendChild( $table );
        my $tr = $session->make_element( "tr" );
        $table->appendChild( $tr );
        foreach my $params ( $self->action_list( $list_id ) )
        {
                my $td = $session->make_element( "td" );
                $tr->appendChild( $td );
                $td->appendChild( $self->render_action_icon_as_img( { %$params, hidden => $hidden } ) );
        }

        return $div;
}


sub render_action_icon_as_img
{
        my( $self, $params ) = @_;

        my $session = $self->{session};

        my( $action, $title, $icon );
        if( defined $params->{action} )
        {
                $action = $params->{action};
                $title = $params->{screen}->phrase( "action:$action:title" );
                $icon = $params->{screen}->action_icon_url( $action );
        }
        else
        {
                $action = "null";
                $title = $params->{screen}->phrase( "title" );
                $icon = $params->{screen}->icon_url();
        }

	if ($action eq 'spacer')
	{
		return $session->make_element('img', src => $icon, alt => 'spacer');
	}


	my $control_params = { screen =>  substr( $params->{screen_id}, 8 ) };
	foreach my $id ( @{$params->{hidden}} )
	{
		$control_params->{$id} = $self->{processor}->{$id};
	}
	$control_params->{'_action_' . $action} = $action;

	my $control_url = $self->generate_control_url($control_params);

	my $a = $session->render_link( $control_url );
	$a->appendChild($session->make_element('img', src => $icon, alt => $title, title => $title, style => "border: none"));


	return $a;
}




sub generate_control_url
{
	my ($self, $params) = @_;

	my $url = $self->{session}->get_repository->get_conf('userhome') . '?';

	my $paramstrings;
	foreach my $paramid (keys %{$params})
	{
		push @{$paramstrings}, $paramid . '=' . $params->{$paramid};
	}
	$url .= join('&',@{$paramstrings});

	return $url;
}


sub render_hidden_bits
{
        my( $self ) = @_;

        my $chunk = $self->{session}->make_doc_fragment;

        $chunk->appendChild( $self->{session}->render_hidden_field( "_buffer_order", $self->{processor}->{_buffer_order} ) );
        $chunk->appendChild( $self->{session}->render_hidden_field( "_buffer_offset", $self->{processor}->{_buffer_offset} ) );

        $chunk->appendChild( $self->SUPER::render_hidden_bits );

        return $chunk;
}


1;
