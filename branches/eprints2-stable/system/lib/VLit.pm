######################################################################
#
# EPrints::VLit
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

B<EPrints::VLit> - VLit Transclusion Module

=head1 DESCRIPTION

This module is consulted when any document file is served. It allows
subsets of the whole to be served.

This is an experimental feature. It may be turned off in the configuration
if you object to it for some reason.

=over 4

=cut

package EPrints::VLit;

use CGI;
use EPrints::AnApache;
use Digest::MD5;
use FileHandle;

use strict;
use EPrints::XML;

my $TMPDIR = "/tmp/partial";



######################################################################
=pod

=item EPrints::VLit::handler( $r )

undocumented

=cut
######################################################################

sub handler
{
	my( $r ) = @_;

	my $filename = $r->filename;

	if ( ! -r $filename ) 
	{
		return NOT_FOUND;
	}

	my $apr = Apache::Request->new( $r );

	my $version = $apr->param( "xuversion" );
	my $locspec = $apr->param( "locspec" );

	if( !defined $version && !defined $apr->param( "mode" ) )
	{
		# We don't need to handle it, just do this 
		# the normal way.
		return DECLINED;
	}

	if( !defined $locspec )
	{
		$locspec = "charrange:";
	}

	# undo eprints rewrite!
	my $uri = $r->uri;	
	$uri =~ s#/([0-9]+)/([0-9][0-9])/([0-9][0-9])/([0-9][0-9])/#/$1$2$3$4/#;
	my $baseurl = $uri;
	
	my $LSMAP = {
"area" => \&ls_area,
"charrange" => \&ls_charrange
};

	unless( $locspec =~ m/^([a-z]+):(.*)$/ )
	{
		send_http_error( 400, "Bad locspec \"$locspec\"" );
		return;
	}

	my( $lstype, $lsparam ) = ( $1, $2 );

	my $fn = $LSMAP->{$lstype};

	if( !defined $fn )
	{
		send_http_error( 501, "Unsupported locspec" );
		return;
	}

	&$fn( $filename, $lsparam, $locspec, $r, $apr, $baseurl );

	return OK;
}




######################################################################
=pod

=item EPrints::VLit::send_http_error( $code, $message )

undocumented

=cut
######################################################################

sub send_http_error
{
	my( $code, $message ) = @_;

	my $r = Apache->request;
	$r->content_type( 'text/html' );
	$r->status_line( "$code $message" );
	$r->send_http_header;
	my $title = "Error $code in VLit request";
	$r->print( <<END );
<html>
<head><title>$title</title></head>
<body>
  <h1>$title</h1>
  <p>$message</p>
</body>
END
}


######################################################################
=pod

=item EPrints::VLit::send_http_header( $type )

undocumented

=cut
######################################################################

sub send_http_header
{
	my( $type ) = @_;

	my $r = Apache->request;
	if( defined $type )
	{
		$r->content_type( $type );
	}
	$r->status_line( "200 YAY" );
	$r->send_http_header;
}

####################


######################################################################
=pod

=item EPrints::VLit::ls_charrange( $filename, $param, $locspec, $r, $apr, $baseurl )

undocumented

=cut
######################################################################

