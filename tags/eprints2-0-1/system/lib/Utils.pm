######################################################################
#
#  EPrints Utility module
#
#   Provides various useful functions
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

package EPrints::Utils;
use strict;
use Filesys::DiskSpace;
use Unicode::String qw(utf8 latin1 utf16);
use File::Path;
use XML::DOM;
use URI;

my $DF_AVAILABLE;

BEGIN {

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
	$DF_AVAILABLE = detect_df();
	if (!$DF_AVAILABLE)
	{
		print STDERR <<END;
---------------------------------------------------------------------------
df appears to be unavailable on your server. To enable it, you should
run 'h2ph * */*' (as root) in your /usr/include directory. See the EPrints 
manual for more information.
---------------------------------------------------------------------------
END
	}
}


######################################################################
# $dirspace = df_dir( $dir );
#
#  Returns the amount of free space in directory $dir, or undef
#  if df could not be used.
# 
######################################################################

sub df_dir
{
	my( $dir ) = @_;

	return df $dir if ($DF_AVAILABLE);
	warn("df appears to be unavailable on your server. To enable it, you should run 'h2ph * */*' (as root) in your /usr/include directory. See the manual for more information.");	
}



sub render_date
{	
	my( $session, $datevalue ) = @_;

	if( !defined $datevalue )
	{
		return $session->html_phrase( "lib/utils:date_unspecified" );
	}

	my @elements = split /\-/, $datevalue;

	if( $elements[0]==0 )
	{
		return $session->html_phrase( "lib/utils:date_unspecified" );
	}

	if( $#elements != 2 || $elements[1] < 1 || $elements[1] > 12 )
	{
		return $session->html_phrase( "lib/utils:date_invalid" );
	}

	return $session->make_text( $elements[2]." ".EPrints::Utils::get_month_label( $session, $elements[1] )." ".$elements[0] );
}

sub get_month_label
{
	my( $session, $monthid ) = @_;

	my $code = sprintf( "lib/utils:month_%02d", $monthid );

	return $session->phrase( $code );
}


sub render_name
{
	my( $session, $name, $familylast ) = @_;

	my $firstbit;
	if( defined $name->{honourific} && $name->{honourific} ne "" )
	{
		$firstbit = $name->{honourific}." ".$name->{given};
	}
	else
	{
		$firstbit = $name->{given};
	}
	
	my $secondbit;
	if( defined $name->{lineage} && $name->{lineage} ne "" )
	{
		$secondbit = $name->{family}." ".$name->{lineage};
	}
	else
	{
		$secondbit = $name->{family};
	}
	
	if( $familylast )
	{
		return $session->make_text( $firstbit." ".$secondbit );
	}
	
	return $session->make_text( $secondbit.", ".$firstbit );
}

######################################################################
#
# ( $cmp ) = cmp_names( $val_a , $val_b )
#
#  This method compares (alphabetically) two arrays of names. Passed
#  by reference.
#
######################################################################


sub cmp_namelists
{
	my( $a , $b , $fieldname ) = @_;

	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	return _cmp_names_aux( $val_a, $val_b );
}

sub cmp_names
{
	my( $a , $b , $fieldname ) = @_;

	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	return _cmp_names_aux( [$val_a] , [$val_b] );
}

sub _cmp_names_aux
{
	my( $val_a, $val_b ) = @_;

	my( $texta , $textb ) = ( "" , "" );
	if( defined $val_a )
	{ 
		foreach( @{$a} ) { $texta.=":$_->{family},$_->{given},$_->{honourific},$_->{lineage}"; } 
	}
	if( defined $val_b )
	{ 
		foreach( @{$b} ) { $textb.=":$_->{family},$_->{given},$_->{honourific},$_->{lineage}"; } 
	}

	return( $texta cmp $textb );
}


sub cmp_ints
{
	my( $a , $b , $fieldname ) = @_;
	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	$val_a = 0 if( !defined $val_a );
	$val_b= 0 if( !defined $val_b);
	return $val_a <=> $val_b
}

sub cmp_strings
{
	my( $a , $b , $fieldname ) = @_;
	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	$val_a = "" if( !defined $val_a );
	$val_b= "" if( !defined $val_b);
	return $val_a cmp $val_b
}

sub cmp_dates
{
	my( $a , $b , $fieldname ) = @_;
	return cmp_strings( $a, $b, $fieldname );
}

# replyto / replytoname are optional (both or neither), they set
# the reply-to header.
sub send_mail
{
	my( $archive, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname ) = @_;
	#   Archive   string   utf8   utf8      utf8      DOM    DOM   string    utf8

	unless( open( SENDMAIL, "|".$archive->invocation( "sendmail" ) ) )
	{
		$archive->log( "Failed to invoke sendmail: ".
			$archive->invocation( "sendmail" ) );
		return( 0 );
	}

	# Addresses should be 7bit clean, but I'm not checking yet.
	# god only knows what 8bit data does in an email address.

	#cjg should be in the top of the file.
	my $MAILWIDTH = 80;
	my $arcname_q = mime_encode_q( EPrints::Session::best_language( 
		$archive,
		$langid,
		%{$archive->get_conf( "archivename" )} ) );

	my $name_q = mime_encode_q( $name );
	my $subject_q = mime_encode_q( $subject );
	my $adminemail = $archive->get_conf( "adminemail" );

	my $utf8body 	= EPrints::Utils::tree_to_utf8( $body , $MAILWIDTH );
	my $utf8sig	= EPrints::Utils::tree_to_utf8( $sig , $MAILWIDTH );
	my $utf8all	= $utf8body.$utf8sig;
	my $type	= get_encoding($utf8all);
	my $content_type_q = "text/plain";

	my $msg = $utf8all;
	if ($type eq "iso-latin-1")
	{
		$content_type_q = "text/plain; charset=iso-latin-1"; 
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
#
# $encoding = get_encoding($mystring)
# 
# Returns:
# "7-bit" if 7-bit clean
# "utf-8" if utf-8 encoded
# "iso-latin-1" if latin-1 encoded
# "unknown" if of unknown origin (shouldn't really happen)
#
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
	return "iso-latin-1" if $latin1;
	return "unknown";
}

# Encode a utf8 string for a MIME header.
sub mime_encode_q
{
	my( $string ) = @_;
	
	my $stringobj = Unicode::String->new();
	$stringobj->utf8( $string );	

	my $encoding = get_encoding($stringobj);

	return $stringobj
		if( $encoding eq "7-bit" );

	return $stringobj
		if( $encoding ne "utf-8" && $encoding ne "iso-latin-1" );

	my @words = split( " ", $stringobj->utf8 );

	foreach( @words )
	{
		my $wordobj = Unicode::String->new();
		$wordobj->utf8( $_ );	
		# don't do words which are 7bit clean
		next if( get_encoding($wordobj) eq "7-bit" );

		my $estr = ( $encoding eq "iso-latin-1" ?
		             $wordobj->latin1 :
			     $wordobj );
		
		$_ = "=?".$encoding."?Q?".encode_str($estr)."?=";
	}

	return join( " ", @words );
}


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

# ALL cjg get_value should use this.
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
sub tree_to_utf8
{
        my( $node, $width, $pre ) = @_;

	if( substr(ref($node) , 0, 8 ) ne "XML::DOM" )
	{
		print STDERR "Oops. tree_to_utf8 got as a node: $node\n";
	}

        if( defined $width )
        {
                # If we are supposed to be doing an 80 character wide display
                # then only do 78, so the last char does not force a line break.                
		$width = $width - 2;
        }

	if( $node->getNodeType == TEXT_NODE || $node->getNodeType == CDATA_SECTION_NODE )
        {
        	my $v = $node->getNodeValue();
                $v =~ s/[\s\r\n\t]+/ /g unless( $pre );
                return $v;
        }

        my $name = $node->getNodeName();

        my $string = utf8("");
        foreach( $node->getChildNodes )
        {
                $string .= tree_to_utf8( $_, $width, ( $pre || $name eq "pre" || $name eq "mail" )
);
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
        if( $name eq "p" )
        {
                $string = "\n".$string."\n";
        }
        if( $name eq "br" )
        {
                $string = "\n";
        }
        if( $name eq "img" )
        {
		my $alt = $node->getAttribute( "alt" );
		$string = $alt if( defined $alt );
        }
        return $string;
}

sub mkdir
{
	my( $full_path ) = @_;
	my @created = eval
        {
                return mkpath( $full_path, 0, 0775 );
        };
        return ( scalar @created > 0 )
}

# cjg - Potential bug if: <ifset a><ifset b></></> and ifset a is disposed
# then ifset: b is processed it will crash.

sub render_citation
{
	my( $obj, $cstyle, $url ) = @_;

	# This should belong to the base class of EPrint User Subject and
	# Subscription, if we were better OO people...

	# cjg BUG in nested <ifset>'s ?

	my $nodes = { keep=>[], lose=>[] };
	my $node;

	foreach $node ( $cstyle->getElementsByTagName( "ifset" , 1 ) )
	{
		my $fieldname = $node->getAttribute( "name" );
		my $val = $obj->get_value( $fieldname );
		push @{$nodes->{EPrints::Utils::is_set( $val )?"keep":"lose"}}, $node;
	}
	foreach $node ( $cstyle->getElementsByTagName( "ifnotset" , 1 ) )
	{
		my $fieldname = $node->getAttribute( "name" );
		my $val = $obj->get_value( $fieldname );
		push @{$nodes->{!EPrints::Utils::is_set( $val )?"keep":"lose"}}, $node;
	}
	foreach $node ( $cstyle->getElementsByTagName( "iflink" , 1 ) )
	{
		push @{$nodes->{defined $url?"keep":"lose"}}, $node;
	}
	foreach $node ( $cstyle->getElementsByTagName( "ifnotlink" , 1 ) )
	{
		push @{$nodes->{!defined $url?"keep":"lose"}}, $node;
	}
	foreach $node ( $cstyle->getElementsByTagName( "linkhere" , 1 ) )
	{
		if( !defined $url )
		{
			# keep the contents (but remove the node itself)
			push @{$nodes->{keep}}, $node;
			next;
		}

		# nb. setTagName is not really a proper
		# DOM command, but it's much quicker than
		# making a new <a> element and moving it 
		# all across.

		$node->setTagName( "a" );
		$node->setAttribute( "href", EPrints::Utils::url_escape( $url ) );
	}
	foreach $node ( @{$nodes->{keep}} )
	{
		my $sn; 
		foreach $sn ( $node->getChildNodes )
		{       
			$node->getParentNode->insertBefore( $sn, $node );
		}
		$node->getParentNode->removeChild( $node );
		$node->dispose();
	}
	foreach $node ( @{$nodes->{lose}} )
	{
		$node->getParentNode->removeChild( $node );
		$node->dispose();
	}

	_expand_references( $obj, $cstyle );

	return $cstyle;
}      

sub _expand_references
{
	my( $obj, $node ) = @_;

	foreach( $node->getChildNodes )
	{                
		if( $_->getNodeType == ENTITY_REFERENCE_NODE )
		{
			my $fname = $_->getNodeName;
			my $field = $obj->get_dataset()->get_field( $fname );
			my $fieldvalue = $field->render_value( 
						$obj->get_session(),
						$obj->get_value( $fname ),
						0,
 						1 );
			$node->replaceChild( $fieldvalue, $_ );
			$_->dispose();
		}
		else
		{
			_expand_references( $obj, $_ );
		}
	}
}

sub field_from_config_string
{
	my( $dataset, $fieldname ) = @_;

	my $useid = ( $fieldname=~s/\.id$// );
	# use id side of a field if the fieldname
	# ends in .id (and strip the .id)
	my $field = $dataset->get_field( $fieldname );
	if( !defined $field )
	{
		EPrints::Config::abort( "Can't make field from config_string: $fieldname" );
	}
	if( $field->get_property( "hasid" ) )
	{
		if( $useid )
		{
			$field = $field->get_id_field();
		}
		else
		{
			$field = $field->get_main_field();
		
		}
	}
	
	return $field;
}


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
sub url_escape
{
	my( $url ) = @_;

	my $uri = URI->new( $url );
	return $uri->as_string;
}



#
# This code is for debugging memory leaks in objects.
# It is not used by EPrints except when developing. 
#
# 
# my %OBJARRAY = ();
# my %OBJSCORE = ();
# my %OBJPOS = ();
# my %OBJPOSR = ();
# my $c = 0;

sub destroy
{

#	my( $ref ) = @_;
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
#	{
#		#$OBJPOSR{$c}.= $ref->toString."\n";
#	}
#	++$c;
#
#	return $ref;
#}


1;
