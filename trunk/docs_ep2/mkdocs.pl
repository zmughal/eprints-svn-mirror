#!/usr/bin/perl

@files = ( "intro", "reqsoftware", "installation", "contact", "history" );
%titles = (
	intro => "Introduction",
	reqsoftware => "Required Software",
	installation => "How to Install EPrints (and get started)",
	contact => "Problems, Questions and Feedback",
	history => "EPrints History (and Future Plans)"
);

my $BASENAME = "eprints2-alpha2-docs";
	
##########################################################################
# text

use Pod::Text;

$parser = Pod::Text->new( sentance=>0, width=>78 );
foreach $file ( @files )
{
	$parser->parse_from_file( "pod/$file.pod", "tmp/$file.txt" );
}

## Text
open( OUT, ">$BASENAME.txt" );
print OUT <<END;
==============================================================================
EPrints 2 - Alpha - Documentation
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
`mv $BASENAME.pdf ..`;
