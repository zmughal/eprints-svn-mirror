#!/usr/bin/perl

@files = ( 
	"intro", 
	"reqsoftware", 
	"installation", 
	"configeprints",
	"configarchive",
	"contact", 
	"history" ,
	"logo"
);
%titles = (
	intro => "Introduction",
	reqsoftware => "Required Software",
	installation => "How to Install EPrints (and get started)",
	configeprints => "Configuring the System",
	configarchive => "Configuring an Archive",
	contact => "Problems, Questions and Feedback",
	history => "EPrints History (and Future Plans)",
	logo => "The EPrints Logo"
);

my $DOCTITLE = "EPrints 2.0 Documentation";

my $BASENAME = "eprints-2.0-docs";

`rm -rf docs`;
`mkdir docs`;
	
##########################################################################
# text

use Pod::Text;

$parser = Pod::Text->new( sentance=>0, width=>78 );
foreach $file ( @files )
{
	$parser->parse_from_file( "pod/$file.pod", "tmp/$file.txt" );
}

## Text
open( OUT, ">docs/$BASENAME.txt" );
print OUT <<END;
==============================================================================
$DOCTITLE
==============================================================================

Contents:
END
foreach $file ( @files )
{
	print OUT " - ".$titles{$file}."\n";
}
foreach $file ( @files )
{
	print OUT <<END;

==============================================================================
$titles{$file}
==============================================================================

END
	open( IN, "tmp/".$file.".txt" );
	while( <IN> ) { print OUT $_; }
	close IN;
}
close OUT;


##########################################################################
# PDF

use Pod::LaTeX;

$parser = Pod::LaTeX->new(
	AddPreamble=>0,
	AddPostamble=>0
);
foreach $file ( @files )
{
	print "($file)\n";
	$parser->parse_from_file( "pod/$file.pod", "tmp/$file.tex" );
}
open( OUT, ">tmp/$BASENAME.tex" );
print OUT <<END;
\\documentclass{book}
\\usepackage{graphicx}
\\begin{document}
END
foreach $file ( @files )
{
	print OUT "\\chapter{$titles{$file}}\n";
	open( IN, "tmp/".$file.".tex" );
	while( <IN> ) { print OUT $_; }
	close IN;
}
print OUT <<END;
\\end{document}
END
close OUT;

chdir( "tmp" );
`latex $BASENAME.tex`;
`dvipdfm $BASENAME.dvi`;
`mv $BASENAME.pdf ../docs/`;

###############################################################################
# HTML

use Pod::Html;
mkdir( '../docs/html' );
`cp ../images/* ../docs/html`;
foreach $file ( @files )
{
        print "($file)\n";
	pod2html( 
		"--title=".$DOCTITLE." - ".$titles{$file},
		"--infile=../pod/$file.pod", 
		"--outfile=../docs/html/$file.html",
		"--header",
		"--css=epdocs.css",
		"--noindex"
	);
}

open( INDEX, ">../docs/html/index.html" );
print INDEX <<END;
<html>
<head>
<title>$DOCTITLE</title>
<link REL="stylesheet" HREF="epdocs.css" TYPE="text/css">
<link REV="made" HREF="mailto:root@lemur.ecs.soton.ac.uk">
</head>

<body>
<table BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH=100%>
<tr><td CLASS=block VALIGN=MIDDLE WIDTH=100% BGCOLOR="#cccccc">
<font SIZE=+1><strong><p CLASS=block>&nbsp;$DOCTITLE</p></strong></font>
</td></tr>
</table>
<h1>$DOCTITLE: Index</h1>
<ul>
END
foreach $file ( @files )
{
	print INDEX "<li><a href=\"$file.html\">".$titles{$file}."</a></li>\n";
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

###############################################################################
# POD

# This just copies in the POD docs!

mkdir( '../docs/pod' );
foreach $file ( @files )
{
	`cp $file ../docs/pod`;
}
