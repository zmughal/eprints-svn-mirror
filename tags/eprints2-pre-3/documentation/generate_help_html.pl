#!/usr/bin/perl -w

use strict;

# Converts latex2html output to a form suitable for putting in EPrints.

system( "rm -rf online-help-final" );

# Make the destination directory
mkdir "online-help-final", 0755 or die "Couldn't make online-help-final: $!\n";


# Sort out contents page

open NODE_IN, "online-help-html/index.html"
	or die "Couldn't open online-help-html/index.html: $!\n";

open NODE_OUT, ">online-help-final/index.html"
	or die "Couldn't open online-help-final/index.html for writing: $!\n";

print NODE_OUT "TITLE: On-line Help\n\n";
print NODE_OUT "<P>Help is available on the following topics:</P>\n";

my $in_childlinks=0;
my @output_lines;

while( <NODE_IN> )
{
	chomp();

	if( /End of Table of Child\-Links/i )
	{
		$in_childlinks = 0;
	}
	elsif( /Table of Child\-Links/i )
	{
		$in_childlinks = 1;
	}
	elsif( $in_childlinks==1 )
	{
		if( /Introduction/ )
		{
			pop @output_lines;
		}
		else
		{
			push @output_lines, $_;
		}
	}
}

foreach (@output_lines)
{
	print NODE_OUT "$_\n";
}

print NODE_OUT "<P>The on-line help is also available as a <A HREF=\"online-help.pdf\"".
	">printable PDF document</A>.</P>\n";


# Modification date.

open DVI_IN, "online-help/latex/online-help.dvi" or die "Couldn't open DVI file: $!\n";

my $mtime = (stat DVI_IN)[9];

close DVI_IN;

print NODE_OUT "<P>This version of the on-line help is dated ".
	&format_date( $mtime ).".</P>\n";


close NODE_OUT;
close NODE_IN;




my $node_in_filename;

foreach $node_in_filename (<online-help-html/node*.html>)
{
	if( $node_in_filename =~ /node1\.html/ )
	{
		print STDERR "Skipping introduction $node_in_filename\n";
	}
	else
	{
		print STDERR "Processing $node_in_filename\n";

		# Open files
		open NODE_IN, $node_in_filename
			or die "Couldn't open $node_in_filename: $!\n";

		my $out_filename = $node_in_filename;
		$out_filename =~ s/help\-html/help\-final/;

		open NODE_OUT, ">$out_filename"
			or die "Couldn't open $out_filename for writing: $!\n";
		
		# Skip header, reading title
		my $continue = 1;
		my $title;

		while( $continue )
		{
			my $line = <NODE_IN>;
			$continue = 0 if( !defined $line );

			chomp( $line );
			
			$title = $1 if( $line =~ /<TITLE>(.+)<\/TITLE>/ );
			$continue = 0 if( $line =~ /<BODY.*>/ );
		}
		
		die "No title found in $node_in_filename" unless( defined $title );

		# Write title
		print NODE_OUT "TITLE: $title\n\n";
		
		# Link back to contents
		print NODE_OUT "<P ALIGN=CENTER><A HREF=\"__staticroot__/help/\">Return to Help Contents</A></P>\n";
			
		# Remove title, get anchor name
		$continue = 1;
		my $anchor;

		while( $continue )
		{
			my $line = <NODE_IN>;
			$continue = 0 if( !defined $line );
			chomp( $line );
			
			$anchor = $1 if( $line =~ /<A NAME=\"(\w+)\">/ );
			$continue = 0 if( $line =~ /<\/H1>/ );
		}

		die "No anchor for title found in $node_in_filename\n" unless( defined $anchor );
		
		print NODE_OUT "<A NAME=\"$anchor\">\n";
		
		# Now go through message body.
		$continue = 1;
		
		while( $continue )
		{
			my $line = <NODE_IN>;
			$continue = 0 if( !defined $line );
			chomp( $line );

			if( $line=~ /<BR><HR>/ )
			{
				$continue = 0;
			}
			elsif( $line =~ /<P><\/P>/ )
			{
				# This signifies the start on an image segment.
				
				# Get the anchor names from the next line
				$line = <NODE_IN>;
				chomp( $line );
				
				$line =~ /<A NAME=\"(\w+)\"><\/A><A NAME=\"(\w+)\"><\/A>/;
				
				print NODE_OUT "<A NAME=\"$1\"></A><A NAME=\"$2\"></A>\n";
				
				# The caption
				my $temp = <NODE_IN>; # Ignore a line
				$temp = <NODE_IN>; # Get first caption line
				chomp( $temp );
				$temp =~ /<STRONG>(.+)<\/STRONG>/;
				my $caption_text = "<STRONG>$1</STRONG> ";
				$temp = <NODE_IN>; # Second caption line.
				chomp( $temp );
				$temp =~ s/<\/CAPTION>//;
				$caption_text .= $temp;
				
				# Now to get the filename
				<NODE_IN>; <NODE_IN>; # Skip 2 lines
				$temp = <NODE_IN>;
				chomp( $temp );
				$temp =~ /\]images\/(.+)<\/DIV>/;
				my $image_filename = $1.".jpg";
				
				# Write the image stuff out
				
				print NODE_OUT "<BR>\n";
				print NODE_OUT "<P ALIGN=CENTER><IMG SRC=\"$image_filename\"></P>\n";
				print NODE_OUT "<P ALIGN=CENTER>$caption_text</P>\n";
				print NODE_OUT "<BR>\n";

				# Skip the rest of the image stuff
				<NODE_IN>; <NODE_IN>; <NODE_IN>; # Skip 3 lines
			}
			else
			{
				# Regurgitate
				print NODE_OUT "$line\n";
			}
		}

		print NODE_OUT "<P ALIGN=CENTER><A HREF=\"__staticroot__/help/\">Return to Help Contents</A></P>\n";

		close NODE_OUT;
		close NODE_IN;
	}
}

# Now copy the images across
system( "cp online-help/latex/images/*.jpg online-help-final" );


sub format_date
{
	my( $time ) = @_;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=gmtime( $time );
	$mon=("January","February","March","April","May","June","July","August","September","October","November","December")[$mon];
	$year=$year+1900;
	return( "$mday $mon $year" );
}
