#!/usr/bin/perl

use strict;

my @ids = ( 
	"intro", 
	"reqsoftware", 
	"installation", 
	"structure", 
	"configeprints",
	"configarchive",
	"contact", 
	"history" ,
	"logo",
	"!configure_archive",
	"!create_tables",
	"!create_user",
	"!erase_archive",
	"!generate_abstracts",
	"!generate_apacheconf",
	"!generate_dtd",
	"!generate_static",
	"!generate_views",
	"!import_subjects",
	"!reindex"
);
my %titles = (
	intro => "Introduction",
	reqsoftware => "Required Software",
	installation => "How to Install EPrints (and get started)",
	structure => "EPrints Structures and Terms",
	configeprints => "Configuring the System",
	configarchive => "Configuring an Archive",
	contact => "Problems, Questions and Feedback",
	history => "EPrints History (and Future Plans)",
	logo => "The EPrints Logo"
);

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
		

my $DOCTITLE = "EPrints 2.0 Documentation";

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
        print "($id)\n";
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
<h1>$DOCTITLE: Index</h1>
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

###############################################################################
# POD

# This just copies in the POD docs!

mkdir( '../docs/pod' );
foreach $id ( @ids )
{
	next if( $filemap{$id} =~ m/binpod/ );
	`cp ../$filemap{$id} ../docs/pod`;
}
