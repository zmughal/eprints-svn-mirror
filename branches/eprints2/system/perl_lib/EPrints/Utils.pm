######################################################################
#
# EPrints::Utils
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

B<EPrints::Utils> - Utility functions for EPrints.

=head1 DESCRIPTION

This package contains functions which don't belong anywhere else.

=over 4

=cut

package EPrints::Utils;

use Filesys::DiskSpace;
use Unicode::String qw(utf8 latin1 utf16);
use File::Path;
use Term::ReadKey;
use URI;

use strict;

$EPrints::Utils::FULLTEXT = "_fulltext_";

my $DF_AVAILABLE;

BEGIN {
	$DF_AVAILABLE = 0;

	sub detect_df 
	{
		my $dir = "/";
		my ($fmt, $res);
	
		# try with statvfs..
		eval 
		{  
			{
				package main;
				require "sys/syscall.ph";
			}
			$fmt = "\0" x 512;
			$res = syscall (&main::SYS_statvfs, $dir, $fmt) ;
			$res == 0;
		}
		# try with statfs..
		|| eval 
		{ 
			{
				package main;
				require "sys/syscall.ph";
			}	
			$fmt = "\0" x 512;
			$res = syscall (&main::SYS_statfs, $dir, $fmt);
			$res == 0;
		}
	}
	unless( $EPrints::SystemSettings::conf->{disable_df} )
	{
		$DF_AVAILABLE = detect_df();
		if( !$DF_AVAILABLE )
		{
			print STDERR <<END;
---------------------------------------------------------------------------
df ("Disk Free" system call) appears to be unavailable on your server. To 
enable it, you should run 'h2ph * */*' (as root) in your /usr/include 
directory. See the EPrints manual for more information.

If you can't get df working on your system, you can work around it by
adding 
  disable_df => 1
to .../eprints2/perl_lib/EPrints/SystemSettings.pm
but you should read the manual about the implications of doing this.
---------------------------------------------------------------------------
END
			exit;
		}
	}
}



######################################################################
=pod

=item $space =  EPrints::Utils::df_dir( $dir )

Return the number of bytes of disk space available in the directory
$dir or undef if we can't find out.

=cut
######################################################################

sub df_dir
{
	my( $dir ) = @_;

	return df $dir if( $DF_AVAILABLE );
	die( "Attempt to call df when df function is not available." );
}


######################################################################
=pod

=item $cmd = EPrints::Utils::prepare_cmd($cmd,%VARS)

Prepare command string $cmd by substituting variables (specified by
C<$(varname)>) with their value from %VARS (key is C<varname>). All %VARS are
quoted before replacement to make it shell-safe.

If a variable is specified in $cmd, but not present in %VARS a die is thrown.

=cut
######################################################################

sub prepare_cmd {
	my ($cmd, %VARS) = @_;
	$cmd =~ s/\$\(([\w_]+)\)/defined($VARS{$1}) ? quotemeta($VARS{$1}) : die("Unspecified variable $1 in $cmd")/seg;
	$cmd;
}

######################################################################
=pod

=item $path = EPrints::Utils::join_path(@PARTS)

Join a path together in an OS-safe manner. Currently this just joins using '/'.
If EPrints is adapted to work under WinOS it will need to use '\' to join paths
together.

=cut
######################################################################

sub join_path
{
	return join('/', @_);
}

######################################################################
=pod

=item $xhtml = EPrints::Utils::render_date( $session, $datevalue )

Render the given date or date and time as a chunk of XHTML.

=cut
######################################################################

sub render_date
{
	my( $session, $datevalue ) = @_;

	if( !defined $datevalue )
	{
		return $session->html_phrase( "lib/utils:date_unspecified" );
	}

	# remove 0'd days and months
	$datevalue =~ s/(-0+)+$//;

	my( $year,$mon,$day,$hour,$min,$sec ) = split /[- :]/, $datevalue;

	if( !defined $year || $year eq "undef" || $year == 0 ) 
	{
		return $session->html_phrase( "lib/utils:date_unspecified" );
	}

	# 1999
	my $r = $year;

	$r = EPrints::Utils::get_month_label( $session, $mon )." $r" if( defined $mon );
	$r = "$day $r" if( defined $day );
	if( defined $hour )
	{
		my $time;
		if( defined $sec ) 
		{
			$time = sprintf( "%02d:%02d:%02d",$hour,$min,$sec );
		}
		elsif( defined $min )
		{
			$time = sprintf( "%02d:%02d",$hour,$min );
		}
		else
		{
			$time = sprintf( "%02d",$hour );
		}
		$r = "$time on $r";
	}	

	return $session->make_text( $r );
}


######################################################################
=pod

=item $label = EPrints::Utils::get_month_label( $session, $monthid )

Return a UTF-8 string describing the month, in the current lanugage.

$monthid is a 3 character code: jan, feb, mar... etc.

=cut
######################################################################

sub get_month_label
{
	my( $session, $monthid ) = @_;

	my $code = sprintf( "lib/utils:month_%02d", $monthid );

	return $session->phrase( $code );
}



######################################################################
=pod

=item $string = EPrints::Utils::make_name_string( $name, [$familylast] )

Return a string containing the name described in the hash reference
$name. 

The keys of the hash are one or more of given, family, honourific and
lineage. The values are utf-8 strings.

Normally the result will be:

"family lineage, honourific given"

but if $familylast is true then it will be:

"honourific given family lineage"

=cut
######################################################################

