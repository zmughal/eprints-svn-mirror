package ISSVerify;

use strict;

sub setupDir
{
	my( $dir, $mode ) = @_;

	return if( -d $dir );

	return if( mkdir( $dir, $mode ) );
		
	print "Error: Cannot create $dir ($!)\n\n";
	exit 1;
}

sub findCommand
{
	my( $cmd ) = @_;

	my $found;
	foreach( split /:/, $ENV{PATH} )
	{
		my $try = "$_/$cmd";
		$found = $try if( -x $try );
	}
	print "Location of $cmd? [$found] ";
	my $input = <STDIN>;
	chomp $input;
	if( $input eq '' ) { $input = $found; }
	unless( -x $input )
	{
		print "Error: $input does not exist or is not executable\n\n";
		exit 1;
	}
	return $input;
}

sub verifySig
{
	my( $conf, $sig, $content ) = @_;

	my $basiccmd = $conf->{OPENSSL}.' smime -verify -in "'.$sig.'" -content "'.$content.'" -inform der -CApath '.$conf->{RCDIR}.'/CACerts ';
	my $cmd = $basiccmd.' >/dev/null 2>&1';
	if( $conf->{DEBUG} ) { print STDERR "ISSVerify: $cmd\n"; }
	system $cmd;
	my $exit_v = $? >> 8;

	if( $exit_v != 0 )
	{
		my $cmd = $basiccmd.' -out /dev/null 2>&1';
		if( $conf->{DEBUG} ) { print STDERR "ISSVerify: $cmd\n"; }
		open( OS, "$cmd|" );
		my $line = <OS>;
		chomp $line;
		my $error = "$line - Verify Failed\n";
		if( $line =~ m/^Verification failure/ )
		{
			$line = <OS>;
			chomp $line;
			my @a = split( /:/, $line );
			if( !defined $a[9] || $a[9] eq "" ) { $a[9] = "Verify Failed"; }
			$error = $a[2].':'."\U$a[5]".' - '.$a[9].' for document "'.$content.'"'."\n";
			#if($a[2] == "21071065") { #Digest Error }
			#if($a[2] == "21075075") { #Bad Local Cert }
		}
		close OS;
		return { error=>$error };
	}

	my $info = {};
	$cmd = $basiccmd.' -pk7out | '.$conf->{OPENSSL}.' pkcs7 -print_certs -text -noout'; 
	if( $conf->{DEBUG} ) { print STDERR "ISSVerify: $cmd\n"; }
	open( OS, "$cmd|" );
	while( <OS> )
	{
		chomp;
		if( s/^\s*Subject://i )
		{ 
			$info->{subject} = studyLine( $_ ); 
		}
		if( s/^\s*Issuer://i )
		{ 
			$info->{issuer} = studyLine( $_ ); 
		}
	}
	close OS;

	$cmd = $conf->{OPENSSL}.' asn1parse -inform DER -in '.$sig;
	if( $conf->{DEBUG} ) { print STDERR "ISSVerify: $cmd\n"; }
	open( OS, "$cmd|" );
	while( <OS> )
	{
		if( m/signingTime/ )
		{
			$_ = <OS>;
			$_ = <OS>;
			chomp;
			m/:(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
			$info->{signtime} = {
				year => 2000+$1,
				month => $2,
				day => $3,
				hours => $4,
				mins => $5,
				secs => $6 };
			last;
		}
	}
	close( OS );

	return $info;
}

sub studyLine
{
	my( $line ) = @_;

	my $d = {};

	foreach( split /\s*,\s*/, $line ) 
	{
		m/^\s*([^=]+)=([^=]*)\s*$/;
		$d->{$1} = $2;
	}

	return $d;
}


sub getVerifyConf
{
	my $rcdir = $ENV{HOME}.'/.ISSDigiSign';
	my $rc_changed = 1;

	# Now find out where openssl is
	my $conf = { OPENSSL => "" };
	if( open( RC, "$rcdir/rc" ) )
	{
		foreach( <RC> )
		{ 
			chomp;
			m/^([^=]+)=(.*)$/;
			$conf->{$1} = $2;
		}
		$rc_changed = 0;
	}
	
	if( !defined $conf->{OPENSSL} || !-x $conf->{OPENSSL} )
	{
		$rc_changed = 1;
		$conf->{OPENSSL} = findCommand( 'openssl' );
	}
	
	setupDir( $rcdir );
	setupDir( $rcdir.'/CACerts' );
	setupDir( $rcdir.'/PersonalCerts', 0700 );
	
	if( $rc_changed )
	{
		open( RC, ">$rcdir/rc" ) || die( "Can't write rc file" );
		foreach( sort keys %{$conf} )
		{
			print RC $_.'='.$conf->{$_}."\n";
		}
	}

	$conf->{RCDIR} = $rcdir;

	return $conf;
}

1;
