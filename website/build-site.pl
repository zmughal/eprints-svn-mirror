#!/usr/bin/perl -w

use Getopt::Long;
use strict;


# Configuation variables.

my $config_file = "site.cfg";

my %config;

# SITEROOT
# MAIN_FG
# MAIN_BG
# NAV_BG
# NAV_FG_HI
# NAV_FG_LO

my @icons;

my @html_files;
my %nav_icon_text;
my %urls;

# What site config file?
my $siteroot = undef;
my $htmlroot = undef;
my $dest = undef;
unless( GetOptions( "config=s",   \$config_file,
                    "siteroot=s", \$siteroot,
                    "htmlroot=s", \$htmlroot,
                    "dest=s",     \$dest ) )
{
	die "Usage: build-site.pl [--config=<site-cfg-file>] [--siteroot=<site-root-url>] [--htmlroot=<html-root-url>] [--dest=<destination-dir>]\n";
}


# Set up config defaults
$config{IN_RAW} = "in-raw";
$config{IN_HTML} = "in-html";
$config{OUT} = "out";
$config{TEMPLATE} = "template.html";


# Read in site config
open( SITECFG, $config_file ) or die "Can't open site config\n";

while( <SITECFG> )
{
	chomp();
	
	if( /^ICON_HTML:/i )
	{
		my( $dummy, $file_stem, $icon_text ) = split /:/, $_;

		push @icons, $file_stem;
		push @html_files, $file_stem;
		$nav_icon_text{$file_stem} = $icon_text;
	}
	elsif( /^ICON_URL:/i )
	{
		# ICON_URL: filename: Icon Text : URL
		m/^ICON_URL:\s*([^:]+)\s*:\s*([^:]+)\s*:\s*(\S*)\s*$/i;

		my( $stem, $icon_text, $url ) = ( $1, $2, $3 );

		push @icons, $stem;
		$nav_icon_text{$stem} = $icon_text;
		$urls{$stem} = $url;
	}
	elsif( /^HTML:/i )
	{
		my( $dummy, $file_stem ) = split /:/, $_;
		push @html_files, $file_stem;
	}
	elsif( /^[^#]/ )      # Ignore comments
	{
		/^([^:]+):\s*(.+)\s*$/;
		$config{$1} = $2;
	}
}

close( SITECFG );

# HTMLROOT = SITEROOT unless we're given an alternative
$config{HTMLROOT} = $config{SITEROOT} unless( defined $config{HTMLROOT} );

# Stuff overidden by command line args...
$config{SITEROOT} = $siteroot if( defined $siteroot );
$config{HTMLROOT} = $htmlroot if( defined $htmlroot );
$config{OUT} = $dest if( defined $dest );


# Now we generate the HTML

my $stem;

foreach $stem (@html_files)
{
	my $in_filename = "$config{IN_HTML}/$stem.html";
	my $out_filename = "$config{OUT}/$stem.html";

	&write_html( $stem, $in_filename, $out_filename, 0 );
}



# Make image directory for gif's
mkdir "$config{OUT}/image", 0755;

# Work out colours in terms of values for GIMP script
$config{NAV_FG_HI} =~ /(..)(..)(..)/;
my @nav_fg_hi_cols = ( hex($1), hex($2), hex($3) );
$config{NAV_FG_LO} =~ /(..)(..)(..)/;
my @nav_fg_lo_cols = ( hex($1), hex($2), hex($3) );
$config{NAV_BG} =~ /(..)(..)(..)/;
my @nav_bg_cols = ( hex($1), hex($2), hex($3) );
$config{NAV_OUTLINE_HI} =~ /(..)(..)(..)/;
my @nav_outline_hi_cols = ( hex($1), hex($2), hex($3) );
$config{NAV_OUTLINE_LO} =~ /(..)(..)(..)/;
my @nav_outline_lo_cols = ( hex($1), hex($2), hex($3) );

# Generate the .gif's
open( GIMPOUT, ">gimp.script" );

my $icon;
print GIMPOUT "(\n";
foreach $icon (@icons)
{
	print GIMPOUT "(\"$config{OUT}/image/init_$icon.hi.gif\" \"$nav_icon_text{$icon}\" ".
		"($nav_fg_hi_cols[0] $nav_fg_hi_cols[1] $nav_fg_hi_cols[2]) ".
		"($nav_bg_cols[0] $nav_bg_cols[1] $nav_bg_cols[2]) ".
		"($nav_outline_hi_cols[0] $nav_outline_hi_cols[1] $nav_outline_hi_cols[2]))\n";
	print GIMPOUT "(\"$config{OUT}/image/init_$icon.gif\" \"$nav_icon_text{$icon}\" ".
		"($nav_fg_lo_cols[0] $nav_fg_lo_cols[1] $nav_fg_lo_cols[2]) ".
		"($nav_bg_cols[0] $nav_bg_cols[1] $nav_bg_cols[2])".
		"($nav_outline_lo_cols[0] $nav_outline_lo_cols[1] $nav_outline_lo_cols[2]))\n";
}
print GIMPOUT ")\n";
close( GIMPOUT );

# Run the GIMP
my $current_dir = `pwd`;
chomp( $current_dir );
my $command_line = "gimp --verbose --no-data --no-interface --batch '(dolots-sideicons \"gimp.script\")' '(gimp-quit 0)'";
print "$command_line\n";
#system( "sh", "-c", $command_line );

# Make transparent
foreach $icon (keys %nav_icon_text)
{
	$command_line = "giftrans -t 0 \"$config{OUT}/image/init_$icon.hi.gif\" >\"$config{OUT}/image/$icon.hi.gif\"";
	#print "!$command_line\n";
	#system( "sh", "-c", $command_line );
	$command_line = "giftrans -t 0 \"$config{OUT}/image/init_$icon.gif\" >\"$config{OUT}/image/$icon.gif\"";
	#print "?$command_line\n";
	#system( "sh", "-c", $command_line );
}

# Remove non-transparent
system( "sh", "-c", "rm -f $config{OUT}/image/init_*" );

# Copy raw files over
system( "sh", "-c", "cp -a $config{IN_RAW}/* $config{OUT}" );

print "Finished.\n";



######################################################################
#
# write_html( $stem, $in, $out, $full_paths )
#
######################################################################

sub write_html
{
	my( $stem, $in, $out, $full_paths ) = @_;
	
	open TEMPLATEIN, $config{TEMPLATE}
		or die "Couldn't open template $config{TEMPLATE}\n";
	open HTMLIN, $in or die "Couldn't open $in\n";
	open HTMLOUT, ">$out" or die "Couldn't write to $out\n";
	
	# Get title
	my $title_line = <HTMLIN>;
	chomp( $title_line );
	$title_line =~ /^TITLE:\s*(.+)\s*$/;
	my $title = $1;
	die "No title in $in\n" unless( defined $title && $title ne "" );

	while( <TEMPLATEIN> )
	{
		# Simple substitutions
		s/TITLE_PLACEHOLDER/$title/g;
		s/SITE_ROOT/$config{SITEROOT}/g;
		s/HTML_ROOT/$config{HTMLROOT}/g;
		s/MAIN_FG/#$config{MAIN_FG}/g;
		s/MAIN_BG/#$config{MAIN_BG}/g;
		s/NAV_FG_HI/#$config{NAV_FG_HI}/g;
		s/NAV_FG_LO/#$config{NAV_FG_LO}/g;
		s/NAV_BG/#$config{NAV_BG}/g;


		if( /DATE_PLACEHOLDER/ )
		{
			my $datestr = &format_date( time );
			s/DATE_PLACEHOLDER/$datestr/g;
		}
		
		if( /MODIFIED_PLACEHOLDER/ )
		{
			my @info = stat HTMLIN;

			my $datestr = &format_date( $info[9] );
			s/MODIFIED_PLACEHOLDER/$datestr/g;
		}

		# Major substitutions
		if( /BODY_PLACEHOLDER/ )
		{
			# Pump in the body
			while( <HTMLIN> )
			{
				s%<ITEMS>%<TABLE>%ig;
				s%</ITEMS>%</TABLE>%ig;
				s%<ITEM>%'<TR><TD valign="top"><IMG src="'.$config{SITEROOT}.'image/jig'.(1+int rand 4).'.gif" width="32" height="32" alt="*"></TD><TD valign="top"><IMG src="'.$config{SITEROOT}.'image/white.gif" width="6" height="6"><BR>'%ieg;
				s%</ITEM>%</TD></TR>%ig;
				print HTMLOUT;
			}
		}
		elsif( /NAVIGATION_BAR/ )
		{
			&gen_nav_bar( \*HTMLOUT, $stem, $full_paths );
		}
		else
		{
			print HTMLOUT;
		}
	}

	close( TEMPLATEIN );
	close( HTMLIN );
	close( HTMLOUT );
}


######################################################################
#
# gen_nav_bar( $out_fh, $stem, $full_paths )
#
######################################################################

sub gen_nav_bar
{
	my( $htmlout, $current, $full_paths ) = @_;
	
	my $stem;
	my $first=1;

	foreach $stem (@icons)
	{
		my $icon_text = $nav_icon_text{$stem};
		my $icon_filename = "image/$stem";
		my $class = "sidebar";

		# Use the highlighted version if it's for the current page
		$icon_filename .= ".hi" if( $stem eq $current );
		$icon_filename .= ".gif";

		$class = "sidebarcurrent" if( $stem eq $current );

		# Print a separate if appropriate
		if( $first )
		{
			$first=0;
		}
		else
		{
			print $htmlout $config{NAV_SEPARATOR};
		}
	
		if( defined $urls{$stem} )
		{
			# This is an external URL
			$stem =~ s/SITE_ROOT/$config{SITEROOT}/gi;
			$stem =~ s/HTML_ROOT/$config{HTMLROOT}/gi;
			print $htmlout "<A class=\"$class\" HREF=\"$urls{$stem}\">";
		}
		elsif( $full_paths )
		{
			# For a normal page. We're using full paths.
			print $htmlout "<A class=\"$class\" HREF=\"$config{HTMLROOT}$stem.html\">" unless( $stem eq "index" );
			print $htmlout "<A class=\"$class\" HREF=\"$config{HTMLROOT}/\">" if( $stem eq "index" );
		}
		else
		{
			# Normal page. Can output a relative filename.
			if( $stem eq "index" ) {
				print $htmlout '<A class="'.$class.'" HREF="'.$config{HTMLROOT}.'">' ;
			} else {
				print $htmlout '<A class="'.$class.'" HREF="'.$stem.'.html">' ;
			}
		}

		# Now include the image itself, using full URL if appropriate.
		if( $full_paths )
		{
			#print $htmlout "<IMG SRC=\"$config{HTMLROOT}$icon_filename\" BORDER=0 ALT=\"$icon_text\">\n";
			print $htmlout $icon_text;
		}
		else
		{
			print $htmlout $icon_text;

		}
		print $htmlout "</A>\n";
	}
}


sub format_date
{
	my( $time ) = @_;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=gmtime( $time );
	$mon=("January","February","March","April","May","June","July","August","September","October","November","December")[$mon];
	$year=$year+1900;
	return( "$mday $mon $year" );
}