sub make_name_string
{
	my( $name, $familylast ) = @_;

	EPrints::abort "make_name_string expected hash reference" unless ref($name) eq "HASH";

	my $firstbit = "";
	if( defined $name->{honourific} && $name->{honourific} ne "" )
	{
		$firstbit = $name->{honourific}." ";
	}
	if( defined $name->{given} )
	{
		$firstbit.= $name->{given};
	}
	
	
	my $secondbit = "";
	if( defined $name->{family} )
	{
		$secondbit = $name->{family};
	}
	if( defined $name->{lineage} && $name->{lineage} ne "" )
	{
		$secondbit .= " ".$name->{lineage};
	}

	
	if( defined $familylast && $familylast )
	{
		return $firstbit." ".$secondbit;
	}
	
	return $secondbit.", ".$firstbit;
}


######################################################################
=pod

=item EPrints::Utils::send_mail( $repository, $langid, $name, $address, $subject, $body, $sig, [$replyto, $replytoname] )

Sends an email. 

$repository - the repository sending the email.

$langid - the language id (eg. "en")

$name - the name of the recipient (UTF-8 encoded string)

$address - the email address of the recipient

$subject - the subject of the message (UTF-8 encoded string)

$body - the body of the message as a DOM tree

$sig - the signature file as a DOM tree

$replyto -  the reply-to email address 

$replytoname - the reply-to name (UTF-8 encoded string)

Returns true if mail sending (appears to have) succeeded. False otherwise.

Uses the config. option "send_email" to send the mail, or if that's
not defined sends the email via STMP.

=cut
######################################################################

sub send_mail
{
	my( $repository, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname ) = @_;
	#   repository   string   utf8   utf8      utf8      DOM    DOM   string    utf8

	my $mail_func = $repository->get_conf( "send_email" );
	if( !defined $mail_func )
	{
		$mail_func = \&send_mail_via_sendmail;
	}

	my $result = &{$mail_func}( $repository, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname );

	if( !$result )
	{
		$repository->log( "Failed to send mail.\nTo: $address <$name>\nSubject: $subject\n" );
	}

	return $result;
}

######################################################################
=pod

=item $datestring = EPrints::Utils::email_date()

Returns the current date and time formatted appropriately for an email
Date: field.

=cut
######################################################################

sub email_date()
{
	my @D = qw/Sun Mon Tue Wed Thu Fri Sat/;
	my @M = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;

	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
	my @gmt = gmtime(time);

	my $zone = $hour-$gmt[2];
	if( $zone > 12 ) { $zone-=24; }
	if( $zone < -12 ) { $zone+=24; }

	my $date = $D[$wday].', '.$mday.' '.$M[$mon].' '.($year+1900).' ';
	$date .= sprintf( "%02d:%02d:%02d ", $hour, $min, $sec );
	if( $zone < 0 ) { $date.='-'; $zone = -$zone; } else { $date.='+'; }
	$date .= sprintf( "%02d",$zone ).'00';

	return $date;
}



######################################################################
=pod

=item EPrints::Utils::send_mail_via_smtp( $repository, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname )

Send an email via STMP. Should not be called directly, but rather by
EPrints::Utils::send_mail.

=cut
######################################################################

sub send_mail_via_smtp
{
	my( $repository, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname ) = @_;
	#   repository   string   utf8   utf8      utf8      DOM    DOM   string    utf8

	my $smtphost = $repository->get_conf( 'smtp_server' );

	if( !defined $smtphost )
	{
		$repository->log( "No STMP host has been defined. To fix this, find the full\naddress of your SMTP server (eg. smtp.example.com) and add it\nas the value of smtp_server in\nperl_lib/EPrints/SystemSettings.pm" );
		return( 0 );
	}


	use Net::SMTP;
	my $smtp=Net::SMTP->new( $smtphost );
	if( !defined $smtp )
	{
		$repository->log( "Failed to create smtp connection to $smtphost" );
		return( 0 );
	}
	# test ?
#	unless( open( SENDMAIL, "|".$repository->invocation( "sendmail" ) ) )
#	{
#		$repository->log( "Failed to invoke sendmail: ".
#			$repository->invocation( "sendmail" ) );
#		return( 0 );
#	}

	# Addresses should be 7bit clean, but I'm not checking yet.
	# god only knows what 8bit data does in an email address.

	#cjg should be in the top of the file.
	my $MAILWIDTH = 80;
	my $arcname_q = mime_encode_q( EPrints::Session::best_language( 
		$repository,
		$langid,
		%{$repository->get_conf( "archivename" )} ) );

	my $name_q = mime_encode_q( $name );
	my $subject_q = mime_encode_q( $subject );
	my $adminemail = $repository->get_conf( "adminemail" );

	my $utf8body 	= EPrints::Utils::tree_to_utf8( $body , $MAILWIDTH );
	my $utf8sig	= EPrints::Utils::tree_to_utf8( $sig , $MAILWIDTH );
	my $utf8all	= $utf8body.$utf8sig;
	my $type	= get_encoding($utf8all);
	my $date	= email_date();
	my $content_type_q = 'text/plain; charset="'.$type.'"';
	my $msg = $utf8all;
	if ($type eq "iso-8859-1")
	{
		$msg = $utf8all->latin1; 
	}

	$smtp->mail( $adminemail );
	$smtp->to( $address );
	$smtp->data();

	my $mailheader = <<END;
From: "$arcname_q" <$adminemail>
To: "$name_q" <$address>
Subject: $arcname_q: $subject_q
Date: $date
Precedence: bulk
Content-Type: $content_type_q
Content-Transfer-Encoding: 8bit
END
	if( defined $replyto )
	{
		my $replytoname_q = mime_encode_q( $replytoname );
		$mailheader.= "Reply-To: \"$replytoname_q\" <$replyto>\n";
	}

	# de Unicode::String the strings!
	$smtp->datasend( "$mailheader" );  
	$smtp->datasend( "\n" );
	$smtp->datasend( "$msg" );  
	$smtp->dataend();
	$smtp->quit;

	return( 1 );
}

