
package EPrints::Plugin::Screen::Review;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 400,
		}
	];

	$self->{actions} = [qw/ col_left col_right remove_col add_col /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "editorial_review" );
}

sub allow_col_left { return $_[0]->can_be_viewed; }
sub allow_col_right { return $_[0]->can_be_viewed; }
sub allow_remove_col { return $_[0]->can_be_viewed; }
sub allow_add_col { return $_[0]->can_be_viewed; }

sub action_col_left
{
	my( $self ) = @_;

	my $col_id = $self->{handle}->param( "colid" );
	my $v = $self->{handle}->current_user->get_value( "review_fields" );

	my @newlist = @$v;
	my $a = $newlist[$col_id];
	my $b = $newlist[$col_id-1];
	$newlist[$col_id] = $b;
	$newlist[$col_id-1] = $a;

	$self->{handle}->current_user->set_value( "review_fields", \@newlist );
	$self->{handle}->current_user->commit();
}

sub action_col_right
{
	my( $self ) = @_;

	my $col_id = $self->{handle}->param( "colid" );
	my $v = $self->{handle}->current_user->get_value( "review_fields" );

	my @newlist = @$v;
	my $a = $newlist[$col_id];
	my $b = $newlist[$col_id+1];
	$newlist[$col_id] = $b;
	$newlist[$col_id+1] = $a;
	
	$self->{handle}->current_user->set_value( "review_fields", \@newlist );
	$self->{handle}->current_user->commit();
}
sub action_add_col
{
	my( $self ) = @_;

	my $col = $self->{handle}->param( "col" );
	my $v = $self->{handle}->current_user->get_value( "review_fields" );

	my @newlist = @$v;
	push @newlist, $col;	
	
	$self->{handle}->current_user->set_value( "review_fields", \@newlist );
	$self->{handle}->current_user->commit();
}
sub action_remove_col
{
	my( $self ) = @_;

	my $col_id = $self->{handle}->param( "colid" );
	my $v = $self->{handle}->current_user->get_value( "review_fields" );

	my @newlist = @$v;
	splice( @newlist, $col_id, 1 );
	
	$self->{handle}->current_user->set_value( "review_fields", \@newlist );
	$self->{handle}->current_user->commit();
}

sub render_links
{
	my( $self ) = @_;

	my $style = $self->{handle}->make_element( "style", type=>"text/css" );
	$style->appendChild( $self->{handle}->make_text( ".ep_tm_main { width: 90%; }" ) );

	return $style;
}


