#!/usr/bin/perl -w

if( $#ARGV != 2 )
{
	print STDERR
		"Usage: insert_license.pl <license-file> <version-info> <source_file>\n";
	exit( 1 );
}

my( $license_file, $version_info, $source_file ) = @ARGV;

my @license_text;

open LICENSE, $license_file or die "Couldn't open license file.\n";

while( <LICENSE> )
{
	chomp();
	s/__VERSION__/$version_info/g;
	push @license_text, "# $_";
}

close LICENSE;

open IN, $source_file or die "Couldn't open file to add license.\n";

my $perms = (stat IN)[2];

open OUT, ">$source_file.out" or die "Couldn't open output file.\n";

while( <IN> )
{
	chomp();
	
	if( /__LICENSE__/ )
	{
		# Replace with license text
		foreach (@license_text)
		{
			print OUT "$_\n";
		}
	}
	else
	{
		print OUT "$_\n";
	}
}

close OUT;
close IN;

system( "mv", "$source_file.out", "$source_file" );

chmod $perms, $source_file;

exit( 0 );