######################################################################
=pod

=item EPrints::Utils::send_mail_via_sendmail( $repository, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname )

Also should not be called directly. The config. option "send_email"
can be set to \&EPrints::Utils::send_mail_via_sendmail to use the
sendmail command to send emails rather than send to a SMTP server.

=cut
######################################################################

sub send_mail_via_sendmail
{
	my( $repository, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname ) = @_;
	#   repository   string   utf8   utf8      utf8      DOM    DOM   string    utf8
	unless( open( SENDMAIL, "|".$repository->invocation( "sendmail" ) ) )
	{
		$repository->log( "Failed to invoke sendmail: ".
			$repository->invocation( "sendmail" ) );
		return( 0 );
	}

	# Addresses should be 7bit clean, but I'm not checking yet.
	# god only knows what 8bit data does in an email address.

	#cjg should be in the top of the file.
	my $MAILWIDTH = 80;
	my $arcname_q = mime_encode_q( EPrints::Session::best_language( 
		$repository,
		$langid,
		%{$repository->get_conf( "archivename" )} ) );

	my $name_q = mime_encode_q( $name );
	my $subject_q = mime_encode_q( $subject );
	my $adminemail = $repository->get_conf( "adminemail" );

	my $utf8body 	= EPrints::Utils::tree_to_utf8( $body , $MAILWIDTH );
	my $utf8sig	= EPrints::Utils::tree_to_utf8( $sig , $MAILWIDTH );
	my $utf8all	= $utf8body.$utf8sig;
	my $type	= get_encoding($utf8all);
	my $date	= email_date();
	my $content_type_q = 'text/plain; charset="'.$type.'"';
	my $msg = $utf8all;
	if ($type eq "iso-8859-1")
	{
		$msg = $utf8all->latin1; 
	}
	#precedence bulk to avoid automail replies?  cjg
	my $mailheader = "";
	if( defined $replyto )
	{
		my $replytoname_q = mime_encode_q( $replytoname );
		$mailheader.= <<END;
Reply-To: "$replytoname_q" <$replyto>
END
	}
	$mailheader.= <<END;
From: "$arcname_q" <$adminemail>
To: "$name_q" <$address>
Subject: $arcname_q: $subject_q
Date: $date
Precedence: bulk
Content-Type: $content_type_q
Content-Transfer-Encoding: 8bit
END

	print SENDMAIL $mailheader;
	print SENDMAIL "\n";
	print SENDMAIL $msg;
	close(SENDMAIL) or return( 0 );
	return( 1 );
}


######################################################################
=pod

=item $enc = EPrints::Utils::get_encoding( $string )

Return the best guess of the encoding of the given string. Results
one of: 7-bit, utf-8, iso-8859-1, unknown. Used for sending email.

=cut
######################################################################

sub get_encoding
{
	my( $string ) = @_;

	return "7-bit" if (length($string) == 0);

	my $svnbit = 1;
	my $latin1 = 1;
	my $utf8   = 0;

	foreach($string->unpack())
	{
		$svnbit &= !($_ > 0x79);	
		$latin1 &= !($_ > 0xFF);
		if ($_ > 0xFF)
		{
			$utf8 = 1;	
			last;
		} 
	}
	return "7-bit" if $svnbit;
	return "utf-8" if $utf8;
	return "iso-8859-1" if $latin1;
	return "unknown";
}


######################################################################
=pod

=item $header = EPrints::Utils::mime_encode_q( $string )

Encode a utf-8 string as a mime header.

=cut
######################################################################

sub mime_encode_q
{
	my( $string ) = @_;
	
	my $stringobj = Unicode::String->new();
	$stringobj->utf8( $string );	

	my $encoding = get_encoding($stringobj);

	return $stringobj
		if( $encoding eq "7-bit" );

	return $stringobj
		if( $encoding ne "utf-8" && $encoding ne "iso-8859-1" );

	my @words = split( " ", $stringobj->utf8 );

	foreach( @words )
	{
		my $wordobj = Unicode::String->new();
		$wordobj->utf8( $_ );	
		# don't do words which are 7bit clean
		next if( get_encoding($wordobj) eq "7-bit" );

		my $estr = ( $encoding eq "iso-8859-1" ?
		             $wordobj->latin1 :
			     $wordobj );
		
		$_ = "=?".$encoding."?Q?".encode_str($estr)."?=";
	}

	return join( " ", @words );
}



######################################################################
=pod

=item $encoded = EPrints::Utils::encode_str( $string )

Used by mime_encode_q to escape non legal values in the string.

=cut
######################################################################

sub encode_str
{
	my( $string ) = @_;
	my $encoded = "";
        my $i;
        for $i (0..length($string)-1)
        {
                my $o = ord(substr($string,$i,1));
                # less than space, higher or equal than 'DEL' or _ or ?
                if( $o < 0x20 || $o > 0x7E || $o == 0x5F || $o == 0x3F )
                {
                        $encoded.=sprintf( "=%02X", $o );
                }
                else
                {
                        $encoded.=chr($o);
                }
        }
	return $encoded;
}


######################################################################
=pod

=item $boolean = EPrints::Utils::is_set( $r )

Recursive function. 

Return false if $r is not set.

If $r is a scalar then returns true if it is not an empty string.

For arrays and hashes return true if at least one value of them
is_set().

This is used to see if a complex data structure actually has any data
in it.

=cut
######################################################################