sub render
{
	my( $self ) = @_;

	my $handle = $self->{handle};
	my $user = $self->{handle}->current_user;
	my $page = $self->{handle}->make_doc_fragment();

	# Get EPrints in the submission buffer
	my $list = $user->get_editable_eprints();

	my $div = $self->{handle}->make_element( "div", class=>"ep_block" );
	$page->appendChild( $div );

	if( $user->is_set( "editperms" ) )
	{
		$div->appendChild( $self->{handle}->html_phrase( 
			"cgi/users/buffer:buffer_scope",
			scope=>$user->render_value( "editperms" ) ) );
	}

	my $imagesurl = $handle->get_repository->get_conf( "rel_path" )."/style/images";

	my %options;
 	$options{handle} = $handle;
	$options{id} = "ep_review_instructions";
	$options{title} = $handle->html_phrase( "Plugin/Screen/Review:help_title" );
	$options{content} = $handle->html_phrase( "Plugin/Screen/Review:help" );
	$options{collapsed} = 1;
	$options{show_icon_url} = "$imagesurl/help.gif";
	my $box = $handle->make_element( "div", style=>"text-align: left" );
	$box->appendChild( EPrints::Box::render( %options ) );
	$div->appendChild( $box );

	my $columns = $handle->current_user->get_value( "review_fields" );
	if( !EPrints::Utils::is_set( $columns ) )
	{
		$columns = [ "eprintid","type","status_changed", "userid" ];
		$handle->current_user->set_value( "review_fields", $columns );
		$handle->current_user->commit;
	}

	my $len = scalar @{$columns};

	my $final_row = undef;
	if( $len > 1 )
	{	
		$final_row = $handle->make_element( "tr" );
		for(my $i=0; $i<$len;++$i )
		{
			my $col = $columns->[$i];
			# Column headings
			my $td = $handle->make_element( "td", class=>"ep_columns_alter" );
			$final_row->appendChild( $td );
	
			my $acts_table = $handle->make_element( "table", cellpadding=>0, cellspacing=>0, border=>0, width=>"100%" );
			my $acts_row = $handle->make_element( "tr" );
			my $acts_td1 = $handle->make_element( "td", align=>"left", width=>"14" );
			my $acts_td2 = $handle->make_element( "td", align=>"center", width=>"100%");
			my $acts_td3 = $handle->make_element( "td", align=>"right", width=>"14" );
			$acts_table->appendChild( $acts_row );
			$acts_row->appendChild( $acts_td1 );
			$acts_row->appendChild( $acts_td2 );
			$acts_row->appendChild( $acts_td3 );
			$td->appendChild( $acts_table );

			if( $i!=0 )
			{
				my $form_l = $handle->render_form( "post" );
				$form_l->appendChild( 
					$handle->render_hidden_field( "screen", "Review" ) );
				$form_l->appendChild( 
					$handle->render_hidden_field( "colid", $i ) );
				$form_l->appendChild( $handle->make_element( 
					"input",
					type=>"image",
					value=>"Move Left",
					title=>"Move Left",
					src => "$imagesurl/left.png",
					alt => "<",
					name => "_action_col_left" ) );
				$acts_td1->appendChild( $form_l );
			}
			else
			{
				$acts_td1->appendChild( $handle->make_element("img",src=>"$imagesurl/noicon.png",alt=>"") );
			}

			my $msg = $self->phrase( "remove_column_confirm" );
			my $form_rm = $handle->render_form( "post" );
			$form_rm->appendChild( 
				$handle->render_hidden_field( "screen", "Review" ) );
			$form_rm->appendChild( 
				$handle->render_hidden_field( "colid", $i ) );
			$form_rm->appendChild( $handle->make_element( 
				"input",
				type=>"image",
				value=>"Remove Column",
				title=>"Remove Column",
				src => "$imagesurl/delete.png",
				alt => "X",
				onclick => "if( window.event ) { window.event.cancelBubble = true; } return confirm( ".EPrints::Utils::js_string($msg)." );",
				name => "_action_remove_col" ) );
			$acts_td2->appendChild( $form_rm );

			if( $i!=$len-1 )
			{
				my $form_r = $handle->render_form( "post" );
				$form_r->appendChild( 
					$handle->render_hidden_field( "screen", "Review" ) );
				$form_r->appendChild( 
					$handle->render_hidden_field( "colid", $i ) );
				$form_r->appendChild( $handle->make_element( 
					"input",
					type=>"image",
					value=>"Move Right",
					title=>"Move Right",
					src => "$imagesurl/right.png",
					alt => ">",
					name => "_action_col_right" ) );
				$acts_td3->appendChild( $form_r );
			}
			else
			{
				$acts_td3->appendChild( $handle->make_element("img",src=>"$imagesurl/noicon.png",alt=>"")  );
			}
		}
		my $td = $handle->make_element( "td", class=>"ep_columns_alter ep_columns_alter_last" );
		$final_row->appendChild( $td );
	}

	# Paginate list
	my %opts = (
		params => {
			screen => "Review",
		},
		columns => [@{$columns}, undef ],
		render_result_params => {
			row => 1,
		},
		render_result => sub {
			my( $handle, $e, $info ) = @_;

			my $class = "row_".($info->{row}%2?"b":"a");
			if( $e->is_locked )
			{
				$class .= " ep_columns_row_locked";
				my $my_lock = ( $e->get_value( "edit_lock_user" ) == $handle->current_user->get_id );
				if( $my_lock )
				{
					$class .= " ep_columns_row_locked_mine";
				}
				else
				{
					$class .= " ep_columns_row_locked_other";
				}
			}

			my $tr = $handle->make_element( "tr", class=>$class );

 			my $cols = $columns,

			my $first = 1;
			for( @$cols )
			{
				my $td = $handle->make_element( "td", class=>"ep_columns_cell".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
				$first = 0;
				$tr->appendChild( $td );
				$td->appendChild( $e->render_value( $_ ) );
			}

			$self->{processor}->{eprint} = $e;
			$self->{processor}->{eprintid} = $e->get_id;
			my $td = $handle->make_element( "td", class=>"ep_columns_cell ep_columns_cell_last", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( 
				$self->render_action_list_icons( "eprint_review_actions", ['eprintid'] ) );
			delete $self->{processor}->{eprint};


			++$info->{row};

			return $tr;
		},
		rows_after => $final_row,
	);
#	my $h2 = $self->{handle}->make_element( "h2",class=>"ep_search_desc" );
#	$h2->appendChild( $self->html_phrase( "list_desc" ) );
#	$page->appendChild( $h2 );
	$page->appendChild( EPrints::Paginate::Columns->paginate_list( $self->{handle}, "_review", $list, %opts ) );

	# Add form
	my $add_div = $handle->make_element( "div", class=>"ep_columns_add" );
	my $form_add = $handle->render_form( "post" );
	$form_add->appendChild( $handle->render_hidden_field( "screen", "Review" ) );

	my $colcurr = {};
	foreach( @$columns ) { $colcurr->{$_} = 1; }
        my $ds = $handle->get_repository->get_dataset( "eprint" );
	my $fieldnames = {};
        foreach my $field ( $ds->get_fields )
        {
                next unless $field->get_property( "show_in_fieldlist" );
		next if $colcurr->{$field->get_name};
		my $name = EPrints::Utils::tree_to_utf8( $field->render_name( $handle ) );
		my $parent = $field->get_property( "parent_name" );
		if( defined $parent ) 
		{
			my $pfield = $ds->get_field( $parent );
			$name = EPrints::Utils::tree_to_utf8( $pfield->render_name( $handle )).": $name";
		}
		$fieldnames->{$field->get_name} = $name;
        }

	my @tags = sort { $fieldnames->{$a} cmp $fieldnames->{$b} } keys %$fieldnames;

	$form_add->appendChild( $handle->render_option_list( 
		name => 'col',
		height => 1,
		multiple => 0,
		'values' => \@tags,
		labels => $fieldnames ) );
		
	$form_add->appendChild( 
			$handle->render_button(
				class=>"ep_form_action_button",
				name=>"_action_add_col", 
				value => $self->phrase( "add" ) ) );
	$add_div->appendChild( $form_add );
	$page->appendChild( $add_div );
	# End of Add form

	return $page;
}



1;
