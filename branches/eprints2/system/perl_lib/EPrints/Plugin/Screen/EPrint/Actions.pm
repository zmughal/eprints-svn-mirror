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
				class=>"ep_form_action_button",
				name=>"_action_$action", 
				value=>$session->phrase( "priv:action/eprint/".$action ) ) );
		$tr->appendChild( $td );
		my $td2 = $session->make_element( 
				"td", 
				style => 'border: 1px #ccc solid; padding-left: 0.5em' );
		$td2->appendChild( 
			$session->html_phrase( 
				"priv:action/eprint/".$action.".help" ) ); 
		$tr->appendChild( $td2 );
		$table->appendChild( $tr );
	}

	return $form;
}

1;