sub is_set
{
	my( $r ) = @_;

	return 0 if( !defined $r );
		
	if( ref($r) eq "" )
	{
		return ($r ne "");
	}
	if( ref($r) eq "ARRAY" )
	{
		foreach( @$r )
		{
			return( 1 ) if( is_set( $_ ) );
		}
		return( 0 );
	}
	if( ref($r) eq "HASH" )
	{
		foreach( keys %$r )
		{
			return( 1 ) if( is_set( $r->{$_} ) );
		}
		return( 0 );
	}
	# Hmm not a scalar, or a hash or array ref.
	# Lets assume it's set. (it is probably a blessed thing)
	return( 1 );
}

# widths smaller than about 3 may totally break, but that's
# a stupid thing to do, anyway.

######################################################################
=pod

=item $string = EPrints::Utils::tree_to_utf8( $tree, $width, [$pre], [$whitespace_before] )

Convert a XML DOM tree to a utf-8 encoded string.

If $width is set then word-wrap at that many characters.

XHTML elements are removed with the following exceptions:

<br /> is converted to a newline.

<p>...</p> will have a blank line above and below.

<img /> will be replaced with the content of the alt attribute.

<hr /> will, if a width was specified, insert a line of dashes.

=cut
######################################################################

sub tree_to_utf8
{
        my( $node, $width, $pre, $whitespace_before ) = @_;

	$whitespace_before = 0 unless defined $whitespace_before;

	unless( EPrints::XML::is_dom( $node ) )
	{
		print STDERR "Oops. tree_to_utf8 got as a node: $node\n";
	}
	if( EPrints::XML::is_dom( $node, "NodeList" ) )
	{
		# Hmm, a node list, not a node.
        	my $string = utf8("");
		my $ws = $whitespace_before;
        	for( my $i=0 ; $i<$node->getLength ; ++$i )
        	{
                	$string .= tree_to_utf8( 
				$node->index( $i ), 
				$width,
 				$pre,
				$ws );
			$ws = _blank_lines( $ws, $string );
		}
		return $string;
	}

        if( defined $width )
        {
                # If we are supposed to be doing an 80 character wide display
                # then only do 78, so the last char does not force a line break.                
		$width = $width - 2;
        }

	
	if( EPrints::XML::is_dom( $node, "Text" ) ||
	    EPrints::XML::is_dom( $node, "CDataSection" ) )
        {
        	my $v = $node->getNodeValue();
                $v =~ s/[\s\r\n\t]+/ /g unless( $pre );
                return $v;
        }

        my $name = $node->getNodeName();

        my $string = utf8("");
	my $ws = $whitespace_before;
        foreach( $node->getChildNodes )
        {
                $string .= tree_to_utf8( 
			$_,
			$width, 
			( $pre || $name eq "pre" || $name eq "mail" ),
			$ws );
		$ws = _blank_lines( $ws, $string );
        }

        if( $name eq "fallback" )
        {
                $string = "*".$string."*";
        }

        # <hr /> only makes sense if we are generating a known width.
        if( $name eq "hr" && defined $width )
        {
                $string = latin1("\n"."-"x$width."\n");
        }

        # Handle wrapping block elements if a width was set.
        if( ( $name eq "p" || $name eq "mail" ) && defined $width)
        {
                my @chars = $string->unpack;
                my @donechars = ();
                my $i;
                while( scalar @chars > 0 )
                {
                        # remove whitespace at the start of a line
                        if( $chars[0] == 32 )
                        {
                                splice( @chars, 0, 1 );
                                next;
                        }

                        # no whitespace at start, so look for first line break
                        $i=0;
                        while( $i<$width && defined $chars[$i] && $chars[$i] !=
10 ) { ++$i; }
                        if( defined $chars[$i] && $chars[$i] == 10 )
                        {
                                push @donechars, splice( @chars, 0, $i+1 );
                                next;
                        }

                        # no line breaks, so if remaining text is smaller
                        # than the width then just add it to the end and
                        # we're done.
                        if( scalar @chars < $width )
                        {
                                push @donechars,@chars;
                                last;
                        }

                        # no line break, more than $width chars.
                        # so look for the last whitespace within $width
                        $i=$width-1;
                        while( $i>=0 && $chars[$i] != 32 ) { --$i; }
                        if( defined $chars[$i] && $chars[$i] == 32 )
                        {
                                # up to BUT NOT INCLUDING the whitespace
                                my @line = splice( @chars, 0, $i );
# This code makes the output "flush" by inserting extra spaces where
# there is currently one. Is that what we want? cjg
#my $j=0;
#while( scalar @line < $width )
#{
#       if( $line[$j] == 32 )
#       {
#               splice(@line,$j,0,-1);
#               ++$j;
#       }
#       ++$j;
#       $j=0 if( $j >= scalar @line );
#}
#foreach(@line) { $_ = 32 if $_ == -1; }
                                push @donechars, @line;

                                # just consume the whitespace
                                splice( @chars, 0, 1);
                                # and a CR...
                                push @donechars,10;
                                next;
                        }

                        # No CR's, no whitespace, just split on width then.
                        push @donechars,splice(@chars,0,$width);

                        # Not the end of the block, so add a \n
                        push @donechars,10;
                }
                $string->pack( @donechars );
        }
	$ws = $whitespace_before;
        if( $name eq "p" )
        {
		while( $ws < 2 ) { $string="\n".$string; ++$ws; }
        }
	$ws = _blank_lines( $whitespace_before, $string );
        if( $name eq "p" )
        {
		while( $ws < 1 ) { $string.="\n"; ++$ws; }
        }
        if( $name eq "br" )
        {
		while( $ws < 1 ) { $string.="\n"; ++$ws; }
        }
        if( $name eq "img" )
        {
		my $alt = $node->getAttribute( "alt" );
		$string = $alt if( defined $alt );
        }
        return $string;
}

