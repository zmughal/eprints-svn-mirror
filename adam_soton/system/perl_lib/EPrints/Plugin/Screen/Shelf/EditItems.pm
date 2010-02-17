
package EPrints::Plugin::Screen::Shelf::EditItems;

use EPrints::Plugin::Screen::Shelf;

@ISA = ( 'EPrints::Plugin::Screen::Shelf' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
                {
                        place => "shelf_item_actions",
                        position => 200,
                },
                {
                        place => "shelf_view_actions",
                        position => 200,
                },
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

        return (
                $self->{processor}->{shelf}->has_editor($self->{processor}->{user})
        );
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

        my $columns = [ 'title', 'creators_name', 'date' ];

        my $len = scalar @{$columns};

	# Paginate list
	my %opts = (
		params => {
			screen => "Shelf::EditItems",
			shelfid => $self->{processor}->{shelfid},
		},
		columns => [@{$columns}, undef ],
		render_result => sub {
			my( $session, $e ) = @_;

			my $tr = $session->make_element( "tr" );

                        my $first = 1;
                        for( @$columns )
                        {
                                my $td = $session->make_element( "td", class=>"ep_columns_cell ".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
                                $first = 0;
                                $tr->appendChild( $td );
                                $td->appendChild( $e->render_value( $_ ) );
                        }

			$self->{processor}->{eprint} = $e;
			$self->{processor}->{eprintid} = $e->get_id;
			my $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_last", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( 
				$self->render_action_list_icons( "shelf_eprint_actions", ['shelfid','eprintid'] ) );
#can we have our own actions appear here?


			delete $self->{processor}->{eprint};

			return $tr;
		},
	);
	$chunk->appendChild( EPrints::Paginate::Columns->paginate_list( $session, "_buffer", $list, %opts ) );


#	# Add form
#	my $div = $session->make_element( "div", class=>"ep_shelf_actions" );
#	my $form_add = $session->render_form( "post" );
#	$form_add->appendChild( $session->render_hidden_field( "screen", "Shelf::EditItems" ) );
#
#	my $colcurr = {};
#	foreach( @$columns ) { $colcurr->{$_} = 1; }
#	my $fieldnames = {};
#        foreach my $field ( $ds->get_fields )
#        {
#                next unless $field->get_property( "show_in_fieldlist" );
#		next if $colcurr->{$field->get_name};
#		my $name = EPrints::Utils::tree_to_utf8( $field->render_name( $session ) );
#		my $parent = $field->get_property( "parent_name" );
#		if( defined $parent ) 
#		{
#			my $pfield = $ds->get_field( $parent );
#			$name = EPrints::Utils::tree_to_utf8( $pfield->render_name( $session )).": $name";
#		}
#		$fieldnames->{$field->get_name} = $name;
#        }
#
#	my @tags = sort { $fieldnames->{$a} cmp $fieldnames->{$b} } keys %$fieldnames;
#
#	$form_add->appendChild( $session->render_option_list( 
#		name => 'col',
#		height => 1,
#		multiple => 0,
#		'values' => \@tags,
#		labels => $fieldnames ) );
#		
#	$form_add->appendChild( 
#			$session->render_button(
#				class=>"ep_form_action_button",
#				name=>"_action_add_col", 
#				value => $self->phrase( "add" ) ) );
#	$div->appendChild( $form_add );
#	$chunk->appendChild( $div );
#	# End of Add form

	return $chunk;
}


1;