sub ls_charrange
{
	my( $filename, $param, $locspec, $r, $apr, $baseurl ) = @_;

	my $archive = EPrints::Archive->new_from_request( $r );
	
#	if( $r->content_type !~ m#^text/# )
#	{
#		send_http_error( 400, "Can't return a charrange of mimetype: ".$r->content_type );
#		return;
#	}
		
	my( $offset, $length );
	if( $param eq "" )
	{
		$offset = 0;
		$length = -s $filename;
	}
	else
	{	
		unless( $param=~m/^(\d+)\/(\d+)$/ )
		{
			send_http_error( 400, "Malformed charrange param: $param" );
			return;
		}
		( $offset, $length ) = ( $1, $2 );
	}

	my $mode = $apr->param( "mode" );

	my $readoffset = $offset;
	my $readlength = $length;
	my $constart = -1;
	my $conend = -1;
	if( $mode eq "context" )
	{
		my $contextsize = 512;
		$readoffset-=$contextsize;
		$readlength+=$contextsize+$contextsize;
		$constart = $contextsize;
		if( $readoffset<0 )
		{
			$constart += $readoffset;
			$readlength += $readoffset;
			$readoffset=0;
		}
		$conend = $readlength-$contextsize;
	}

	if( $mode eq "context2" )
	{
		# has a char range but loads whole document
		$readoffset = 0;
		$readlength = -s $filename;
		$constart = $offset;
		$conend = $offset+$length;
	}
	
	my $fh = new FileHandle( $filename, "r" );
	binmode( $fh );
	my $data = "";
	$fh->seek( $readoffset, 0 );
	$fh->read( $data, $readlength );
	$fh->close();

	if( $mode eq "human" || $mode eq "context" || $mode eq "context2" || $mode eq 'spanSelect' || $mode eq 'endSelect' || $mode eq 'link' || $mode eq 'spanSelect2' || $mode eq 'endSelect2' )
	{
		my $html = "";
		my $BIGINC = 100;
		my $inc = $BIGINC;
		if( $mode eq  'spanSelect2'  ||  $mode eq 'endSelect2' || $mode eq 'context' || $mode eq "context2" )
		{
			$inc = 1;
		}
		$html.='<span class="vlit-charrange">';
		my $toggle = 0;
		for( my $o=0; $o<$readlength; $o+=$inc )
		{
			my $class = "vlit-spanlink".($toggle+1);
			$toggle = !$toggle; 
			if( $o == $constart)
			{
				$html.='<span class="vlit-highlight">';
			}
			if( $o == $constart-512)
			{
				$html.='<a name="c" />';
			}
			my $c=substr($data,$o,$inc);
			# $c is either a string or a single char
			$c =~ s/&/&amp;/g;
			$c =~ s/</&lt;/g;
			$c =~ s/>/&gt;/g;
			$c =~ s/\n/<br \/>/g;
			if( $mode eq 'spanSelect' )
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset+$o)."/".($length-$o).'&mode=spanSelect2';
				$c ='<a class="'.$class.'" href="'.$url.'">'.$c.'</a>';
			}
			if( $mode eq 'spanSelect2' && $o < $BIGINC )
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset+$o)."/".($length-$o).'&mode=endSelect';
				$c ='<a class="'.$class.'" href="'.$url.'">'.$c.'</a>';
			}
			if( $mode eq 'endSelect' )
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset)."/".($o+$inc).'&mode=endSelect2#end';
				$c ='<a class="'.$class.'" href="'.$url.'">'.$c.'</a>';
			}
			if( $mode eq 'endSelect2' && $o > $readlength-$BIGINC-1)
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset)."/".($o+1).'&mode=link';
				$c ='<a class="'.$class.'" href="'.$url.'">'.$c.'</a>';
			}
			#if( $o > 0 && $mode eq "spanSelect" ) { $html.="|"; }
			$html.=$c;
			if( $o == $conend-1 )
			{
				$html.='</span>';
			}
		}
		$html.='</span>';
		my $copyurl = $archive->get_conf( "vlit" )->{copyright_url};
		my $front = '<a href="'.$copyurl.'">trans &copy;</a>';
		if( $param eq "" )
		{
			if( $mode eq "human" )
			{
				$front.= ' [<a href="'.$baseurl.'?mode=spanSelect">quote document</a>]';
			}
		}
		else
		{
			my $url = $baseurl;
			if( $mode eq "human" )
			{
				$front.= ' [<a href="'.$baseurl.'?xuversion=1.0&locspec=charrange:'.$param.'&mode=context">view context</a>]';
			}
			if( $mode eq "context" )
			{
				$front.= ' [<a href="'.$baseurl.'?xuversion=1.0&locspec=charrange:'.$param.'&mode=context2#c">context in full document</a>]';
			}
			if( $mode eq "context2" )
			{
				$front.= ' [<a href="'.$baseurl.'?xuversion=1.0&locspec=charrange:&mode=human">full document</a>]';
				$front.= ' [<a href="'.$baseurl.'?mode=spanSelect">quote document</a>]';
			}
		}
		$front.= ' [<a href="'.$baseurl.'?xuversion=1.0&locspec=charrange:'.$param.'">raw data</a>]';

		my $msg='';
		my $msg2='';
		if( $mode eq "endSelect2" )
		{ 
			$msg='<h1>select exact end point</h1>';
		}
		if( $mode eq "spanSelect2" )
		{ 
			$msg='<h1>select exact start point</h1>';
		}
		if( $mode eq "endSelect" )
		{ 
			$msg='<h1>select approximate end point</h1>';
		}
		if( $mode eq "spanSelect" )
		{ 
			$msg='<h1>select approximate start point</h1>';
		}
		$msg2=$msg; # only for span msgs
		
			
		
			
		send_http_header( "text/html" );
		my $title = "Transquotation from char $offset, length $length";
		if( $mode eq 'link' )
		{
			my $url = $baseurl.'?xuversion=1.0&locspec=charrange:'.($offset)."/".($length);
			my $urlh = $url.'&mode=human';
			my $urlx = $url.'&mode=xml-entity';
			$msg=<<END;
<div style="margin: 8px;">
<p><b>$title</b></p>
<p>Raw char quote: <a href="$url">$url</a></p>
<p>Human readable (HTML): <a href="$urlh">$urlh</a></p>
<p>XML: <a href="$urlx">$urlx</a></p>
END
			my $urlh2 = $urlh;
			$urlh2=~s/'/&squot;/g;
			$msg.=<<END;
<p>Cut and paste HTML for pop-up window:</p>
<div style="margin-left: 10px"><tt>
&lt;a href="#" onclick="javascript:window.open( '$urlh2', 'transclude_window', 'width=666, height=444, scrollbars');"&gt;$title&lt;/a&gt;
</tt></div>
</div>
END
		}
		my $cssurl = $archive->get_conf( "base_url" )."/vlit.css";
		$r->print( <<END );
<html>
<head>
  <title>$title</title>
  <link rel="stylesheet" type="text/css" href="$cssurl" title="screen stylesheet" media="screen" />
