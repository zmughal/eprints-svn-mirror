
package EPrints::Plugin::Screen::EPrint::View::Other;

use EPrints::Plugin::Screen::EPrint::View;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::View' );

use strict;


sub set_title
{
	my( $self ) = @_;

	$self->{processor}->{title} = $self->{session}->make_text("Registered User View of Item");
}

sub render_status
{
	my( $self ) = @_;

	my $status_fragment = $self->{session}->make_doc_fragment;

	return $status_fragment;

#	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );
#	$status_fragment->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:item_is_in_".$status ) );
#
#	return $self->{session}->render_toolbox( 
#			$self->{session}->make_text( "Status" ),
#			$status_fragment );
}

sub allow
{
	my( $self, $priv ) = @_;

	# Special case for the action tab when there is no possible actions

#	if( $priv eq "view/eprint/actions" )
#	{
#		my @a = $self->get_allowed_actions;
#		return 0 if( scalar @a == 0 );
#	}

	my $allow_code = $self->{processor}->allow( $priv );

	# if we only have this because we're the owner then
	# don't allow this option.
	return( $allow_code & 2 );
}

sub about_to_render 
{
	my( $self ) = @_;
}

1;

