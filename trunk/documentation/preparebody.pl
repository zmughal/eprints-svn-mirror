#!/usr/bin/perl

# script to add arbitary headers to an HTML body file
# and to tweak some tags to be XML compliantish
# cjg 21 Dec 2000

print join("\n",@ARGV)."\n";
while(<STDIN>) {
	s#<BR>#<BR \>#g;
	s#<HR>#<HR \>#g;
	s#SRC="([-a-z0-9]+\.(gif|jpg))"#SRC="image/$1"#ig;
	s#\[width=3.5in\]images/components#<IMG src="image/components.jpg">#g;
	print;
}
