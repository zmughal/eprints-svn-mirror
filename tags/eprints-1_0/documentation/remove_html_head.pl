#!/usr/bin/perl -w

my $in_body = 0;

while( <> )
{
	chomp();
	
	if( $in_body )
	{
		if( /<\/BODY>/ )
		{
			$in_body = 0;
		}
		else
		{
			print;
			print "\n";
		}
	}
	else
	{
		if( /<BODY/ )
		{
			$in_body = 1;
		}
	}
}
