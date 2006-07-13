
package EPrints::Interface::Screen::EPrint;

use EPrints::Interface::Screen;

@ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub new
{
	my( $class, $processor ) = @_;

	$class->SUPER::new( $processor );
}

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{eprintid} = $self->{session}->param( "eprintid" );
	$self->{processor}->{eprint} = new EPrints::DataObj::EPrint( $self->{session}, $self->{processor}->{eprintid} );

	if( !defined $self->{processor}->{eprint} )
	{
		$self->{session}->render_error( $self->{session}->html_phrase(
			"cgi/users/edit_eprint:cant_find_it",
			id=>$self->{session}->make_text( $self->{processor}->{eprintid} ) ) );
		return;
	}

	$self->{processor}->{dataset} = $self->{processor}->{eprint}->get_dataset;

	$self->SUPER::properties_from;
}

sub from
{
	my( $self ) = @_;

	# actions with their own screens
	foreach my $a ( 
		"remove", 
		"deposit", 
		"reject_with_email", 
		"remove_with_email",
		"request_eprint_deletion",
	)
	{
		next unless( $self->{processor}->{action} eq $a );
	
		if( !$self->{processor}->allow_action( $a ) )
		{
			$self->{processor}->action_not_allowed( $a );
			return;
		}

		$self->{processor}->{screenid} = "EPrint::\u$a";
		return;
	}

	foreach my $a ( "derive_eprint_version", "derive_eprint_clone" )
	{
		next unless( $self->{processor}->{action} eq $a );

		if( !$self->{processor}->allow_action( $a ) )
		{
			$self->{processor}->action_not_allowed( $a );
			return;
		}

		$self->derive_eprint_version if( $a eq "derive_eprint_version" );

		$self->derive_eprint_clone if( $a eq "derive_eprint_clone" );

		return;
	}

	if( $self->{processor}->{action} =~ m/move_eprint_(.*)_(.*)$/ )
	{
		my( $a, $b ) = ( $1, $2 );
		if( $self->{processor}->allow_action( $self->{processor}->{action} ) )
		{
			my $ok;
			$ok = $self->{processor}->{eprint}->move_to_archive if( $b eq "archive" );
			$ok = $self->{processor}->{eprint}->move_to_buffer if( $b eq "buffer" );
			$ok = $self->{processor}->{eprint}->move_to_inbox if( $b eq "inbox" );
			$ok = $self->{processor}->{eprint}->move_to_deletion if( $b eq "deletion" );
			if( $ok )
			{
				$self->{processor}->add_message( "message",
					$self->{session}->html_phrase( "cgi/users/edit_eprint:status_changed" ) );
			}
			else
			{
				$self->{processor}->add_message( "error",
					$self->{session}->html_phrase(
						"cgi/users/edit_eprint:cant_move",
						id=>$self->{session}->make_text( $self->{processor}->{eprintid} ) ) );
			}
		}
		else
		{
			$self->{processor}->action_not_allowed( $self->{processor}->{action} );
		}

		return;
	}

	$self->SUPER::from;
}

