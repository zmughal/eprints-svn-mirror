
package EPrints::Plugin::Screen::EPrint::View::Owner;

use EPrints::Plugin::Screen::EPrint::View;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::View' );

use strict;



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


# don't do what view does 
sub about_to_render 
{
}

1;

