#!/usr/bin/perl

use strict;

my @ids = ( 
	"intro", 
	"reqsoftware", 
	"installation", 
	"structure", 
	"configeprints",
	"configarchive",
	"metadata",
	"functions",
	"troubleshooting",
	"howto" ,
	"vlit" ,
	"backup" ,
	"contact", 
	"updating",
	"history" ,
	"logo",
	"!configure_archive",
	"!create_tables",
	"!create_user",
	"!erase_archive",
	"!erase_fulltext_cache",
	"!explain_sql_tables",
	"!export_hashes",
	"!export_xml",
	"!force_config_reload",
	"!generate_abstracts",
	"!generate_apacheconf",
	"!generate_static",
	"!generate_views",
	"!import_eprints",
	"!import_subjects",
	"!indexer",
	"!list_user_emails",
	"!rehash_documents",
	"!send_subscriptions",
	"!upgrade"






);
my %titles = (
	intro => "Introduction",
	reqsoftware => "Required Software",
	installation => "How to Install EPrints (and get started)",
	structure => "EPrints Structure and Terms",
	configeprints => "Configuring the System",
	configarchive => "The Archive Configuration Files",
	metadata => "Configuring the Archive Metadata",
	functions => "Configuring the functions of an Archive",
	howto => "How-To Guides",
	troubleshooting => "Troubleshooting",
	backup => "Backing-Up your System",
	contact => "Problems, Questions and Feedback",
	vlit => "VLit Transclusion Support",
	updating => "Updating from Previous Versions",
	history => "EPrints History (and Future Plans)",
	logo => "The EPrints Logo",

	cmdline=> "Command Line Tools"
);

my $website = ( $ARGV[0] eq "www" );
if( $website ){
	print "BUILDING DOCS FOR WEBSITE!!\n" 
}
else
{
	print "BUILDING DOCS FOR PACKAGE!!\n" 
}