sub _blank_lines
{
	my( $n, $str ) = @_;

	$str = "\n"x$n . $str;
	$str =~ s/\[[^\]]*\]//sg;
	$str =~ s/[ 	\r]+//sg;
	my $ws;
	for( $ws = 0; substr( $str, (length $str) - 1 - $ws, 1 ) eq "\n"; ++$ws ) {;}

	return $ws;
}


######################################################################
=pod

=item $ok = EPrints::Utils::mkdir( $full_path )

Create the specified directory.

Return true on success.

=cut
######################################################################

sub mkdir
{
	my( $full_path ) = @_;

	# Make sure $dir is a plain old string (not unicode) as
	# Unicode::String borks mkdir
	$full_path = "$full_path";


	my @created = eval
        {
                return mkpath( $full_path, 0, 0775 );
        };
	if( defined $@ && $@ ne "" ) { warn $@; }
        return ( scalar @created > 0 )
}


######################################################################
=pod

=item $xhtml = EPrints::Utils::render_citation( $obj, $cstyle, [$url] )

Render the given object (EPrint, User, etc) using the citation style
$cstyle. If $url is specified then the <ep:linkhere> element will be
replaced with a link to that URL.

=cut
######################################################################

sub render_citation
{
	my( $obj, $cstyle, $url ) = @_;

	# This should belong to the base class of EPrint User Subject and
	# Subscription, if we were better OO people...

	my $session = $obj->get_session;

	my $collapsed = collapse_conditions( $session, $cstyle, $obj );

	my $r= _render_citation_aux( $obj, $session, $collapsed, $url );

	return $r;
}

######################################################################
=pod

=item $xml = EPrints::Utils::collapse_conditions( $session, $xml, $object, [%params] )

Using the given object and %params, collapse the <ep:ifset>,
<ep:ifnotset>, <ep:ifmatch> and <ep:ifnotmatch>
elements in XML and return the result.

The name attribute in ifset etc. refer to the field name in $object,
unless the are prefixed with a asterisk (*) in which case they are keys
to values in %params.

=cut
######################################################################

sub collapse_conditions
{
	my( $session, $node, $obj, %params ) = @_;

# cjg - Potential bug if: <ifset a><ifset b></></> and ifset a is disposed
# then ifset: b is processed it will crash.

	my $addkids = $node->hasChildNodes;
	my $collapsed;

	if( EPrints::XML::is_dom( $node, "Element" ) )
	{

		my $name = $node->getTagName;
		$name =~ s/^ep://;

		my $fieldname = $node->getAttribute( "name" );
		if( $name =~ s/^\*// )
		{
			if( $name eq "ifset" )
			{
				$collapsed = $session->make_doc_fragment;
				$addkids = defined $params{$fieldname};
			}
			elsif( $name eq "ifnotset" )
			{
				$collapsed = $session->make_doc_fragment;
				$addkids = !defined $params{$fieldname};
			}
			elsif( $name eq "ifmatch" || $name eq "ifnotmatch" )
			{
				my $value = $node->getAttribute( "value" );
				$addkids = 0;
				foreach( split( /\s+/,$value ) )
				{
					$addkids = 1 if( $_ eq $params{$fieldname} );
				}

				if( $name eq "ifnotmatch" )
				{
					$addkids = !$addkids;
				}

				$collapsed = $session->make_doc_fragment;
			}
		}
		else
		{
			if( $name eq "ifset" )
			{
				$collapsed = $session->make_doc_fragment;
				$addkids = $obj->is_set( $fieldname );
			}
			elsif( $name eq "ifnotset" )
			{
				$collapsed = $session->make_doc_fragment;
				$addkids = !$obj->is_set( $fieldname );
			}
			elsif( $name eq "ifmatch" || $name eq "ifnotmatch" )
			{
				my $dataset = $obj->get_dataset;
	
				my $merge = $node->getAttribute( "merge" );
				my $value = $node->getAttribute( "value" );
				my $match = $node->getAttribute( "match" );
	
				my @multiple_names = split /\//, $fieldname;
				my @multiple_fields;
				
				# Put the MetaFields in a list
				foreach (@multiple_names)
				{
					push @multiple_fields, EPrints::Utils::field_from_config_string( $dataset, $_ );
				}
		
				my $sf = EPrints::Search::Field->new( 
					$session, 
					$dataset, 
					\@multiple_fields,
					$value,	
					$match,
					$merge );
	
				$addkids = $sf->get_conditions->item_matches( $obj );
	
				if( $name eq "ifnotmatch" )
				{
					$addkids = !$addkids;
				}

				$collapsed = $session->make_doc_fragment;
			}
		}
	}

	if( !defined $collapsed )
	{
		$collapsed = $session->clone_for_me( $node );
	}

	if( $addkids )
	{
		foreach my $child ( $node->getChildNodes )
		{
			$collapsed->appendChild(
				collapse_conditions( 
					$session,
					$child,
					$obj,
					%params ) );			
		}
	}

	return $collapsed;
}

sub _render_citation_aux
{
	my( $obj, $session, $node, $url ) = @_;
	my $rendered;

	if( EPrints::XML::is_dom( $node, "Text" ) ||
	    EPrints::XML::is_dom( $node, "CDataSection" ) )
	{
		my $rendered = $session->make_doc_fragment;
		my $v = $node->getData;
		my $inside = 0;
		foreach( split( '@' , $v ) )
		{
			if( $inside )
			{
				$inside = 0;
				unless( EPrints::Utils::is_set( $_ ) )
				{
					$rendered->appendChild( 
						$session->make_text( '@' ) );
					next;
				}
                                my $field = EPrints::Utils::field_from_config_string( 
					$obj->get_dataset(), 
					$_ );
				$rendered->appendChild( _citation_field_value( $obj, $field ) );
				next;
			}

			$rendered->appendChild( 
				$session->make_text( $_ ) );
			$inside = 1;
		}
		return $rendered;
	}

	if( EPrints::XML::is_dom( $node, "EntityReference" ) )
	{
		# old style. Deprecated.

		my $fname = $node->getNodeName;
		my $field = $obj->get_dataset()->get_field( $fname );

		return _citation_field_value( $obj, $field );
	}

	my $addkids = $node->hasChildNodes;

	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->getTagName;
		$name =~ s/^ep://;

		if( $name eq "iflink" )
		{
			$rendered = $session->make_doc_fragment;
			$addkids = defined $url;
		}
		elsif( $name eq "ifnotlink" )
		{
			$rendered = $session->make_doc_fragment;
			$addkids = !defined $url;
		}
		elsif( $name eq "linkhere" )
		{
			if( defined $url )
			{
				$rendered = $session->make_element( 
					"a",
					href=>EPrints::Utils::url_escape( 
						$url ) );
			}
			else
			{
				$rendered = $session->make_doc_fragment;
			}
		}
	}

	if( !defined $rendered )
	{
		$rendered = $session->clone_for_me( $node );
	}

	# icky code to spot @title@ in node attributes and replace it.
	my $attrs = $rendered->getAttributes;
	if( $attrs )
	{
		for my $i ( 0..$attrs->getLength-1 )
		{
			my $attr = $attrs->item( $i );
			my $v = $attr->getValue;
			$v =~ s/@([a-z0-9_]+)@/$obj->get_value( $1 )/egi;
			$v =~ s/@@/@/gi;
			$attr->setValue( $v );
		}
	}

	if( $addkids )
	{
		foreach my $child ( $node->getChildNodes )
		{
			$rendered->appendChild(
				_render_citation_aux( 
					$obj,
					$session,
					$child,
					$url ) );			
		}
	}
	return $rendered;
}

