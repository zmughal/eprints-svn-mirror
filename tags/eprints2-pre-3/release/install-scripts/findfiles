
# This perl script finds all the files, and only the files in a given directory.
#
# It has the same functionality as gnu find with the options -maxdepth 1 -type f
# but is (hopefully) more portable.
#
# Christopher Gutteridge (12/01/2001)

if (scalar @ARGV!=1) {
	print STDERR "Usage: perl findfiles.pl <directory>\n\n";
	exit 1;
}

$dir=$ARGV[0];
opendir(D,$dir); 
while( $f=readdir(D) ) 
{ 
	if ( -f "$dir/$f" ) 
	{
		print "$dir/$f\n"; 
	}
} 
closedir(D);
