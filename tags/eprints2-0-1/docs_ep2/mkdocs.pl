#!/usr/bin/perl

use strict;

my @ids = ( 
	"intro", 
	"reqsoftware", 
	"installation", 
	"structure", 
	"configeprints",
	"configarchive",
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
	"!generate_abstracts",
	"!generate_apacheconf",
	"!generate_static",
	"!generate_views",
	"!import_subjects",
	"!reindex"
);
my %titles = (
	intro => "Introduction",
	reqsoftware => "Required Software",
	installation => "How to Install EPrints (and get started)",
	structure => "EPrints Structure and Terms",
	configeprints => "Configuring the System",
	configarchive => "Configuring an Archive",
	howto => "How-To Guides",
	troubleshooting => "Troubleshooting",
	backup => "Backing-Up your System",
	contact => "Problems, Questions and Feedback",
	vlit => "VLit Transclusion Support",
	updating => "Updating from Previous Versions",
	history => "EPrints History (and Future Plans)",
	logo => "The EPrints Logo"
);

my $website = ( $ARGV[0] eq "www" );
if( $website ){
	print "BUILDING DOCS FOR WEBSITE!!\n" 
}
else
{
	print "BUILDING DOCS FOR PACKAGE!!\n" 
}

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
	}
	else
	{
		$filemap{$_} = "pod/$_.pod";
	}
}
		

my $DOCTITLE = "EPrints 2.0.1 Documentation";

my $BASENAME = "eprints-2.0-docs";

`rm -rf docs`;
`mkdir docs`;
	
##########################################################################
# text

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
# PDF & Postscript

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
	print "($id)\n";
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
	print $_."\n";
	`$_`;
}

###############################################################################
# HTML

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
	print INC "<h2>$DOCTITLE</h2><ul>\n";
	foreach $id ( @ids )
	{
		print INC "<li><a href=\"/docs/php/$id.php\">".$titles{$id}."</a></li>\n";
	}
	print INC "</ul>\n";
	close( INC );
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
'<link rel="Prev" href="http://www.eprints.org/docs/php/'.$ids[$c-1].'.php" />';
		}
		if( defined $ids[$c+1] )
		{
			$n = 
'<link rel="Next" href="http://www.eprints.org/docs/php/'.$ids[$c+1].'.php" />';
		}
		print TARGET <<END;
<?

include "../../../conf/site_conf.phps";
include "../../../include/elements.phps";

\$pagetitle = "$DOCTITLE - $titles{$id}";
\$pagelinks = '
<link rel="Up" href="http://www.eprints.org/documentation.php" />
<link rel="ToC" href="http://www.eprints.org/documentation.php" />
$toc
$p
$n
';


function do_page()
{
?>
<h1>$DOCTITLE - $titles{$id}</h1>
END

		print TARGET $_;
		while( <FILE> )
		{
			last if( m#CELLPADDING# );
			print TARGET $_;
		}
		s/<table.*//i;
		print TARGET $_;
		print TARGET <<END;
<?
} 
ep_generate_page( "??" );
?>
END
		close TARGET;
		close FILE;
		
		++$c;
	}
}

###############################################################################
# POD

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
	my $host = 'sage.ecs.soton.ac.uk';
	my $path = '/home/www.eprints/htdocs/docs/';

	my @commands = (
		"rsh -l $user $host rm -rf '$path*'",
		"rcp -r docs/ $user\@$host:$path",
		"rsh -l $user $host chmod a+rX -R $path"
	);

	foreach( @commands )
	{
		print $_."\n";
		`$_`;
	}
}