sub _citation_field_value
{
	my( $obj, $field ) = @_;

	my $session = $obj->get_session;
	my $fname = $field->get_name;
	my $span = $session->make_element( "span", class=>"field_".$fname );
	my $value = $obj->get_value( $fname );
	$span->appendChild( $field->render_value( 
				$session,
				$value,
				0,
 				1 ) );

	return $span;
}




######################################################################
=pod

=item $metafield = EPrints::Utils::field_from_config_string( $dataset, $fieldname )

Return the EPrint::MetaField from $dataset with the given name.

If fieldname ends in ".id" then return a metafield representing the
ID part only.

If fieldname has a semicolon followed by render options then these
are passed as render_opts to the new EPrints::MetaField object.

=cut
######################################################################

sub field_from_config_string
{
	my( $dataset, $fieldname ) = @_;

	my $modifiers = 0;

	my %q = ();
	if( $fieldname =~ s/^([^;\.]*)(\.id)?(;(.*))?$/$1/ )
	{
		if( defined $4 )
		{
			foreach( split( /;/, $4 ) )
			{
				$q{$_}=1;
				$modifiers = 1;
			}
		}
		if( defined $2 ) 
		{ 
			$q{id} = 1; 
			$modifiers = 1;
		}
	}

	my $field;
	if( $fieldname eq $EPrints::Utils::FULLTEXT )
	{
		$field = new EPrints::MetaField(
				dataset=>$dataset,
				multiple=>1,
				name=>$EPrints::Utils::FULLTEXT,
				type=>"fulltext" );
	}
	else
	{
		$field = $dataset->get_field( $fieldname );
	}

	if( !defined $field )
	{
		EPrints::Config::abort( "Can't make field from config_string: $fieldname" );
	}

	if( $field->get_property( "hasid" ) )
	{
		if( $q{id} )
		{
			$field = $field->get_id_field();
		}
		else
		{
			$field = $field->get_main_field();
		
		}
	}

	unless( $modifiers ) { return $field; }

	$field = $field->clone;

	my $opts = {};
	foreach( keys %q )
	{
		my( $k, $v ) = split( /=/, $_ );
		$v = 1 unless defined $v;
		$opts->{$k} = $v;
	}

	$field->set_property( "render_opts", $opts );
	
	return $field;
}

######################################################################
=pod

=item $string = EPrints::Utils::get_input( $regexp, [$prompt], [$default] )

Read input from the keyboard.

Prints the prompt and default value, if any. eg.
 How many fish [5] >

Return the value the user enters at the keyboard.

If the value does not match the regexp then print the prompt again
and try again.

If a default is set and the user just hits return then the default
value is returned.

=cut
######################################################################

sub get_input
{
	my( $regexp, $prompt, $default ) = @_;

	$prompt = "" if( !defined $prompt);
	for(;;)
	{
		print $prompt;
		if( defined $default )
		{
			print " [$default] ";
		}
		print "? ";
		my $in = <STDIN>;
		chomp $in;
		if( $in eq "" && defined $default )
		{
			return $default;
		}
		if( $in=~m/^$regexp$/ )
		{
			return $in;
		}
		else
		{
			print "Bad Input, try again.\n";
		}
	}
}

######################################################################
=pod

=item EPrints::Utils::get_input_hidden( $regexp, [$prompt], [$default] )

Get input from the console without echoing the entered characters 
(mostly useful for getting passwords). Uses L<Term::ReadKey>.

