
package EPrints::Plugin::Screen::EPrint::View;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;


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

sub about_to_render 
{
	my( $self ) = @_;

	my $cuser = $self->{session}->current_user;
	my $owner = $cuser->is_owner( $self->{processor}->{eprint} );
	my $editor = $cuser->can_edit( $self->{processor}->{eprint} );

	if( $editor )
	{
		$self->{processor}->{screenid} = "EPrint::View::Editor";	
		return;
	}
	if( $owner )
	{
		$self->{processor}->{screenid} = "EPrint::View::Owner";	
		return;
	}
	$self->{processor}->{screenid} = "EPrint::View::Other";	
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
	if( defined $view )
	{
		$view = "Screen::$view";
	}

	my $id_prefix = "ep_eprint_views";

#	my @views = qw/ summary full actions export export_staff edit edit_staff history /;



	my $tabs = [];
	my $labels = {};
	my $links = {};
	my $slowlist = [];
	my $position = {};
	foreach my $item ( $self->list_items( "eprint_view_tabs" ) )
	{
		if( $item->{screen}->{expensive} )
		{
			push @{$slowlist}, $item->{screen_id};
		}

		push @{$tabs}, $item->{screen_id};
		$position->{$item->{screen_id}} = $item->{position};
		$labels->{$item->{screen_id}} = $item->{screen}->render_title;
		$links->{$item->{screen_id}} = "?screen=".$self->{processor}->{screenid}."&eprintid=".$self->{processor}->{eprintid}."&view=".substr( $item->{screen_id}, 8 );
	}

	@{$tabs} = sort { $position->{$a} <=> $position->{$b} } @{$tabs};
	if( !defined $view )
	{
		$view = $tabs->[0] 
	}

	$chunk->appendChild( 
		$self->{session}->render_tabs( 
			$id_prefix,
			$view,
			$tabs,
			$labels,
			$links,
			$slowlist ) );
			
	my $panel = $self->{session}->make_element( 
			"div", 
			id => "${id_prefix}_panels", 
			class => "ep_tab_panel" );
	$chunk->appendChild( $panel );
	my $view_div = $self->{session}->make_element( 
			"div", 
			id => "${id_prefix}_panel_$view" );

	my $screen = $self->{session}->plugin( 
			$view,
			processor => $self->{processor} );
	if( !defined $screen )
	{
		$view_div->appendChild( 
			$self->{session}->html_phrase(
				"cgi/users/edit_eprint:view_unavailable" ) ); # error
	}
	elsif(  defined $screen->{priv} && !$self->allow( $screen->{priv} ) )
	{
		$view_div->appendChild( 
			$self->{session}->html_phrase(
				"cgi/users/edit_eprint:view_unavailable" ) );
	}
	else
	{
		$view_div->appendChild( $screen->render );
	}

	$panel->appendChild( $view_div );

	my $view_slow = 0;
	foreach my $slow ( @{$slowlist} )
	{
		$view_slow = 1 if( $slow eq $view );
	}
	return $chunk if $view_slow;
	
	# don't render the other tabs if this is a slow tab - they must reload
	foreach my $screen_id ( @{$tabs} )
	{
		next if $screen_id eq $view;
		my $other_view = $self->{session}->make_element( 
			"div", 
			id => "${id_prefix}_panel_$screen_id", 
			style => "display: none" );
		$panel->appendChild( $other_view );

		my $screen = $self->{session}->plugin( 
			$screen_id,
			processor=>$self->{processor} );
		if( $screen->{expensive} )
		{
			$other_view->appendChild( $self->{session}->html_phrase( 
					"cgi/users/edit_eprint:loading" ) );
			next;
		}

		$other_view->appendChild( $screen->render );
	}

	return $chunk;
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



1;

