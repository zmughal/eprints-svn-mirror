
package EPrints::Interface::Screen::EPrint::View::Owner;

use EPrints::Interface::Screen::EPrint::View;

@ISA = ( 'EPrints::Interface::Screen::EPrint::View' );

use strict;

sub new
{
	my( $class, $processor ) = @_;

	$class->SUPER::new( $processor );
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
		"request_deletion",
		"edit",
		"edit_staff",
	)
	{
		next unless( $self->{processor}->{action} eq $a );
	
		if( !$self->allow( "action/eprint/$a" ) )
		{
			$self->{processor}->action_not_allowed( $a );
			return;
		}

		$self->{processor}->{screenid} = "EPrint::\u$a";
		return;
	}

	foreach my $a ( "derive_version", "derive_clone" )
	{
		next unless( $self->{processor}->{action} eq $a );

		if( !$self->allow( "action/eprint/$a" ) )
		{
			$self->{processor}->action_not_allowed( $a );
			return;
		}

		$self->derive_version if( $a eq "derive_version" );

		$self->derive_clone if( $a eq "derive_clone" );

		return;
	}

	if( $self->{processor}->{action} =~ m/move_(.*)_(.*)$/ )
	{
		my( $a, $b ) = ( $1, $2 );
		if( $self->allow( "action/eprint/".$self->{processor}->{action} ) )
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
			$self->{processor}->action_not_allowed( "eprint/".$self->{processor}->{action} );
		}

		return;
	}

	$self->SUPER::from;
}

sub set_title
{
	my( $self ) = @_;

	$self->{processor}->{title} = $self->{session}->make_text("View Item");
}

sub render_status
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	my $status_fragment = $self->{session}->make_doc_fragment;
	$status_fragment->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:item_is_in_".$status ) );



	if( $self->allow( "action/eprint/deposit" ) )
	{
		# clean up
		my $deposit_div = $self->{session}->make_element( "div", id=>"controlpage_deposit_link" );
		my $a = $self->{session}->make_element( "a", href=>"?screen=EPrint::Deposit&eprintid=".$self->{processor}->{eprintid} );
		$a->appendChild( $self->{session}->make_text( "Deposit now!" ) );
		$deposit_div->appendChild( $a );
		$status_fragment->appendChild( $deposit_div );
	}

	return $status_fragment;
#	return $self->{session}->render_toolbox( 
#			$self->{session}->make_text( "Status" ),
#			$status_fragment );
}


