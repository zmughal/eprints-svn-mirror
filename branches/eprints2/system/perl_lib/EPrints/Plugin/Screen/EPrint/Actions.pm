package EPrints::Plugin::Screen::EPrint::Actions;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 300,
		}
	];

	return $self;
}


sub get_allowed_actions_delete_me
{
	my( $self ) = @_;
	my @actions = ( 

		
		"derive_version", # New version 1200
		"derive_clone", # Use as template

		"request_deletion",  #1400 # 


###########done
		"edit", #1600
		"edit_staff",#1700
		"deposit", #100 #done.
		"reject_with_email", #done
		"remove_with_email", #done
		"remove", #done
		"move_inbox_buffer", #400
		"move_buffer_inbox", #500
		"move_buffer_archive",#600
		"move_archive_buffer", #700
		"move_archive_deletion",#800
		"move_deletion_archive",#900

		"move_inbox_archive", #1000
		"move_archive_inbox",  #1100
	);

	my @r = ();

	foreach my $action ( @actions )
	{
#		my $allow = $self->allow( "action/eprint/$action" );
#		next if( !$allow );
		push @r, $action;
	}
	
	return @r;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $table = $session->make_element( "table" );
	foreach my $item ( $self->list_items( "eprint_actions" ) )
	{
		my $tr = $session->make_element( "tr" );
		$table->appendChild( $tr );

		my $td = $session->make_element( "td" );
		$tr->appendChild( $td );

		my $form = $session->render_form( "form" );
		$td->appendChild( $form );
		$form->appendChild( $session->render_hidden_field( "eprintid", $self->{processor}->{eprintid} ) );

		$form->appendChild( $session->render_hidden_field( "screen", substr( $item->{screen_id}, 8 ) ) );
		my( $action, $title, $description );
		if( defined $item->{action} )
		{
			$action = $item->{action};
			$title = $item->{screen}->phrase( "action:$action:title" );
			$description = $item->{screen}->html_phrase( "action:$action:description" );
		}
		else
		{
			$action = "null";
			$title = $item->{screen}->phrase( "title" );
			$description = $item->{screen}->html_phrase( "description" );
		}
		$form->appendChild( 
			$session->make_element( 
				"input", 
				type=>"submit",
				class=>"ep_form_action_button",
				name=>"_action_$action", 
				value=>$title ));

		my $td2 = $session->make_element( "td" );
		$tr->appendChild( $td2 );

		$td2->appendChild( $description );
	}
	
	return $table;
#				style => 'border: 1px #ccc solid; padding-left: 0.5em' );
}

1;