my( @non_cmd_ids, @cmd_ids );
`rm tmp/*`;
`rm -rf binpod`;
`mkdir binpod`;
my %filemap = ();
foreach( @ids )
{
	if( s/^!// )
	{
		$filemap{$_} = "binpod/$_";
		`grep -v __GENERICPOD__ ../system/bin/$_ > binpod/$_`;
		$titles{$_} = "$_ command";
		push @cmd_ids, $_;
	}
	else
	{
		push @non_cmd_ids, $_;
		$filemap{$_} = "pod/$_.pod";
	}
}
		

my $DOCTITLE = "EPrints 2.3 Documentation";

my $BASENAME = "eprints-docs";

`rm -rf docs`;
`mkdir docs`;
	
##########################################################################
#
# texinfo
#
###############################################################################
print "Making TexInfo\n";

## Text
open( OUT, ">docs/$BASENAME.texinfo" );
my $firstnode = $ids[0];
print OUT <<END;

\@c %**start of header
\@setfilename eprints2.info
\@settitle $DOCTITLE
\@c Disable the monstrous rectangles beside overfull hbox-es.
\@finalout
\@c Use `odd' to print double-sided.
\@setchapternewpage on
\@c %**end of header

\@iftex
\@c Remove this if you don't use A4 paper.
\@afourpaper
\@end iftex

\@dircategory World Wide Web
\@direntry
* EPrints: (eprints).         EPrints Archive Software.
\@end direntry

\@node top, $firstnode, (dir) ,(dir)
\@top $DOCTITLE

GNU EPrints 2 Archive software from the University of Southampton.

The texinfo version is generated automatically from the POD version.

END

print OUT '@menu'."\n";
my @menu = @non_cmd_ids;
push @menu , "cmdline";
foreach my $id ( @menu )
{
	printf OUT '* '.$id.'::'.(" "x(20-(length $id))).$titles{$id}."\n";
}
print OUT '@end menu'."\n";

for( my $i=0; $i<scalar @menu; ++$i )
{
	my $id = $menu[$i];
	my $next = $menu[$i+1];
	my $prev = $menu[$i-1];
	$next = "" if( $i+1 == scalar @menu );
	$prev = "top" if( $i == 0 );

	print OUT "\@node $id, $next, $prev, top\n";

	if( $id eq "cmdline" )
	{
		print OUT <<END;

\@subheading EPrints Command Line Tools

These commands can usually be found in /opt/eprints2/bin/.

\@menu
END
		foreach my $id ( @cmd_ids )
		{
			printf OUT '* '.$id.'::'.(" "x(20-(length $id))).$titles{$id}."\n";
		}
		print OUT '@end menu'."\n";
		
	}
	else
	{
#		print "Processing: $filemap{$id}\n";
		print OUT `./pod2texinfo $filemap{$id}`;
	}
}

for( my $i=0; $i<scalar @cmd_ids; ++$i )
{
	my $id = $cmd_ids[$i];
	my $next = $cmd_ids[$i+1];
	my $prev = $cmd_ids[$i-1];
	$next = "" if( $i+1 == scalar @cmd_ids );
	$prev = "" if( $i == 0 );

	print OUT "\@node $id, $next, $prev, cmdline\n";
	# print "Processing: $filemap{$id}\n";
	print OUT `./pod2texinfo $filemap{$id}`;
}

print OUT "\n\n\@bye\n\n";

close OUT;

`makeinfo --force docs/$BASENAME.texinfo`;
`mv eprints2.info* docs`;

#########################################################################
#
# text
#
###############################################################################
print "Making ASCII Text\n";

use Pod::Text;

my $parser = Pod::Text->new( sentance=>0, width=>78 );
my $id;
foreach $id ( @ids )
{
	$parser->parse_from_file( $filemap{$id}, "tmp/$id.txt" );
}

## Text
open( OUT, ">docs/$BASENAME.txt" );
print OUT <<END;
==============================================================================
$DOCTITLE
==============================================================================

Contents:
END
foreach $id ( @ids )
{
	print OUT " - ".$titles{$id}."\n";
}
foreach $id ( @ids )
{
	print OUT <<END;

==============================================================================
$titles{$id}
==============================================================================

END
	open( IN, "tmp/".$id.".txt" );
	while( <IN> ) { print OUT $_; }
	close IN;
}
close OUT;

##########################################################################
#
# PDF & Postscript
#
###############################################################################
print "Making PDF & Postscript\n";

use Pod::LaTeX;

$parser = Pod::LaTeX->new(
	AddPreamble=>0,
	AddPostamble=>0
);
my $parser2 = Pod::LaTeX->new(
	Head1Level=>3,
	AddPreamble=>0,
	AddPostamble=>0
);
foreach $id ( @ids )
{
	if( $filemap{$id} =~ m/binpod/ )
	{
		$parser2->parse_from_file( $filemap{$id}, "tmp/$id.tex.old" );
		`sed 's/\\section{/\\section\*{/' tmp/$id.tex.old > tmp/$id.tex`;
	}
	else
	{
		$parser->parse_from_file( $filemap{$id}, "tmp/$id.tex" );
	}
}
open( OUT, ">tmp/$BASENAME.tex" );
print OUT <<END;
\\documentclass{book}
\\usepackage{graphicx}
\\usepackage{epsf}
\\usepackage{epsfig}

\\title{$DOCTITLE}
\\author{Christopher Gutteridge}

\\begin{document}
\\maketitle
\\tableofcontents
END
my $inbin = 0;
foreach $id ( @ids )
{
	if( $filemap{$id} =~ m/binpod/ )
	{
		unless( $inbin )
		{
			print OUT "\\chapter{Command Line Tools}\n";
		}
		$inbin = 1;
	}

	my $title = $titles{$id};
	$title =~ s/_/\\_/g;
	my $l = $inbin ? "section" : "chapter";
	print OUT "\\".$l."{$title}\n";
	open( IN, "tmp/".$id.".tex" );
	while( <IN> ) { print OUT $_; }
	close IN;
}

print OUT <<END;
\\end{document}
END
close OUT;

chdir( "tmp" );
my @commands = (
	"latex $BASENAME.tex",
	"latex $BASENAME.tex",
	"dvipdfm $BASENAME.dvi",
	"mv $BASENAME.pdf ../docs/",
	"dvips $BASENAME.dvi -o $BASENAME.ps",
	"psnup -2 $BASENAME.ps > $BASENAME-2up.ps",
	"mv $BASENAME-2up.ps ../docs/" );

foreach( @commands )
{
	`$_`;
}

###############################################################################
#
# HTML
#
###############################################################################
print "Making HTML\n";

use Pod::Html;
mkdir( '../docs/html' );
`cp ../images/* ../docs/html`;
foreach $id ( @ids )
{
	pod2html( 
		"--title=".$DOCTITLE." - ".$titles{$id},
		"--infile=../$filemap{$id}",
		"--outfile=../docs/html/$id.html",
		"--header",
		"--css=epdocs.css"
	);
}

open( INDEX, ">../docs/html/index.html" );
print INDEX <<END;
<html>
<head>
<title>$DOCTITLE</title>
<link REL="stylesheet" HREF="epdocs.css" TYPE="text/css">
<link REV="made" HREF="mailto:root\@lemur.ecs.soton.ac.uk">
</head>

<body>
<table BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH=100%>
<tr><td CLASS=block VALIGN=MIDDLE WIDTH=100% BGCOLOR="#cccccc">
<font SIZE=+1><strong><p CLASS=block>&nbsp;$DOCTITLE</p></strong></font>
</td></tr>
</table>
<h1>$DOCTITLE</h1>
<ul>
END
foreach $id ( @ids )
{
	print INDEX "<li><a href=\"$id.html\">".$titles{$id}."</a></li>\n";
}
print INDEX <<END;
</ul>
<table BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH=100%>
<tr><td CLASS=block VALIGN=MIDDLE WIDTH=100% BGCOLOR="#cccccc">
<font SIZE=+1><strong><p CLASS=block>&nbsp;$DOCTITLE</p></strong></font>
</td></tr>
</table>
</body>

</html>
END
close INDEX;

if( $website )
{
	mkdir( '../docs/php' );
	`cp ../images/* ../docs/php`;
	open( INC, ">../docs/php/index.inc" );
	print INC "<h2>$DOCTITLE</h2>\n";
	print INC "<ul><li><a href='../eprints-docs.pdf'>PDF Version</a></li></ul>";
	print INC "<ul>";
	foreach $id ( @ids )
	{
		print INC "<li><a href=\"/documentation/tech/php/$id.php\">".$titles{$id}."</a></li>\n";
		if( $id eq "logo" ) { print INC "</ul>\n<ul>"; }
	}
	print INC "</ul>\n";
	close( INC );

	open( INDEX, ">../docs/index.php" );
	print INDEX <<END;
<?
eprints_header( "Documentation - Technichal");
require "php/index.inc";
eprints_footer();
?>
END
	close INDEX;


	my $toc = '';
	foreach $id ( @ids )
	{
		$toc .= '<link rel="chapter" href="?" title="'.$titles{$id}.'" />'."\n";
	}

	my $c = 0;
	foreach $id ( @ids )
	{
		my $html = "../docs/html/$id.html";
		my $target = "../docs/php/$id.php";
		
		open( FILE, $html );
		open( TARGET, ">$target" );
	 	while( <FILE> ) { last if m/INDEX BEGIN/; }
		my $n = "";
		my $p = "";
		if( defined $ids[$c-1] )
		{
			$p = 
'<link rel="Prev" href="http://eprints.org/documentation/tech/php/'.$ids[$c-1].'.php" />';
		}
		if( defined $ids[$c+1] )
		{
			$n = 
'<link rel="Next" href="http://eprints.org/documentation/tech/php/'.$ids[$c+1].'.php" />';
		}
		print TARGET <<END;
<?

\$pagelinks = '
<link rel="Up" href="http://eprints.org/documentation/" />
<link rel="ToC" href="http://eprints.org/documentation/tech/" />
$toc
$p
$n
';

eprints_header( "Tech. Documentation - $titles{$id}" );
?>
<div class="floatmenu"><? require( "index.inc" ); ?></div>
END

		print TARGET '<div class="docs_index"><h2>Sections</h2>';
		# kill off FIRST HR only
		my $gothr = 0;
		while( <FILE> )
		{
			last if( m#CELLPADDING# );
			s#<h3>#<h4>#ig;
			s#</h3>#</h4>#ig;
			s#<h2>#<h3>#ig;
			s#</h2>#</h3>#ig;
			s#<h1>#<h2>#ig;
			s#</h1>#</h2>#ig;
			s#<!-- INDEX END -->#</div><div class="docs_body">#ig;
			if( !$gothr && s/<hr>//i ) { $gothr = 1; }
			s/''/"/ig;
			s/``/"/ig;
			print TARGET $_;
		}
		s/<table.*//i;

		print TARGET $_;
print TARGET <<END;
</div>
<? 
eprints_footer();
?>
END
		close TARGET;
		close FILE;
		
		++$c;
	}
}

###############################################################################
#
# POD
#
###############################################################################
print "Making POD\n";

# This just copies in the POD docs!

mkdir( '../docs/pod' );
foreach $id ( @ids )
{
	next if( $filemap{$id} =~ m/binpod/ );
	`cp ../$filemap{$id} ../docs/pod`;
}
chdir( ".." );

if( $website )
{
	my $user = 'webmaster';
	my $host = 'seer.ecs.soton.ac.uk';
	my $path = '/home/www.eprints/techdocs/';

	my @commands = (
		"ssh $user\@$host rm -rf '$path'",
		"scp -r docs/ $user\@$host:$path",
		"ssh $user\@$host chmod a+rX -R $path"
	);

	foreach( @commands )
	{
		print $_."\n";
		`$_`;
	}
}

