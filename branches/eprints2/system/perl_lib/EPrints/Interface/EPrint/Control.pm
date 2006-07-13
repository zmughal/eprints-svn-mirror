
package EPrints::Interface::EPrint::Control;

use EPrints::Interface::Screen;
use EPrints::Interface::EPrint::Deposit;


@ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub from
{
	my( $class, $interface ) = @_;

	# actions with their own screens
	foreach my $a ( 
		"remove", 
		"deposit", 
		"reject_with_email", 
		"remove_with_email",
		"request_eprint_deletion",
	)
	{
		next unless( $interface->{action} eq $a );
	
		if( !$interface->allow_action( $a ) )
		{
			$interface->action_not_allowed( $a );
			return;
		}

		$interface->{screenid} = $a;
		return;
	}

	foreach my $a ( "derive_eprint_version", "derive_eprint_clone" )
	{
		next unless( $interface->{action} eq $a );

		if( !$interface->allow_action( $a ) )
		{
			$interface->action_not_allowed( $a );
			return;
		}

		derive_eprint_version( $interface ) if( $a eq "derive_eprint_version" );

		derive_eprint_clone( $interface ) if( $a eq "derive_eprint_clone" );

		return;
	}

	if( $interface->{action} =~ m/move_eprint_(.*)_(.*)$/ )
	{
		my( $a, $b ) = ( $1, $2 );
		if( $interface->allow_action( $interface->{action} ) )
		{
			my $ok;
			$ok = $interface->{eprint}->move_to_archive if( $b eq "archive" );
			$ok = $interface->{eprint}->move_to_buffer if( $b eq "buffer" );
			$ok = $interface->{eprint}->move_to_inbox if( $b eq "inbox" );
			$ok = $interface->{eprint}->move_to_deletion if( $b eq "deletion" );
			if( $ok )
			{
				$interface->add_message( "message",
					$interface->{session}->html_phrase( "cgi/users/edit_eprint:status_changed" ) );
			}
			else
			{
				$interface->add_message( "error",
					$interface->{session}->html_phrase(
						"cgi/users/edit_eprint:cant_move",
						id=>$interface->{session}->make_text( $interface->{eprintid} ) ) );
			}
		}
		else
		{
			$interface->action_not_allowed( $interface->{action} );
		}

		return;
	}

	$class->SUPER::from( $interface );
}