sub render
{
	my( $self ) = @_;

	$self->set_title;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->render_status );

	# if in archive and can request delete then do that here TODO

	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" ) || 0;
	
	my $view = $self->{session}->param( "view" );

	if( !$self->allow( "view/eprint/$view" ) )
	{
		$view = undef;
	}
	my $id_prefix = "ep_eprint_views";

	my @views = qw/ summary full actions export export_staff edit edit_staff history /;
	my $tabs = [];
	my $labels = {};
	my $links = {};
	foreach my $view_i ( @views )
	{	
		next if( !$self->allow( "view/eprint/$view_i" ) );
		$view = $view_i if !defined $view;
		push @{$tabs}, $view_i;
		$labels->{$view_i} = $self->{session}->html_phrase( "priv:view/eprint/".$view_i );
		$links->{$view_i} = "?screen=".$self->{processor}->{screenid}."&eprintid=".$self->{processor}->{eprintid}."&view=".$view_i, 
	}

	$chunk->appendChild( 
		$self->{session}->render_tabs( 
			$id_prefix,
			$view,
			$tabs,
			$labels,
			$links,
			[ "history" ] ) );
			


	my $panel = $self->{session}->make_element( "div", id=>"${id_prefix}_panels", class=>"ep_tab_panel" );
	$chunk->appendChild( $panel );
	my $view_div = $self->{session}->make_element( "div", id=>"${id_prefix}_panel_$view" );
	$view_div->appendChild( $self->render_view( $view ) );	
	$panel->appendChild( $view_div );

	# don't render the other tabs if this is a slow tab - they must reload
	if( $view ne "history" )
	{
		foreach my $view_i ( @views )
		{
			next if( !$self->allow( "view/eprint/$view_i" ) );
			next if $view_i eq $view;
			my $other_view = $self->{session}->make_element( "div", id=>"${id_prefix}_panel_$view_i", style=>"display: none" );
			if( $view_i ne "history" )
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


sub render_view
{
	my( $self, $view ) = @_;

	my( $data, $title );
	if( !$self->allow( "view/eprint/$view" ) )
	{
		return $self->{session}->html_phrase( "cgi/users/edit_eprint:cant_view_view" );
	}

	if( $view eq "actions" ) { $data = $self->render_action_tab; }
	if( $view eq "summary" ) { ($data,$title) = $self->{processor}->{eprint}->render; }
	if( $view eq "full" ) { ($data,$title) = $self->{processor}->{eprint}->render_full; }
	if( $view eq "history" ) { ($data,$title) = $self->{processor}->{eprint}->render_history; }
	if( $view eq "export" ) { $data = $self->{processor}->{eprint}->render_export_links; }
	if( $view eq "export_staff" ) { $data = $self->{processor}->{eprint}->render_export_links(1); }
	if( $view eq "edit" ) { $data = $self->render_edit_tab(0); }
	if( $view eq "edit_staff" ) { $data = $self->render_edit_tab(1); }
	if( !defined $view )
	{
		return $self->{session}->html_phrase( "cgi/users/edit_eprint:no_such_view" );
	}
	return $data;
}

sub get_allowed_actions
{
	my( $self ) = @_;

	my @actions = ( 
		"deposit",
		"reject_with_email",
		"remove_with_email",

		"move_inbox_buffer", 
		"move_buffer_inbox", 
		"move_buffer_archive",
		"move_archive_buffer", 
		"move_archive_deletion",
		"move_deletion_archive",

		"move_inbox_archive", 
		"move_archive_inbox",  
		
		"derive_version", # New version
		"derive_clone", # Use as template

		"request_deletion",  
		"remove",
		"edit",
		"edit_staff",
	);

	my @r = ();

	foreach my $action ( @actions )
	{
		my $allow = $self->allow( "action/eprint/$action" );
		next if( !$allow );
		push @r, $action;
	}
	
	return @r;
}

sub render_action_tab
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $form = $self->render_form;
	my $table = $session->make_element( "table" );
	$form->appendChild( $table );
	my @actions =  $self->get_allowed_actions;

	foreach my $action ( $self->get_allowed_actions )
	{
		my $tr = $session->make_element( "tr" );
		my $td = $session->make_element( "th" );
		$td->appendChild( $session->render_hidden_field( "action", $action ) );
		$td->appendChild( 
			$session->make_element( 
				"input", 
				type=>"submit",
				class=>"actionbutton",
				name=>"_action_$action", 
				value=>$session->phrase( "priv:action/eprint/".$action ) ) );
		$tr->appendChild( $td );
		my $td2 = $session->make_element( "td", style=>'border: 1px #ccc solid; padding-left: 0.5em' );
		$td2->appendChild( $session->html_phrase( "priv:action/eprint/".$action.".help" ) ); 
		$tr->appendChild( $td2 );
		$table->appendChild( $tr );
	}
	return $form;
}

sub allow
{
	my( $self, $priv ) = @_;

	# Special case for the action tab when there is no possible actions

	if( $priv eq "view/eprint/actions" )
	{
		my @a = $self->get_allowed_actions;
		return 0 if( scalar @a == 0 );
	}

	my $allow_code = $self->{processor}->allow( $priv );

	# if we only have this because we're the editor then
	# don't allow this option.
	return 0 if( !( $allow_code & 4 ) );

	return $allow_code;
}

sub render_edit_tab
{
	my( $self, $staff ) = @_;

	my $session = $self->{processor}->{session};
	my $eprint = $self->{processor}->{eprint};
	my $escreen = "EPrint::Edit";
	if( $staff ) { $escreen = "EPrint::Edit_staff"; }

	my $workflow = $self->workflow( $staff );
	my $ul = $session->make_element( "ul" );
	foreach my $stage_id ( $workflow->get_stage_ids )
	{
		my $li = $session->make_element( "li" );
		my $a = $session->render_link( "?eprintid=".$self->{processor}->{eprintid}."&screen=$escreen&stage=$stage_id" );
		$li->appendChild( $a );
		$a->appendChild( $session->html_phrase( "metapage_title_".$stage_id ) );
		$ul->appendChild( $li );
	}
	return $ul;
}

sub derive_version
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

sub derive_clone
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

sub about_to_render 
{
	my( $self ) = @_;
}

sub can_be_viewed
{
	my( $self ) = @_;

	my $r = $self->{processor}->allow( "view/eprint/view/owner" );
	return 0 unless $r;

	return $self->SUPER::can_be_viewed;
}
1;

