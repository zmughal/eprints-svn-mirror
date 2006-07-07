#!/usr/bin/perl


my $dir = "/";
my $fmt = "\0" x 512;

# try with statvfs..
my $statvfs = eval {  
	{
		package main;
		require "sys/syscall.ph";
	}
	my $res = syscall (&main::SYS_statvfs, $dir, $fmt) ;
	$res == 0;
};
if( $statvfs )
{
	print "stavfs\n";
	exit 1;
}

# try with statfs..
my $statfs =  eval { 
	{
		package main;
		require "sys/syscall.ph";
	}	
	my $res = syscall (&main::SYS_statfs, $dir, $fmt);
	$res == 0;
};
if( $statfs )
{
	print "statfs\n";
	exit 1;
}

print "none\n";
exit 1;
