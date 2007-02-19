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
use File::Copy qw();
use Text::Wrap qw();
use MIME::Lite;
use LWP::MediaTypes qw( guess_media_type );
use URI;

use strict;

$EPrints::Utils::FULLTEXT = "_fulltext_";

my $DF_AVAILABLE;

BEGIN {
	eval "use Term::ReadKey";
	eval "use Compat::Term::ReadKey" if $@;

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

	#EPrints::abort "make_name_string expected hash reference" unless ref($name) eq "HASH";
	return "make_name_string expected hash reference" unless ref($name) eq "HASH";

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

=item $str = EPrints::Utils::wrap_text( $text, [$width], [$init_tab], [$sub_tab] )

Wrap $text to be at most $width (or 80 if undefined) characters per line. As a
special case $width may be C<console>, in which case the width used is the
current console width (L<Term::ReadKey>).

$init_tab and $sub_tab allow indenting on the first and subsequent lines
respectively (see L<Text::Wrap> for more information).

=cut
######################################################################

sub wrap_text
{
	my( $text, $width, $init_tab, $sub_tab ) = @_;

	$width ||= 80;
	if( $width eq 'console' )
	{
		($width) = Term::ReadKey::GetTerminalSize;
		$width ||= 80;
	}
	$width = 80 if $width < 1;
	$init_tab = "" if( !defined $init_tab );
	$sub_tab = "" if( !defined $sub_tab );

	local $Text::Wrap::columns = $width;
	local $Text::Wrap::huge = "overflow";

	return join "", Text::Wrap::fill( $init_tab, $sub_tab, $text );
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

=item $string = EPrints::Utils::tree_to_utf8( $tree, $width, [$pre], [$whitespace_before], [$ignore_a] )

Convert a XML DOM tree to a utf-8 encoded string.

If $width is set then word-wrap at that many characters.

XHTML elements are removed with the following exceptions:

<br /> is converted to a newline.

<p>...</p> will have a blank line above and below.

<img /> will be replaced with the content of the alt attribute.

<hr /> will, if a width was specified, insert a line of dashes.

<a href="foo">bar</a> will be converted into "bar <foo>" unless ignore_a is set.

=cut
######################################################################

sub tree_to_utf8
{
	my( $node, $width, $pre, $whitespace_before, $ignore_a ) = @_;

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
		for( my $i=0 ; $i<$node->length ; ++$i )
		{
			$string .= tree_to_utf8( 
					$node->item( $i ), 
					$width,
					$pre,
					$ws,
					$ignore_a );
			$ws = _blank_lines( $ws, $string );
		}
		return $string;
	}

	if( EPrints::XML::is_dom( $node, "Text" ) ||
		EPrints::XML::is_dom( $node, "CDataSection" ) )
	{
		my $v = $node->nodeValue();
		$v =~ s/[\s\r\n\t]+/ /g unless( $pre );
		return $v;
	}
	my $name = $node->nodeName();

	my $string = utf8("");
	my $ws = $whitespace_before;
	foreach( $node->getChildNodes )
	{
		$string .= tree_to_utf8( 
				$_,
				$width, 
				( $pre || $name eq "pre" || $name eq "mail" ),
				$ws,
				$ignore_a );
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
		$string = utf8( wrap_text( $string, $width ) );
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
	if( $name eq "a" && !$ignore_a)
	{
		my $href = $node->getAttribute( "href" );
		$string .= " <$href>" if( defined $href );
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

=item $ok = EPrints::Utils::copy( $source, $target )

Copy $source file to $target file without alteration.

Return true on success (sets $! on error).

=cut
######################################################################

sub copy
{
	my( $source, $target ) = @_;
	
	return File::Copy::copy( $source, $target );
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
	my( $full_path, $perms ) = @_;

	Carp::croak("EPrints::Utils::mkdir is deprecated: use EPrints::Platform::mkdir");

	# Default to "dir_perms"
	$perms = $EPrints::SystemSettings::conf->{"dir_perms"}
		if @_ < 2;

	# Make sure $dir is a plain old string (not unicode) as
	# Unicode::String borks mkdir

	my $dir="";
	my @parts = split( "/", "$full_path" );
	while( scalar @parts )
	{
		$dir .= "/".(shift @parts );
		if( !-d $dir )
		{
			my $ok = mkdir( $dir, $EPrints::SystemSettings::conf->{"dir_perms"} );
			if( !$ok )
			{
				print STDERR "Failed to mkdir $dir: $!\n";
				return 0;
			}
		}
	}		

	return 1;	
}


######################################################################
=pod

=item $ok = EPrints::Utils::rmtree( $full_path )

Unlinks the path and everything in it.

Return true on success.

=cut
######################################################################

sub rmtree
{
	my( $full_path ) = @_;

	$full_path = "$full_path";

	return 1 if( !-e $full_path );

	my $dh;
	if( !opendir( $dh, $full_path ) )
	{
		print STDERR "Failed to open dir $full_path: $!\n";
		return 0;
	}
	my @dir = ();
	while( my $fn = readdir( $dh ) )
	{
		next if $fn eq ".";
		next if $fn eq "..";
		my $file = "$full_path/$fn";
		if( -d $file )
		{
			push @dir, $file;	
			next;
		}
		
		if( !unlink( $file ) )
		{
			print STDERR "Failed to unlink $file: $!\n";
			return 0;
		}
	}
	closedir( $dh );

	foreach my $a_dir ( @dir )			
	{
		EPrints::Utils::rmtree( $a_dir );
	}
	
	if( !rmdir( $full_path ) )
	{
		print STDERR "Failed to rmdir $full_path: $!\n";
		return 0;
	}

	return 1;
}


######################################################################
#=pod
#
# =item $xhtml = EPrints::Utils::render_citation( $cstyle, %params );
#
# Render the given object (EPrint, User, etc) using the citation style
# $cstyle. If $url is specified then the <ep:linkhere> element will be
# replaced with a link to that URL.
#
# in=>.. describes where this came from in case it needs to report an
# error.
#
# session=> is required
#
# item => is required (the epobject being cited).
#
# url => is option if the item is to be linked.
#
#=cut
######################################################################

sub render_citation
{
	my( $cstyle, %params ) = @_;

	# This should belong to the base class of EPrint User Subject and
	# SavedSearch, if we were better OO people...

	my $collapsed = EPrints::XML::EPC::process( $cstyle, %params, in=>"render_citation" );
	my $r = _render_citation_aux( $collapsed, %params );

	EPrints::XML::trim_whitespace( $r );

	return $r;
}

sub _render_citation_aux
{
	my( $node, %params ) = @_;

	my $addkids = $node->hasChildNodes;

	my $rendered;
	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->tagName;
		$name =~ s/^ep://;
		$name =~ s/^cite://;

		if( $name eq "iflink" )
		{
			$rendered = $params{session}->make_doc_fragment;
			$addkids = defined $params{url};
		}
		elsif( $name eq "ifnotlink" )
		{
			$rendered = $params{session}->make_doc_fragment;
			$addkids = !defined $params{url};
		}
		elsif( $name eq "linkhere" )
		{
			if( defined $params{url} )
			{
				$rendered = $params{session}->make_element( 
					"a",
					target=>$params{target},
					href=>EPrints::Utils::url_escape( 
						$params{url} ) );
			}
			else
			{
				$rendered = $params{session}->make_doc_fragment;
			}
		}
	}

	if( !defined $rendered )
	{
		$rendered = $params{session}->clone_for_me( $node );
	}

	if( $addkids )
	{
		foreach my $child ( $node->getChildNodes )
		{
			$rendered->appendChild(
				_render_citation_aux( 
					$child,
					%params ) );			
		}
	}
	return $rendered;
}



######################################################################
=pod

=item $metafield = EPrints::Utils::field_from_config_string( $dataset, $fieldname )

Return the EPrint::MetaField from $dataset with the given name.

If fieldname ends in ".id" then return a metafield representing the
ID part only.

If fieldname has a semicolon followed by render options then these
are passed as render options to the new EPrints::MetaField object.

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

	my $field = $dataset->get_field( $fieldname );

	if( !defined $field )
	{
		EPrints::abort( "Can't make field from config_string: $fieldname" );
	}

	unless( $modifiers ) { return $field; }

	if( scalar keys %q )
	{
		$field = $field->clone;
	
		foreach( keys %q )
		{
			my( $k, $v ) = split( /=/, $_ );
			$v = 1 unless defined $v;
			$field->set_property( "render_$k", $v );
		}
	}
	
	return $field;
}

######################################################################
=pod

=item $string = EPrints::Utils::get_input( $regexp, [$prompt], [$default] )

Read input from the keyboard.

Prints the promp and default value, if any. eg.
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
	$prompt .= " [$default] " if( defined $default );
	$prompt .= "? ";
	for(;;)
	{
		print wrap_text( $prompt, 'console' );

		my $in = Term::ReadKey::ReadLine(0);
		$in =~ s/\015?\012?$//s;
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
	$prompt .= " [$default] " if( defined $default );
	$prompt .= "? ";
	for(;;)
	{
		print wrap_text( $prompt, 'console' );
		
		Term::ReadKey::ReadMode('noecho');
		my $in = Term::ReadKey::ReadLine( 0 );
		Term::ReadKey::ReadMode('normal');
		$in =~ s/\015?\012?$//s;
		print "\n";

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

=item EPrints::Utils::get_input_confirm( [$prompt], [$quick] )

Asks the user for confirmation (yes/no). If $quick is true only checks for a
single-character input ('y' or 'n').

Returns true if the user answers 'yes' or false for any other value.

=cut
######################################################################

sub get_input_confirm
{
	my( $prompt, $quick ) = @_;

	$prompt = "" if( !defined $prompt );

	if( $quick )
	{
		$prompt .= " [y/n] ? ";
		print wrap_text( $prompt, 'console' );

		my $in="";
		while( $in ne "y" && $in ne "n" )
		{
			Term::ReadKey::ReadMode( 'raw' );
			$in = lc(Term::ReadKey::ReadKey( 0 ));
			Term::ReadKey::ReadMode( 'normal' );
		}
		if( $in eq "y" ) { print wrap_text( "yes" ); }
		if( $in eq "n" ) { print wrap_text( "no" ); }
		print "\n";
		return( $in eq "y" );
	}
	else
	{
		$prompt .= " [yes/no] ? ";
		my $in="";
		while( $in ne "no" && $in ne "yes" )
		{
			print wrap_text( $prompt, 'console' );

			$in = lc(Term::ReadKey::ReadLine( 0 ));
			$in =~ s/\015?\012?$//s;
		}
		return( $in eq "yes" );
	}
	
	return 0;
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

Copyright (C) 2000-2006 University of Southampton

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

my $REQUIRED_CACHE = {};
sub require_if_exists
{
	my( $module ) = @_;

	if( defined $REQUIRED_CACHE->{$module} )
	{
		return $REQUIRED_CACHE->{$module};
	}

	$REQUIRED_CACHE->{$module} = 0;
	my $fp = $module.".pm";
	$fp =~ s/::/\//g;
	foreach my $path ( @INC )
	{
		if( -e $path."/".$fp )
		{
 			$REQUIRED_CACHE->{$module} = eval "require $module";
			last;
		}
	}

	return $REQUIRED_CACHE->{$module};
}

sub chown_for_eprints
{
	my( $file ) = @_;

	my $group = $EPrints::SystemSettings::conf->{group};
	my $username = $EPrints::SystemSettings::conf->{user};

	my(undef,undef,$uid,undef) = EPrints::Platform::getpwnam( $username );
	my $gid = EPrints::Platform::getgrnam( $group );

	EPrints::Platform::chown( $uid, $gid, $file );
}

######################################################################
# Redirect as this function has been moved.
######################################################################
sub render_xhtml_field { return EPrints::Extras::render_xhtml_field( @_ ); }

1;

######################################################################
=pod

=back

=cut