sub render
{
	my( $class, $interface ) = @_;

	my $chunk = $interface->{session}->make_doc_fragment;

	$interface->{title} = $interface->{session}->make_text("Item Control Page");

	my $status = $interface->{eprint}->get_value( "eprint_status" );

	my $status_fragment = $interface->{session}->make_doc_fragment;
	$status_fragment->appendChild( $interface->{session}->html_phrase( "cgi/users/edit_eprint:item_is_in_".$status ) );

	if( $interface->allow_action( "deposit" ) )
	{
		# clean up
		my $deposit_div = $interface->{session}->make_element( "div", id=>"controlpage_deposit_link" );
		my $a = $interface->{session}->make_element( "a", href=>"?screen=control&eprintid=".$interface->{eprintid}."&_action_deposit=1" );
		$a->appendChild( $interface->{session}->make_text( "Deposit now!" ) );
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
		push @staff_actions, $action if( $interface->allow_action( $action ) );
	}
	if( scalar @staff_actions )
	{
		my %buttons = ( _order=>[] );
		foreach my $action ( @staff_actions )
		{
			push @{$buttons{_order}}, $action;
			$buttons{$action} = $interface->{session}->phrase( "cgi/users/edit_eprint:action_".$action );
		}
		my $form = $interface->render_form;
		$form->appendChild( $interface->{session}->render_action_buttons( %buttons ) );
		$status_fragment->appendChild( $form );
	} 

	$chunk->appendChild( 
		 $interface->{session}->render_toolbox( 
			$interface->{session}->make_text( "Status" ),
			$status_fragment ) );

	# if in archive and can request delete then do that here TODO

	my $sb = $interface->{session}->get_repository->get_conf( "skip_buffer" ) || 0;
	
	my $view = $interface->{session}->param( "view" );

	if( !$interface->allow_view( "$view" ) )
	{
		$view = undef;
	}

	my $script = $interface->{session}->make_element( "script", type=>"text/javascript" );
	$chunk->appendChild( $script );
	$script->appendChild( $interface->{session}->make_text( '
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

	my $table = $interface->{session}->make_element( "table", class=>"ep_tabs", cellspacing=>0 );
	my $tr = $interface->{session}->make_element( "tr", id=>"ep_control_view_tabs" );
	$table->appendChild( $tr );

	my @views = qw/ summary full actions export staffexport edit staffedit history /;
	my $spacer = $interface->{session}->make_element( "td", class=>"ep_tab_spacer" );
	$spacer->appendChild( $interface->{session}->render_nbsp );
	$tr->appendChild( $spacer );
	foreach my $view_i ( @views )
	{	
		next if( !$interface->allow_view( "$view_i" ) );

		$view = $view_i if !defined $view;
		my %a_opts = ( 
			href    => "?eprintid=".$interface->{eprintid}."&view=".$view_i, 
		);
		if( quick_tab($view_i) && quick_tab($view) )
		{
			$a_opts{onClick} = "return ep_showTab('ep_control_view','$view_i' );";
		}
		my %td_opts = ( id => "ep_control_view_tab_$view_i", class=>"ep_tab" );
		if( $view eq $view_i ) { $td_opts{class} = "ep_tab_selected"; }

		my $a = $interface->{session}->make_element( "a", %a_opts );
		my $td = $interface->{session}->make_element( "td", %td_opts );
		my $label = $interface->{session}->html_phrase( $interface->interface.":action_view_".$view_i );

		$a->appendChild( $label );
		$td->appendChild( $a );

		$tr->appendChild( $td );

		my $spacer = $interface->{session}->make_element( "td", class=>"ep_tab_spacer" );
		$spacer->appendChild( $interface->{session}->render_nbsp );
		$tr->appendChild( $spacer );
	}
	$chunk->appendChild( $table );

	my $panel = $interface->{session}->make_element( "div", id=>"ep_control_view_panels" );
	$chunk->appendChild( $panel );
	my $view_div = $interface->{session}->make_element( "div", class=>"ep_tab_panel", id=>"ep_control_view_panel_$view" );
	$view_div->appendChild( render_view( $interface, $view ) );	
	$panel->appendChild( $view_div );

	# don't render the other tabs if this is a slow tab - they must reload
	if( quick_tab($view) )
	{
		foreach my $view_i ( @views )
		{
			next if( !$interface->allow_view( "$view_i" ) );
			next if $view_i eq $view;
			my $other_view = $interface->{session}->make_element( "div", class=>"ep_tab_panel", id=>"ep_control_view_panel_$view_i", style=>"display: none" );
			if( quick_tab( $view_i ) )
			{
				$other_view->appendChild( render_view( $interface, $view_i ) );	
			}
			else	
			{
				$other_view->appendChild( $interface->{session}->html_phrase( "cgi/users/edit_eprint:loading" ) );
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
	my( $interface, $view ) = @_;

	my( $data, $title );
	if( !$interface->allow_view( "$view" ) )
	{
		return $interface->{session}->html_phrase( "cgi/users/edit_eprint:cant_view_view" );
	}

	if( $view eq "actions" ) { $data = render_action_tab( $interface ); }
	if( $view eq "summary" ) { ($data,$title) = $interface->{eprint}->render; }
	if( $view eq "full" ) { ($data,$title) = $interface->{eprint}->render_full; }
	if( $view eq "history" ) { ($data,$title) = $interface->{eprint}->render_history; }
	if( $view eq "export" ) { $data = $interface->{eprint}->render_export_links; }
	if( $view eq "staffexport" ) { $data = $interface->{eprint}->render_export_links(1); }
	if( $view eq "edit" ) { $data = render_edit_tab( $interface ); }
	if( $view eq "staffedit" ) { $data = render_edit_tab( $interface ); }

	if( !defined $view )
	{
		return $interface->{session}->html_phrase( "cgi/users/edit_eprint:no_such_view" );
	}

	return $data;
}

sub render_action_tab
{
	my( $interface ) = @_;

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
	my $session = $interface->{session};
	my $form = $interface->render_form;
	my $table = $session->make_element( "table" );
	$form->appendChild( $table );
	foreach my $action ( @actions )
	{
		next unless( $interface->allow_action( $action ) );
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
	my( $interface ) = @_;

	my $session = $interface->{session};
	my $eprint = $interface->{eprint};
	my $staff = $interface->{staff};

	my %opts = ( item=> $eprint );
	if( $staff ) { $opts{STAFF_ONLY} = "TRUE"; }
	my $workflow = EPrints::Workflow->new( $session, "default", %opts );
	my $ul = $session->make_element( "ul" );
	foreach my $stage_id ( $workflow->get_stage_ids )
	{
		my $li = $session->make_element( "li" );
		my $a = $session->render_link( "eprint?eprintid=".$interface->{eprintid}."&screen=edit&stage=$stage_id" );
		$li->appendChild( $a );
		$a->appendChild( $session->html_phrase( "metapage_title_".$stage_id ) );
		$ul->appendChild( $li );
	}
	return $ul;
}

sub derive_eprint_version
{
	my( $interface ) = @_;

	my $ds_inbox = $interface->{session}->get_repository->get_dataset( "inbox" );
	my $new_eprint = $interface->{eprint}->clone( $ds_inbox, 1, 0 );

	if( !defined $new_eprint )
	{
		$interface->add_message( "error", 
			$interface->{session}->make_text( "Failed" ) );
		return;
	}
	
	$interface->{eprint} = $new_eprint;
	$interface->{eprintid} = $new_eprint->get_id;
	$interface->{screenid} = "edit";
}

sub derive_eprint_clone
{
	my( $interface ) = @_;

	my $ds_inbox = $interface->{session}->get_repository->get_dataset( "inbox" );
	my $new_eprint = $interface->{eprint}->clone( $ds_inbox, 0, 1 );

	if( !defined $new_eprint )
	{
		$interface->add_message( "error", 
			$interface->{session}->make_text( "Failed" ) );
		return;
	}
	
	$interface->{eprint} = $new_eprint;
	$interface->{eprintid} = $new_eprint->get_id;
	$interface->{screenid} = "edit";
}

1;