sub register_furniture
{
	my( $self ) = @_;

	$self->{processor}->before_messages( 
		$self->{session}->render_toolbox( 
			$self->{session}->make_text( "Current item" ),
			$self->{processor}->{eprint}->render_citation  ) );
}

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$self->{processor}->{title} = $self->{session}->make_text("Item Control Page");

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	my $status_fragment = $self->{session}->make_doc_fragment;
	$status_fragment->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:item_is_in_".$status ) );

	if( $self->{processor}->allow_action( "deposit" ) )
	{
		# clean up
		my $deposit_div = $self->{session}->make_element( "div", id=>"controlpage_deposit_link" );
		my $a = $self->{session}->make_element( "a", href=>"?screen=EPrint&eprintid=".$self->{processor}->{eprintid}."&_action_deposit=1" );
		$a->appendChild( $self->{session}->make_text( "Deposit now!" ) );
		$deposit_div->appendChild( $a );
		$status_fragment->appendChild( $deposit_div );
	}

	my @staff_actions = ();
	foreach my $action (
		"reject_with_email",
		"remove_with_email",
		"move_eprint_inbox_buffer", 
		"move_eprint_buffer_archive",
		"move_eprint_archive_buffer", 
		"move_eprint_archive_deletion",
		"move_eprint_deletion_archive",
	) 
	{
		push @staff_actions, $action if( $self->{processor}->allow_action( $action ) );
	}
	if( scalar @staff_actions )
	{
		my %buttons = ( _order=>[] );
		foreach my $action ( @staff_actions )
		{
			push @{$buttons{_order}}, $action;
			$buttons{$action} = $self->{session}->phrase( "cgi/users/edit_eprint:action_".$action );
		}
		my $form = $self->render_form;
		$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );
		$status_fragment->appendChild( $form );
	} 

	$chunk->appendChild( 
		 $self->{session}->render_toolbox( 
			$self->{session}->make_text( "Status" ),
			$status_fragment ) );

	# if in archive and can request delete then do that here TODO

	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" ) || 0;
	
	my $view = $self->{session}->param( "view" );

	if( !$self->{processor}->allow_view( "$view" ) )
	{
		$view = undef;
	}

	my $script = $self->{session}->make_element( "script", type=>"text/javascript" );
	$chunk->appendChild( $script );
	$script->appendChild( $self->{session}->make_text( '
window.ep_showTab = function( baseid, tabid )
{

	panels = document.getElementById( baseid+"_panels" );
	for( i=0; ep_lt(i,panels.childNodes.length); i++ ) 
	{
		child = panels.childNodes[i];
		child.style.display = "none";
	}

	tabs = document.getElementById( baseid+"_tabs" );
	for( i=0; ep_lt(i,tabs.childNodes.length); i++ ) 
	{
		child = tabs.childNodes[i];
		if( child.className == "ep_tab_selected" )
		{
			child.className = "ep_tab";
		}
	}

	panel = document.getElementById( baseid+"_panel_"+tabid );
	panel.style.display = "block";

	tab = document.getElementById( baseid+"_tab_"+tabid );
	tab.style.font_size = "30px";
	tab.className = "ep_tab_selected";
	for( i=0; ep_lt(i,tab.childNodes.length); i++ ) 
	{
		child = tab.childNodes[i];
		if( child.nodeName == "A" )
		{
			child.blur();
		}
	}

	if( tabid == "history" )
	{
		return true;
	}

	return false;
};

' ) );

	my $table = $self->{session}->make_element( "table", class=>"ep_tabs", cellspacing=>0 );
	my $tr = $self->{session}->make_element( "tr", id=>"ep_control_view_tabs" );
	$table->appendChild( $tr );

	my @views = qw/ summary full actions export staffexport edit staffedit history /;
	my $spacer = $self->{session}->make_element( "td", class=>"ep_tab_spacer" );
	$spacer->appendChild( $self->{session}->render_nbsp );
	$tr->appendChild( $spacer );
	foreach my $view_i ( @views )
	{	
		next if( !$self->{processor}->allow_view( "$view_i" ) );

		$view = $view_i if !defined $view;
		my %a_opts = ( 
			href    => "?eprintid=".$self->{processor}->{eprintid}."&view=".$view_i, 
		);
		if( quick_tab($view_i) && quick_tab($view) )
		{
			$a_opts{onClick} = "return ep_showTab('ep_control_view','$view_i' );";
		}
		my %td_opts = ( id => "ep_control_view_tab_$view_i", class=>"ep_tab" );
		if( $view eq $view_i ) { $td_opts{class} = "ep_tab_selected"; }

		my $a = $self->{session}->make_element( "a", %a_opts );
		my $td = $self->{session}->make_element( "td", %td_opts );
		my $label = $self->{session}->html_phrase( "cgi/users/edit_eprint:action_view_".$view_i );

		$a->appendChild( $label );
		$td->appendChild( $a );

		$tr->appendChild( $td );

		my $spacer = $self->{session}->make_element( "td", class=>"ep_tab_spacer" );
		$spacer->appendChild( $self->{session}->render_nbsp );
		$tr->appendChild( $spacer );
	}
	$chunk->appendChild( $table );

	my $panel = $self->{session}->make_element( "div", id=>"ep_control_view_panels" );
	$chunk->appendChild( $panel );
	my $view_div = $self->{session}->make_element( "div", class=>"ep_tab_panel", id=>"ep_control_view_panel_$view" );
	$view_div->appendChild( $self->render_view( $view ) );	
	$panel->appendChild( $view_div );

	# don't render the other tabs if this is a slow tab - they must reload
	if( quick_tab($view) )
	{
		foreach my $view_i ( @views )
		{
			next if( !$self->{processor}->allow_view( "$view_i" ) );
			next if $view_i eq $view;
			my $other_view = $self->{session}->make_element( "div", class=>"ep_tab_panel", id=>"ep_control_view_panel_$view_i", style=>"display: none" );
			if( quick_tab( $view_i ) )
			{
				$other_view->appendChild( $self->render_view( $view_i ) );	
			}
			else	
			{
				$other_view->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:loading" ) );
			}
			$panel->appendChild( $other_view );
		}
	}

	return $chunk;
}

sub quick_tab
{
	my( $tab_id ) = @_;

	return 0 if $tab_id eq "history";
	
	return 1;
}

sub render_view
{
	my( $self, $view ) = @_;

	my( $data, $title );
	if( !$self->{processor}->allow_view( "$view" ) )
	{
		return $self->{session}->html_phrase( "cgi/users/edit_eprint:cant_view_view" );
	}

	if( $view eq "actions" ) { $data = $self->render_action_tab; }
	if( $view eq "summary" ) { ($data,$title) = $self->{processor}->{eprint}->render; }
	if( $view eq "full" ) { ($data,$title) = $self->{processor}->{eprint}->render_full; }
	if( $view eq "history" ) { ($data,$title) = $self->{processor}->{eprint}->render_history; }
	if( $view eq "export" ) { $data = $self->{processor}->{eprint}->render_export_links; }
	if( $view eq "staffexport" ) { $data = $self->{processor}->{eprint}->render_export_links(1); }
	if( $view eq "edit" ) { $data = $self->render_edit_tab; }
	if( $view eq "staffedit" ) { $data = $self->render_edit_tab; }

	if( !defined $view )
	{
		return $self->{session}->html_phrase( "cgi/users/edit_eprint:no_such_view" );
	}

	return $data;
}

sub render_action_tab
{
	my( $self ) = @_;

	my @actions = ( 
		"deposit",
		"reject_with_email",
		"remove_with_email",

		"move_eprint_inbox_buffer", 
		"move_eprint_buffer_inbox", 
		"move_eprint_buffer_archive",
		"move_eprint_archive_buffer", 
		"move_eprint_archive_deletion",
		"move_eprint_deletion_archive",

		"move_eprint_inbox_archive", 
		"move_eprint_archive_inbox",  
		
		"derive_eprint_version", # New version
		"derive_eprint_clone", # Use as template

		"request_eprint_deletion",  
		"remove",
	);
	my $session = $self->{session};
	my $form = $self->render_form;
	my $table = $session->make_element( "table" );
	$form->appendChild( $table );
	foreach my $action ( @actions )
	{
		next unless( $self->{processor}->allow_action( $action ) );
		my $tr = $session->make_element( "tr" );
		my $td = $session->make_element( "th" );
		$td->appendChild( $session->render_hidden_field( "action", $action ) );
		$td->appendChild( 
			$session->make_element( 
				"input", 
				type=>"submit",
				class=>"actionbutton",
				name=>"_action_$action", 
				value=>$session->phrase( "cgi/users/edit_eprint:action_".$action ) ) );
		$tr->appendChild( $td );
		my $td2 = $session->make_element( "td" );
		$td2->appendChild( $session->html_phrase( "cgi/users/edit_eprint:help_".$action ) ); 
		$tr->appendChild( $td2 );
		$table->appendChild( $tr );
	}
	return $form;
}

sub render_edit_tab
{
	my( $self ) = @_;

	my $session = $self->{processor}->{session};
	my $eprint = $self->{processor}->{eprint};
	my $staff = $self->{processor}->{staff};

	my %opts = ( item=> $eprint );
	if( $staff ) { $opts{STAFF_ONLY} = "TRUE"; }
	my $workflow = $self->workflow;
	my $ul = $session->make_element( "ul" );
	foreach my $stage_id ( $workflow->get_stage_ids )
	{
		my $li = $session->make_element( "li" );
		my $a = $session->render_link( "eprint?eprintid=".$self->{processor}->{eprintid}."&screen=edit&stage=$stage_id" );
		$li->appendChild( $a );
		$a->appendChild( $session->html_phrase( "metapage_title_".$stage_id ) );
		$ul->appendChild( $li );
	}
	return $ul;
}

sub derive_eprint_version
{
	my( $self ) = @_;

	my $ds_inbox = $self->{session}->get_repository->get_dataset( "inbox" );
	my $new_eprint = $self->{processor}->{eprint}->clone( $ds_inbox, 1, 0 );

	if( !defined $new_eprint )
	{
		$self->{processor}->add_message( "error", 
			$self->{session}->make_text( "Failed" ) );
		return;
	}
	
	$self->{processor}->{eprint} = $new_eprint;
	$self->{processor}->{eprintid} = $new_eprint->get_id;
	$self->{processor}->{screenid} = "EPrint::Edit";
}

sub derive_eprint_clone
{
	my( $self ) = @_;

	my $ds_inbox = $self->{session}->get_repository->get_dataset( "inbox" );
	my $new_eprint = $self->{processor}->{eprint}->clone( $ds_inbox, 0, 1 );

	if( !defined $new_eprint )
	{
		$self->{processor}->add_message( "error", 
			$self->{session}->make_text( "Failed" ) );
		return;
	}
	
	$self->{processor}->{eprint} = $new_eprint;
	$self->{processor}->{eprintid} = $new_eprint->get_id;
	$self->{processor}->{screenid} = "EPrint::Edit";
}

sub workflow
{
	my( $self ) = @_;

	if( !defined $self->{processor}->{workflow} )
	{
		my %opts = ( item=> $self->{processor}->{eprint}, session=>$self->{session} );
		if( $self->{processor}->{staff} ) { $opts{STAFF_ONLY} = "TRUE"; }
 		$self->{processor}->{workflow} = EPrints::Workflow->new( $self->{session}, "default", %opts );
	}

	return $self->{processor}->{workflow};
}

sub render_blister
{
	my( $self, $sel_stage_id, $with_deposit ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $session = $self->{session};
	my $staff = 0;

	my $workflow = $self->workflow;
	my $table = $session->make_element( "table", cellspacing=>0, class=>"ep_blister_bar" );
	my $tr = $session->make_element( "tr" );
	$table->appendChild( $tr );
	my $first = 1;
	foreach my $stage_id ( $workflow->get_stage_ids )
	{
		if( !$first )  { $tr->appendChild( $session->make_element( "td", class=>"ep_blister_join" ) ); }
		my $td;
		if( $stage_id eq $sel_stage_id )
		{
			$td = $session->make_element( "td", class=>"ep_blister_node_selected" );
		}
		else
		{
			$td = $session->make_element( "td", class=>"ep_blister_node" );
		}
		my $a = $session->render_link( "eprint?eprintid=".$self->{processor}->{eprintid}."&screen=EPrint::Edit&stage=$stage_id" );
		$td->appendChild( $a );
		$a->appendChild( $session->html_phrase( "metapage_title_".$stage_id ) );
		$tr->appendChild( $td );
		$first = 0;
	}

	if( $with_deposit )
	{
		$tr->appendChild( $session->make_element( "td", class=>"ep_blister_join" ) );
		my $td;
		if( $sel_stage_id eq "deposit" ) 
		{
			$td = $session->make_element( "td", class=>"ep_blister_node_selected" );
		}
		else
		{
			$td = $session->make_element( "td", class=>"ep_blister_node" );
		}
		my $a = $session->render_link( "eprint?eprintid=".$self->{processor}->{eprintid}."&screen=EPrint::Deposit" );
		$td->appendChild( $a );
		$a->appendChild( $session->make_text( "Deposit" ) );
		$tr->appendChild( $td );
	}

	return $self->{session}->render_toolbox( 
			$self->{session}->make_text( "Deposit progress" ),
			$table );
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