Identical to get_input except the characters don't appear.

=cut
######################################################################

sub get_input_hidden
{
	my( $regexp, $prompt, $default ) = @_;

	$prompt = "" if( !defined $prompt);
	for(;;)
	{
		print $prompt;
		if( defined $default )
		{
			print " [$default] ";
		}
		print "? ";
		ReadMode('noecho');
		my $in = ReadLine( 0 );
		ReadMode('normal');
		chomp $in;
		if( $in eq "" && defined $default )
		{
			print "\n";
			return $default;
		}
		if( $in=~m/^$regexp$/ )
		{
			print "\n";
			return $in;
		}
		else
		{
			print "Bad Input, try again.\n";
		}
	}

}

######################################################################
=pod

=item $clone_of_data = EPrints::Utils::clone( $data )

Deep copies the data structure $data, following arrays and hashes.

Does not handle blessed items.

Useful when we want to modify a temporary copy of a data structure 
that came from the configuration files.

=cut
######################################################################

sub clone
{
	my( $data ) = @_;

	if( ref($data) eq "" )
	{
		return $data;
	}
	if( ref($data) eq "ARRAY" )
	{
		my $r = [];
		foreach( @{$data} )
		{
			push @{$r}, clone( $_ );
		}
		return $r;
	}
	if( ref($data) eq "HASH" )
	{
		my $r = {};
		foreach( keys %{$data} )
		{
			$r->{$_} = clone( $data->{$_} );
		}
		return $r;
	}


	# dunno
	return $data;			
}


######################################################################
=pod

=item $crypted_value = EPrints::Utils::crypt_password( $value, $session )

Apply the crypt encoding to the given $value.

=cut
######################################################################

sub crypt_password
{
	my( $value, $session ) = @_;

	return unless EPrints::Utils::is_set( $value );

	my @saltset = ('a'..'z', 'A'..'Z', '0'..'9', '.', '/');
	my $salt = $saltset[time % 64] . $saltset[(time/64)%64];
	my $cryptpass = crypt($value ,$salt);

	return $cryptpass;
}

# Escape everything AFTER the last /

######################################################################
=pod

=item $string = EPrints::Utils::url_escape( $url )

Escape the given $url, so that it can appear safely in HTML.

=cut
######################################################################

sub url_escape
{
	my( $url ) = @_;

	my $uri = URI->new( $url );
	return $uri->as_string;
}

######################################################################
=pod

=item $long = EPrints::Utils::ip2long( $ip )

Convert quad-dotted notation to long

=item $ip = EPrints::Utils::long2ip( $ip )

Convert long to quad-dotted notation

=cut
######################################################################

sub ip2long
{
	my( $ip ) = @_;
	my $long = 0;
	foreach my $octet (split(/\./, $ip)) {
		$long <<= 8;
		$long |= $octet;
	}
	return $long;
}

sub long2ip
{
	my( $long ) = @_;
	my @octets;
	for(my $i = 3; $i >= 0; $i--) {
		$octets[$i] = ($long & 0xFF);
		$long >>= 8;
	}
	return join('.', @octets);
}

######################################################################
=pod

=item EPrints::Utils::cmd_version( $progname )

Print out a "--version" style message to STDOUT.

$progname is the name of the current script.

=cut
######################################################################

sub cmd_version
{
	my( $progname ) = @_;

	my $version_id = $EPrints::SystemSettings::conf->{version_id};
	my $version = $EPrints::SystemSettings::conf->{version};
	
	print <<END;
$progname (GNU EPrints $version_id)
$version

Copyright (C) 2001-2006 University of Southampton

__LICENSE__
END
	exit;
}

# This code is for debugging memory leaks in objects.
# It is not used by EPrints except when developing. 
#
# 
# my %OBJARRAY = ();
# my %OBJSCORE = ();
# my %OBJPOS = ();
# my %OBJPOSR = ();
# my $c = 0;


######################################################################
#
# EPrints::Utils::destroy( $ref )
#
######################################################################

sub destroy
{
	my( $ref ) = @_;
#
#	my $class = delete $OBJARRAY{"$ref"};
#	my $n = delete $OBJPOS{"$ref"};
#	delete $OBJPOSR{$n};
#	
#	$OBJSCORE{$class}--;
#	print "Kill: $ref ($class) [$OBJSCORE{$class}]\n";

}

#my %OBJOLDSCORE = ();
#use Data::Dumper;
#sub debug
#{
#	my @k = sort {$b<=>$a} keys %OBJPOSR;
#	for(0..9)
#	{
#		print "=========================================\n";
#		print $OBJPOSR{$k[$_]}."\n";
#	}
#	foreach( keys %OBJSCORE ) { 
#		my $diff = $OBJSCORE{$_}-$OBJOLDSCORE{$_};
#		if( $diff > 0 ) { $diff ="+$diff"; }
#		print "$_ $OBJSCORE{$_}   $diff\n"; 
#		$OBJOLDSCORE{$_} = $OBJSCORE{$_};
#	}
#}
#
#sub bless
#{
#	my( $ref, $class ) = @_;
#
#	CORE::bless $ref, $class;
#
#	$OBJSCORE{$class}++;
#	print "Make: $ref ($class) [$OBJSCORE{$class}]\n";
#	$OBJARRAY{"$ref"}=$class;
#	$OBJPOS{"$ref"} = $c;
#	#my $x = $ref;
#	$OBJPOSR{$c} = "$c - $ref\n";
#	my $i=1;
#	my @info;
#	while( @info = caller($i++) )
#	{
#		$OBJPOSR{$c}.="$info[3] $info[2]\n";
#	}
#
#
#	if( ref( $ref ) =~ /XML::DOM/  )
#	{// to_string
#		#$OBJPOSR{$c}.= $ref->toString."\n";
#	}
#	++$c;
#
#	return $ref;
#}