</head>
<body class="vlit">
$msg
<div class="vlit-controls">$front</div><div class="vlit-human">$html</div><a name="end" />
$msg2
</body>
</html>
END
	}
	elsif( $mode eq "xml-entity" )
	{
		my $page = EPrints::XML::make_document();
		my $transclusion = $page->createElement( "transclusion" );
		$transclusion->setAttribute(
			"xlmns", 
			"http://xanadu.net/transclusion/xu/1.0" );
		$transclusion->setAttribute( "href", $baseurl );
		$transclusion->setAttribute( "offset", $offset );
		$transclusion->setAttribute( "length", $length );
		$transclusion->appendChild( $page->createTextNode( $data ) );
		$page->appendChild( $transclusion );	

		send_http_header( "text/xml" );
		$r->print( EPrints::XML::to_string( $page ) );
	}
	else
	{
		send_http_header();
		$r->print( $data );
	}
}


######################################################################
=pod

=item EPrints::VLit::ls_area( $file, $param, $resspec, $r, $apr, $baseurl )

undocumented

=cut
######################################################################

sub ls_area
{
	my( $file, $param, $resspec, $r, $apr, $baseurl ) = @_;

	my $page = 1;
	my $opts = {
		page => 1,
		hrange => { start=>0 },
		vrange => { start=>0 }
	};

	my $s;
	if( $apr->param( "scale" ) )
	{
		$s = $apr->param( "scale" );
		$s = undef if( $s <= 0 || $s>1000 || $s==100 );
	}

	foreach( split( "/", $param ) )
	{
		my( $key, $value ) = split( "=", $_ );
		if( $key eq "page" )
		{
			unless( $value =~ m/^\d+$/ )
			{
				send_http_error( 400, "Bad page id in area locspec" );
				return;
			}
			$opts->{page} = $value;
		}
		if( $key eq "hrange" || $key eq "vrange" )
		{
			unless( $value =~ m/^(\d+)?,(\d+)?$/ )
			{
				send_http_error( 400, "Bad $key in area locspec" );
				return;
			}
			$opts->{$key}->{start} = $1 if( defined $1 );
			$opts->{$key}->{end} = $2 if( defined $2 );
		}
	}
	
	my $cache = cache_file( "area", $param."/".$s );

	my $dir = $TMPDIR."/area/".Digest::MD5::md5_hex( $file );


	unless( -e $cache )
	{
		my( $p, $x, $y, $w, $h ) = ( $1, $2, $3, $4, $5 );

		# pagearea/ exists cus of cache_file called above.
		if( !-d $dir )
		{
			mkdir( $dir );
			my $cmd = "/usr/bin/X11/convert '$file' 'tif:$dir/%d'";
			`$cmd`;
		}
	}

	my $pageindex = $opts->{page} - 1;

	my $crop = "";

	# Don't crop if we is wanting the full page
	unless( $opts->{hrange}->{start} == 0 && !defined $opts->{hrange}->{end}
	 && $opts->{vrange}->{start} == 0 && !defined $opts->{vrange}->{end} )
	{
		$crop = "-crop ";
		if( defined $opts->{hrange}->{end} )
		{
			$crop .= ($opts->{hrange}->{end} - $opts->{hrange}->{start} + 1);
		}
		else
		{
			$crop .= '999999';
		}
		$crop .= "x";
		if( defined $opts->{vrange}->{end} )
		{
			$crop .= ($opts->{vrange}->{end} - $opts->{vrange}->{start} + 1);
		}
		else
		{
			$crop .= '999999';
		}
		$crop .= "+".$opts->{hrange}->{start};
		$crop .= "+".$opts->{vrange}->{start};
	}

	my $cmd;
	$cmd = "tiffinfo $dir/$pageindex";
	my $scale = '';
	my @d = `$cmd`;
	foreach( @d )
	{
		$scale = '-scale 100%x200%' if m/Resolution: 204, 98 pixels\/inch/;
	}
	my $scale2 = "";
	if( defined $s )
	{
		$scale2 = '-scale '.$s.'%x'.$s.'%';
	}

	$cmd = "/usr/bin/X11/convert $scale $crop $scale2 '$dir/$pageindex' 'png:$cache'";
	`$cmd`;
	

	send_http_header( "image/png" );
	$cmd = "cat $cache";
	print `$cmd`;
}




######################################################################
=pod

=item EPrints::VLit::cache_file( $resspec, $param )

undocumented

=cut
######################################################################

sub cache_file
{
	my( $resspec, $param ) = @_;

	$param = "null" if( $param eq "" );

	$resspec =~ s/[^a-z0-9]/sprintf('_%02X',ord($&))/ieg;
	$param =~ s/[^a-z0-9]/sprintf('_%02X',ord($&))/ieg;

	mkdir( $TMPDIR ) if( !-d $TMPDIR );

	my $dir = $TMPDIR."/".$resspec;
	
	mkdir( $dir ) if( !-d $dir );

	return $dir."/".$param;
}


1;

######################################################################
=pod

=back

=cut

