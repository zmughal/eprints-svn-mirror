#!/usr/bin/perl

@files = ( 
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
%titles = (
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

%filemap = ();
foreach( @files )
{
	if( s/^!// )
	{
		$filemap{$_} = "../system/bin/$_";
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

$parser = Pod::Text->new( sentance=>0, width=>78 );
foreach $id ( @files )
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
foreach $id ( @files )
{
	print OUT " - ".$titles{$id}."\n";
}
foreach $file ( @id )
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

exit;
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

\\title{$DOCTITLE}
\\author{Christopher Gutteridge}

\\begin{document}
\\maketitle
\\tableofcontents
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
foreach $file ( @files )
{
        print "($file)\n";
	pod2html( 
		"--title=".$DOCTITLE." - ".$titles{$file},
		"--infile=../pod/$file.pod", 
		"--outfile=../docs/html/$file.html",
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
	`cp ../pod/$file.pod ../docs/pod`;
}
