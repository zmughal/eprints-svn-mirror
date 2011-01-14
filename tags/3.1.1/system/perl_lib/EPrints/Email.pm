######################################################################
#
# EPrints::Email
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Email> - Email Utility functions for EPrints.

=head1 DESCRIPTION

This package handles sending emails.

=over 4

=cut

package EPrints::Email;

use Unicode::String qw(utf8 latin1 utf16);
use MIME::Lite;
use LWP::MediaTypes qw( guess_media_type );

use strict;


######################################################################
=pod

=item EPrints::Utils::send_mail( %properties )

Sends an email. 

Required properties:

session - the current session

langid - the id of the language to send the email in.

to_email, to_name - who to send it to

subject - the subject of the message (UTF-8 encoded string)

message - the body of the message as a DOM tree

optional properties:

from_email, from_name - who is sending the email (defaults to the archive admin)

sig - the signature file as a DOM tree

replyto_email, replyto_name

attach - ref to an array of filenames (with full paths) to attach to the message 

Returns true if mail sending (appears to have) succeeded. False otherwise.

Uses the config. option "send_email" to send the mail, or if that's
not defined sends the email via STMP.

names and the subject should be encoded as utf-8


=cut
######################################################################

sub send_mail
{
	my( %p ) = @_;

	my $repository = $p{session}->get_repository;

	if( defined $p{message} )
	{
		my $msg = $p{message};

		# First get the body
		my $body = $p{session}->html_phrase( 
			"mail_body",
			content => $p{session}->clone_for_me($msg,1) );
		# Then add the HTML around it
		my $html = $p{session}->html_phrase(
			"mail_wrapper",
			body => $body );

		$p{message} = $html;
	}

	if( !defined $p{from_email} ) 
	{
		$p{from_name} = $p{session}->phrase( "archive_name" );
		$p{from_email} = $repository->get_conf( "adminemail" );
	}
	
	# If a name contains a comma we must quote it, because comma is the
	# separator for multiple addressees
	foreach my $name (qw( from_name to_name replyto_name ))
	{
		if( defined $p{$name} and $p{$name} =~ /,/ )
		{
			$p{$name} = "\"".$p{$name}."\"";
		}
	}

	my $result;
	if( $repository->can_call( 'send_email' ) )
	{
		$result = $repository->call( 'send_email', %p );
	}
	else
	{
		$result = send_mail_via_sendmail( %p );
	}

	if( !$result )
	{
		$p{session}->get_repository->log( "Failed to send mail.\nTo: $p{to_email} <$p{to_name}>\nSubject: $p{subject}\n" );
	}

	return $result;
}


######################################################################
#=pod
#
#=item EPrints::Utils::send_mail_via_smtp( %properties )
#
#Send an email via STMP. Should not be called directly, but rather by
#EPrints::Utils::send_mail.
#
#=cut
######################################################################

sub send_mail_via_smtp
{
	my( %p ) = @_;

	eval 'use Net::SMTP';

	my $repository = $p{session}->get_repository;

	my $smtphost = $repository->get_conf( 'smtp_server' );

	if( !defined $smtphost )
	{
		$repository->log( "No STMP host has been defined. To fix this, find the full\naddress of your SMTP server (eg. smtp.example.com) and add it\nas the value of smtp_server in\nperl_lib/EPrints/SystemSettings.pm" );
		return( 0 );
	}

	my $smtp = Net::SMTP->new( $smtphost );
	if( !defined $smtp )
	{
		$repository->log( "Failed to create smtp connection to $smtphost" );
		return( 0 );
	}

	
	$smtp->mail( $p{from_email} );
	if( !$smtp->recipient( $p{to_email} ) )
	{
		$repository->log( "smtp server refused <$p{to_email}>" );
		$smtp->quit;
		return 0;
	}
	my $message = build_email( %p );
	$smtp->data();
	$smtp->datasend( $message->as_string );
	$smtp->dataend();
	$smtp->quit;

	return 1;
}

######################################################################
# =pod
# 
# =item EPrints::Utils::send_mail_via_sendmail( %params )
# 
# Also should not be called directly. The config. option "send_email"
# can be set to \&EPrints::Utils::send_mail_via_sendmail to use the
# sendmail command to send emails rather than send to a SMTP server.
# 
# =cut
######################################################################

sub send_mail_via_sendmail
{
	my( %p )  = @_;

	my $repository = $p{session}->get_repository;

	unless( open( SENDMAIL, "|".$repository->invocation( "sendmail" ) ) )
	{
		$repository->log( "Failed to invoke sendmail: ".
			$repository->invocation( "sendmail" ) );
		return( 0 );
	}
	my $message = build_email( %p );
	print SENDMAIL $message->as_string;
	close(SENDMAIL) or return( 0 );
	return( 1 );
}

# $mime_message = EPrints::Utils::build_mail( %params ) 
#
# Takes the same parameters as send_mail. This creates a MIME::Lite email
# object with both a text and an HTML part.

sub build_email
{
	my( %p ) = @_;

	my $MAILWIDTH = 80;

	my $repository = $p{session}->get_repository;

	my $mimemsg = MIME::Lite->new(
		From       => "$p{from_name} <$p{from_email}>",
		To         => "$p{to_name} <$p{to_email}>",
		Subject    => $p{subject},
		Type       => "multipart/alternative",
		Precedence => "bulk",
	);

	if( defined $p{replyto_email} )
	{
		$mimemsg->attr( "Reply-to" => "$p{replyto_name} <$p{replyto_email}>" );
	}
	$mimemsg->replace( "X-Mailer" => "EPrints http://eprints.org/" );


	# If there are file attachments, change to a "mixed" type
	# and attach the body Text and HTML to an "alternative" subpart
	my $mixedmsg;
	if( $p{attach} )
	{
		$mixedmsg = $mimemsg;
		$mixedmsg->attr( "Content-Type" => "multipart/mixed" );
		$mimemsg = MIME::Lite->new(
			Type => "multipart/alternative",
		);
		$mixedmsg->attach( $mimemsg );
	}

	my $xml_mail = $p{message};
	my $data = EPrints::Utils::tree_to_utf8( $xml_mail , $MAILWIDTH, 0, 0, 0 );

	my $text = MIME::Lite->new( 
		Type  => "TEXT",
		Data  => $data
	);
	$text->attr('content-type.charset' => 'utf-8');
	$text->attr("Content-disposition" => "");
	$mimemsg->attach( $text );
	my $html = MIME::Lite->new( 
		Type  => "text/html",
		Data  => EPrints::XML::to_string($xml_mail, undef, 1),
	);
	$html->attr('content-type.charset' => 'utf-8');
	$html->attr("Content-disposition" => "");
	$mimemsg->attach( $html );

	if( !$p{attach} )
	{
		# not a multipart message
		return $mimemsg;
	}

	foreach my $file ( @{ $p{attach} } )
	{
		my $part = MIME::Lite->new(
			Type => guess_media_type( $file ),
			Path => $file,
		);
		$mixedmsg->attach( $part );
	}

	return $mixedmsg;
}




1;