######################################################################
#
# Site Specific Routines
#
#  Routines for handling operations that will vary from site to site
#
######################################################################
#
# 06/01/00 - Created by Robert Tansley
#
######################################################################

package EPrintSite::SiteRoutines;

use EPrints::EPrint;
use EPrints::User;
use EPrints::Session;
use EPrints::Name;

use strict;



######################################################################
#
# $title = eprint_short_title( $eprint )
#
#  Return a single line concise title for an EPrint, for rendering
#  lists
#
######################################################################

sub eprint_short_title
{
	my( $class, $eprint ) = @_;
	
	if( !defined $eprint->{title} || $eprint->{title} eq "" )
	{
		return( "Untitled (ID: $eprint->{eprintid})" );
	}
	else
	{
		return( $eprint->{title} );
	}
}


######################################################################
#
# $title = eprint_render_full( $eprint )
#
#  Return HTML for rendering an EPrint
#
######################################################################

sub eprint_render_full
{
	my( $class, $eprint ) = @_;
	
	my $html = "<P><TABLE BORDER=0>\n";
	
	my @fields = EPrints::MetaInfo->get_eprint_fields( $eprint->{type} );
	my $field;
	
	foreach $field (@fields)
	{
		if( $field->{visible} )
		{
			$html .= "<TR><TD><STRONG>$field->{displayname}</STRONG></TD><TD>";
			$html .= $eprint->{session}->{render}->format_field(
				$field,
				$eprint->{$field->{name}} );
			$html .= "</TD></TR>\n";
		}
	}
	$html .= "</TABLE></P>\n";

	return( $html );
}


######################################################################
#
# $html = eprint_render_citation( $eprint )
#
#  Return HTML for rendering an EPrint in a form suitable for a
#  bibliography
#
######################################################################

sub eprint_render_citation
{
	my( $class, $eprint ) = @_;
	
	return( "$eprint->{authors} (<B>$eprint->{year}</B>) $eprint->{title}" );
}


######################################################################
#
# $name = user_display_name( $user )
#
#  Return the user's name in a form appropriate for display.
#
######################################################################

sub user_display_name
{
	my( $class, $user ) = @_;

	# If no surname, just return the username
	return( "User $user->{username}" ) if( !defined $user->{name} ||
	                                       $user->{name} eq "" );

	return( EPrints::Name->format_name( $user->{name}, 1 ) );
}


######################################################################
#
# session_init( $session, $offline )
#        EPrints::Session  boolean
#
#  Invoked each time a new session is needed (generally one per
#  script invocation.) $session is a session object that can be used
#  to store any values you want. To prevent future clashes, prefix
#  all of the keys you put in the hash with site_.
#
#  If $offline is non-zero, the session is an `off-line' session, i.e.
#  it has been run as a shell script and not by the web server.
#
######################################################################

sub session_init
{
	my( $session, $offline ) = @_;
}


######################################################################
#
# session_close( $session )
#
#  Invoked at the close of each session. Here you should clean up
#  anything you did in session_init().
#
######################################################################

sub session_close
{
	my( $session ) = @_;
}


######################################################################
#
# update_submitted_eprint( $eprint )
#
#  This function is called on an EPrint whenever it is transferred
#  from the inbox (the author's workspace) to the submission buffer.
#  You can alter the EPrint here if you need to, or maybe send a
#  notification mail to the administrator or something. 
#
#  Any changes you make to the EPrint object will be written to the
#  database after this function finishes, so you don't need to do a
#  commit().
#
######################################################################

sub update_submitted_eprint
{
	my( $class, $eprint ) = @_;
}


######################################################################
#
# update_archived_eprint( $eprint )
#
#  This function is called on an EPrint whenever it is transferred
#  from the submission buffer to the real archive (i.e. when it is
#  actually "archived".)
#
#  You can alter the EPrint here if you need to, or maybe send a
#  notification mail to the author or administrator or something. 
#
#  Any changes you make to the EPrint object will be written to the
#  database after this function finishes, so you don't need to do a
#  commit().
#
######################################################################

sub update_archived_eprint
{
	my( $class, $eprint ) = @_;
}

1;