######################################################################
=pod

=item ($year,$month,$day,$hour,$min,$sec) = EPrints::Utils::get_date( $time )

Static method that returns the given time (in UNIX time, seconds 
since 1.1.79) in an array.

=cut
######################################################################

sub get_date
{
	my( $time ) = @_;

	my @date = localtime( $time );
	my $day = $date[3];
	my $month = $date[4]+1;
	my $year = $date[5]+1900;
	my $sec = $date[0];
	my $min = $date[1];
	my $hour = $date[2];
	
	# Ensure number of digits
	while( length $day < 2 ) { $day = "0".$day; }

	while( length $month < 2 ) { $month = "0".$month; }

	while( length $hour < 2 ) { $hour = "0".$hour; }

	while( length $min < 2 ) { $min = "0".$min; }

	while( length $sec < 2 ) { $sec = "0".$sec; }

	return( $year, $month, $day, $hour, $min, $sec );
}



######################################################################
=pod

=item  $datestamp = EPrints::Utils::get_datestamp( $time )

Method that returns the given time (in UNIX time, seconds 
since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).

=cut
######################################################################

sub get_datestamp
{
	my( $time ) = @_;

	my( $year, $month, $day ) = EPrints::Utils::get_date( $time );

	return( $year."-".$month."-".$day );
}

######################################################################
=pod

=item  $datetimestamp = EPrints::Utils::get_datetimestamp( $time )

Method that returns the given time (in UNIX time, seconds 
since 1.1.79) in the datetime format used by EPrints and MySQL
YYYY-MM-DD HH:MM:SS

Does not zero pad.

=cut
######################################################################

sub get_datetimestamp
{
	my( $time ) = @_;

	my( $year, $month, $day, $hour, $min, $sec ) = EPrints::Utils::get_date( $time );

	return( "$year-$month-$day $hour:$min:$sec" );
}

######################################################################
=pod

=item $timestamp = EPrints::Utils::get_timestamp()

Return a string discribing the current local date and time.

=cut
######################################################################

sub get_timestamp
{
	my $stamp = "Error in get_timestamp";
	eval {
		use POSIX qw(strftime);
		$stamp = strftime( "%a %b %e %H:%M:%S %Z %Y", localtime);
	};	
	return $stamp;
}

######################################################################
=pod

=item $timestamp = EPrints::Utils::get_UTC_timestamp()

Return a string discribing the current local date and time. 
In UTC Format. eg:

 1957-03-20T20:30:00Z

This the UTC time, not the localtime.

=cut
######################################################################

sub get_UTC_timestamp
{
	my $stamp = "Error in get_UTC_timestamp";
	eval {
		use POSIX qw(strftime);
		$stamp = strftime( "%Y-%m-%dT%H:%M:%SZ", gmtime);
	};

	return $stamp;
}


######################################################################
=pod

=item $esc_string = EPrints::Utils::escape_filename( $string )

Take a value and escape it to be a legal filename to go in the /view/
section of the site.

=cut
######################################################################

sub escape_filename
{
	my( $fileid ) = @_;

	return "NULL" if( $fileid eq "" );

	$fileid = utf8( $fileid );

	my $stringobj = Unicode::String->new();
	$stringobj->utf8( $fileid );

	my $hc = [ 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70 ];
	
	my @in = $stringobj->unpack;
	my @out = ();
	foreach( @in )
	{
		if( $_ < 33 ) { push @out, 95; next; }
		if( $_ >=48 && $_ <= 57 ) { push @out, $_; next; }
		if( $_ >=65 && $_ <= 90 ) { push @out, $_; next; }
		if( $_ >=97 && $_ <= 122 ) { push @out, $_; next; }
		if( $_ == 44 || $_ == 45 || $_ == 46 || $_ == 58 || $_ == 95 ) { push @out, $_; next; }
		if( $_ < 256 )
		{
			push @out, 61;
			push @out, $hc->[($_ / 16 )%16];
			push @out, $hc->[$_%16];
			next;
		}
		push @out, 61;
		push @out, 61;
		push @out, $hc->[($_ / 0x1000 )%16];
		push @out, $hc->[($_ / 0x100 )%16];
		push @out, $hc->[($_ / 0x10 )%16];
		push @out, $hc->[$_%16];
		
	}
	
	$stringobj->pack( @out );

        return $stringobj;
}

######################################################################
=pod

=item $filesize_text = EPrints::Utils::human_filesize( $size_in_bytes )

Return a human readable version of a filesize. If 0-4095b then show 
as bytes, if 4-4095Kb show as Kb otherwise show as Mb.

eg. Input of 5234 gives "5Kb", input of 3234 gives "3234b".

This is not internationalised, I don't think it needs to be. Let me
know if this is a problem. support@eprints.org

=cut
######################################################################

sub human_filesize
{
	my( $size_in_bytes ) = @_;

	if( $size_in_bytes < 4096 )
	{
		return $size_in_bytes.'b';
	}

	my $size_in_k = int( $size_in_bytes / 1024 );

	if( $size_in_k < 4096 )
	{
		return $size_in_k.'Kb';
	}

	my $size_in_meg = int( $size_in_k / 1024 );

	return $size_in_meg.'Mb';
}

######################################################################
# Redirect as this function has been moved.
######################################################################

sub render_xhtml_field
{
	return EPrints::Extras::render_xhtml_field( @_ );
}

1;

######################################################################
=pod

=back

=cut
