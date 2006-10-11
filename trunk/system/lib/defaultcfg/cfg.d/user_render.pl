
######################################################################

=item $xhtmlfragment = user_render( $user, $session )

This subroutine takes a user object and renders the XHTML view
of this user for public viewing.

Takes the L<$user|EPrints::DataObj::User> to render and the current L<$session|EPrints::Session>.

Returns an $xhtmlfragment (see L<EPrints::XML>).

=cut

######################################################################


sub user_render
{
	my( $user, $session ) = @_;

	my $html;	

	my( $info, $p, $a );
	$info = $session->make_doc_fragment;


	# Render the public information about this user.
	$p = $session->make_element( "p" );
	$p->appendChild( $user->render_description() );
	# Address, Starting with dept. and organisation...
	if( $user->is_set( "dept" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "dept" ) );
	}
	if( $user->is_set( "org" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "org" ) );
	}
	if( $user->is_set( "address" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "address" ) );
	}
	if( $user->is_set( "country" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "country" ) );
	}
	$info->appendChild( $p );
	
	if( $user->is_set( "usertype" ) )
	{
		$p = $session->make_element( "p" );
		$p->appendChild( $session->html_phrase( "user_fieldname_usertype" ) );
		$p->appendChild( $session->make_text( ": " ) );
		$p->appendChild( $user->render_value( "usertype" ) );
		$info->appendChild( $p );
	}

	## E-mail and URL last, if available.
	if( $user->get_value( "hideemail" ) ne "TRUE" )
	{
		if( $user->is_set( "email" ) )
		{
			$p = $session->make_element( "p" );
			$p->appendChild( $user->render_value( "email" ) );
			$info->appendChild( $p );
		}
	}

	if( $user->is_set( "url" ) )
	{
		$p = $session->make_element( "p" );
		$p->appendChild( $user->render_value( "url" ) );
		$info->appendChild( $p );
	}
		

	return( $info );
}

