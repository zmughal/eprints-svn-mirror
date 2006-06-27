
package EPrints::Interface::EPrint::Control;

use EPrints::Interface::Screen;
use EPrints::Interface::EPrint::Deposit;


@ISA = ( 'EPrints::Interface::Screen' );

use strict;

sub from
{
	my( $class, $interface ) = @_;

	if( $interface->{action} eq "deposit" )
	{
		$interface->action_deposit;
	}
	elsif( $interface->{action} eq "want_to_deposit" )
	{
		if( $interface->allow_action( "deposit" ) )
		{
			$interface->{screenid} = "deposit";
		}
		else
		{
			$interface->action_not_allowed;
		}
	}
}

sub render
{
	my( $class, $interface ) = @_;

	my $chunk = $interface->{session}->make_doc_fragment;

	$interface->{title} = $interface->{session}->make_text("Hi mom");

	my $status = $interface->{eprint}->get_value( "eprint_status" );
	if( $status eq "inbox" )
	{
		my $div = $interface->{session}->make_element( "div", style=>"border: 1px solid black; margin: 1em 0 1em 0; padding: 1em" );
		$div->appendChild( $interface->{session}->make_text( "blister bar!" ) );
		$chunk->appendChild( $div );
	}

	my $status_phrase = $interface->{session}->html_phrase( "cgi/users/edit_eprint:item_is_in_".$status );

	my $status_div = $interface->{session}->make_element( "div", style=>"border: 1px solid black; margin: 1em 0 1em 0; padding: 1em" );
	$status_div->appendChild( $status_phrase );
	$chunk->appendChild( $status_div );

	if( $interface->allow_action( "deposit" ) )
	{
		# clean up
		my $deposit_div = $interface->{session}->make_element( "div", id=>"controlpage_deposit_link" );
		my $a = $interface->{session}->make_element( "a", href=>"?screen=control&eprintid=".$interface->{eprintid}."&action=want_to_deposit", onclick=>"Element.toggle( 'controlpage_deposit_link','controlpage_deposit_form'); return false;" );
		$a->appendChild( $interface->{session}->make_text( "deposit now!" ) );
		$deposit_div->appendChild( $a );
		$status_div->appendChild( $deposit_div );
		my $hidden_div = $interface->{session}->make_element( "div", id=>"controlpage_deposit_form", style=>"display: none" );
		$hidden_div->appendChild( EPrints::Interface::EPrint::Deposit->render_deposit_form( $interface ) );
		$status_div->appendChild( $hidden_div );
	}
	
	# if in archive and can request delete then do that here TODO

	# Actions bar
	my @actions;

	my $sb = $interface->{session}->get_repository->get_conf( "skip_buffer" ) || 0;
	
	@actions = ( 
		# Move actions (deposit is handled above)
		"move_eprint_buffer_inbox", # Bounce
		"move_eprint_buffer_archive", # Approve
		"move_eprint_archive_inbox",  # Back to inbox from archive
		"move_eprint_archive_buffer", # Back to review from archive
		"move_eprint_archive_deletion", # Retire
		"move_eprint_deletion_archive", # Unretire 
		
		"derive_eprint_version", # New version
		"derive_eprint_clone", # Use as template
		"request_eprint_deletion",  
		"view_buffer",  
	);

	my $action_bar = $interface->{session}->make_element( "div", class => "ep_action_bar" );
	$action_bar->appendChild( $interface->make_action_bar( @actions ) );
	$chunk->appendChild( $action_bar );


	my $view = $interface->{session}->param( "view" );

	if( !$interface->allow_action( "view_$view" ) )
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
		child.className -= "ep_selected";
	}

	panel = document.getElementById( baseid+"_panel_"+tabid );
	panel.style.display = "block";

	tab = document.getElementById( baseid+"_tab_"+tabid );
	tab.style.font_size = "30px";
	tab.className = "ep_selected";
};

' ) );

	my $ul = $interface->{session}->make_element( "ul",id=>"ep_control_view_tabs",  class=>"ep_control_view_tabs" );

	my @lite_views = qw/ summary full export staffexport edit staffedit /;
	my @views = ( @lite_views, "history" );
	foreach my $view_i ( @views )
	{	
		next if( !$interface->allow_action( "view_$view_i" ) );

		$view = $view_i if !defined $view;
		my %a_opts = ( 
			onClick => "ep_showTab('ep_control_view','$view_i' ); return false;", 
			href    => "?eprintid=".$interface->{eprintid}."&view=".$view_i, 
		);
		my %li_opts = ( id => "ep_control_view_tab_$view_i" );
		if( $view eq $view_i ) { $li_opts{class} = "ep_selected"; }

		my $a = $interface->{session}->make_element( "a", %a_opts );
		my $li = $interface->{session}->make_element( "li", %li_opts );
		my $label = $interface->{session}->html_phrase( $interface->interface.":action_view_".$view_i );

		$a->appendChild( $label );
		$li->appendChild( $a );

		$ul->appendChild( $li );
	}
	$chunk->appendChild( $ul );

	my $panel = $interface->{session}->make_element( "div", id=>"ep_control_view_panels" );
	$chunk->appendChild( $panel );
	my $view_div = $interface->{session}->make_element( "div", class=>"ep_control_view", id=>"ep_control_view_panel_$view" );
	$view_div->appendChild( render_view( $interface, $view ) );	
	$panel->appendChild( $view_div );

	foreach my $view_i ( @lite_views )
	{
		next if( !$interface->allow_action( "view_$view_i" ) );
		next if $view_i eq $view;
		my $other_view = $interface->{session}->make_element( "div", class=>"ep_control_view", id=>"ep_control_view_panel_$view_i", style=>"display: none" );
		$other_view->appendChild( render_view( $interface, $view_i ) );	
		$panel->appendChild( $other_view );
	}

	return $chunk;
}

sub render_view
{
	my( $interface, $view ) = @_;

	my( $data, $title );
	if( !$interface->allow_action( "view_$view" ) )
	{
		return $interface->{session}->html_phrase( "cgi/users/edit_eprint:cant_view_view" );
	}

	if( $view eq "summary" ) { ($data,$title) = $interface->{eprint}->render; }
	if( $view eq "full" ) { ($data,$title) = $interface->{eprint}->render_full; }
	if( $view eq "history" ) { ($data,$title) = $interface->{eprint}->render_history; }
	if( $view eq "export" ) { $data = $interface->{eprint}->render_export_links; }
	if( $view eq "staffexport" ) { $data = $interface->{eprint}->render_export_links(1); }
	if( $view eq "edit" ) { $data = render_edit_tab( $interface->{session}, $interface->{eprint}, 0 ); }
	if( $view eq "staffedit" ) { $data = render_edit_tab( $interface->{session}, $interface->{eprint}, 1 ); }

	if( !defined $view )
	{
		return $interface->{session}->html_phrase( "cgi/users/edit_eprint:no_such_view" );
	}

	return $data;
}

sub render_edit_tab
{
	my( $session, $eprint, $staff ) = @_;

	my %opts = ( item=> $eprint );
	if( $staff ) { $opts{STAFF_ONLY} = "TRUE"; }
	my $workflow = EPrints::Workflow->new( $session, "default", %opts );
	my $ul = $session->make_element( "ul" );
	foreach my $stage_id ( $workflow->get_stage_ids )
	{
		my $li = $session->make_element( "li" );
		my $a = $session->render_link( "xxxx" );
		$li->appendChild( $a );
		$a->appendChild( $session->make_text( $stage_id ) );
		$ul->appendChild( $li );
	}
	return $ul;
}


1;

