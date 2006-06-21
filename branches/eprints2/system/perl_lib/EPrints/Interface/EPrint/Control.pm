
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

	my $status_phrase = $interface->{session}->html_phrase( "cgi/users/eprint:item_is_in_".$status );

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


	my $ul = $interface->{session}->make_element( "ul",class=>"ep_control_view_tabs" );

	my $view = $interface->{session}->param( "view" );

	if( !$interface->allow_action( "view_$view" ) )
	{
		$view = undef;
	}

	foreach my $view_i ( qw/ summary full history / )
	{	
		next if( !$interface->allow_action( "view_$view_i" ) );

		$view = $view_i if !defined $view;
		
		my $a = $interface->{session}->render_link( "?eprintid=".$interface->{eprintid}."&view=".$view_i );
		my $label = $interface->{session}->html_phrase( $interface->interface.":action_view_".$view_i );

		my $li;
		if( $view eq $view_i )
		{
			$li = $interface->{session}->make_element( "li", class=>"ep_selected" );
			$li->appendChild( $label );
		}
		else
		{
			$li = $interface->{session}->make_element( "li" );
			$a->appendChild( $label );
			$li->appendChild( $a );
		}

		$ul->appendChild( $li );
	}

	my $view_div = $interface->{session}->make_element( "div", class=>"ep_control_view" );
	my( $data, $title );
	if( $view eq "summary" ) { ($data,$title) = $interface->{eprint}->render; }
	if( $view eq "full" ) { ($data,$title) = $interface->{eprint}->render_full; }
	if( $view eq "history" ) { ($data,$title) = $interface->{eprint}->render_history; }
	$view_div->appendChild( $data );	
	$chunk->appendChild( $ul );
	$chunk->appendChild( $view_div );

	return $chunk;
}


1;

