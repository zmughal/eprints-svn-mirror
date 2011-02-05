#!/bin/perl

use strict;
use File::stat;

my $dir = $ARGV[0];

while (1) {
	process_directory($dir,0);
	sleep(10);
}

sub get_resources {

	my $content_file = shift;

	if ( -e $content_file ) {

		my $resources = {};

		my @res_temp = get_associations($content_file);

		foreach my $resource(@res_temp) {
			my @parts = split(/ /,$resource);
			$resources->{@parts[0]} = @parts[1];
			$resources->{@parts[1]} = @parts[0];
		}

		return $resources;
	} 

	return undef;
}

sub process_directory {

	my $dir = shift;
	my $depth = shift;
	
	my $parent_uri = undef;
	my $resources = {};

	opendir(DIR, $dir);
	
	if ( -e $dir . ".parent_uri" ) {
		$resources = get_resources($dir . ".parent_uri");
	}
	
	foreach my $key (keys %$resources) {
		if ((substr $key,0,4) eq "http") {
			$parent_uri = $key;
		}
	}

	#print "PARENT URI = " . $parent_uri;

	foreach my $file (readdir(DIR)) {

		my $file_name = $file;

		next if ($file_name eq ".parent_uri");

		# Delete files on server which have been removed locally
		if ((substr $file_name,0,1) eq ".") {
			my $normal_file = substr $file_name,1;
			next if ( -e $dir . $normal_file );
			my $uri;
			my $resources = get_resources($dir . $file_name);
			foreach my $key(keys %$resources) {
				if ((substr $key,0,4) eq "http") {
					$uri = $key;
				}
			}	
			if (delete_uri($uri)) {
				unlink($dir . $file_name);
			}
		}
		
		next if ((substr $file_name,0,1) eq ".");
	
		$file = $dir . $file;	

		#my $path = $dir . "." . $file_name . "\n";
		#print "PROCESSING: $path \n";
	
		if ( -d $file ) {
			$depth++;
			process_directory($file.'/',$depth);	
		} elsif ( -e ($dir . "." . $file_name) ) {
			my $uri;
			my $resources = get_resources($dir . "." . $file_name);
			foreach my $key(keys %$resources) {
				if ((substr $key,0,4) eq "http") {
					$uri = $key;
				}
			}	
			#See if file exists in eprints and is up to date.
			my ($server_file_modified, $server_file_md5) = head_uri($uri);
			my ($local_file_modified, $local_file_md5) = local_info($file,$dir . "." . $file_name);
			if (defined $server_file_md5) {
				if (!($local_file_md5 eq $server_file_md5) and ($local_file_modified > $server_file_modified)) {
					put_file_to_uri($file,$file_name,$uri);
				} elsif (!($local_file_md5 eq $server_file_md5) and ($local_file_modified > $server_file_modified)) {
					print "Version of server is newer\n";
				}
				
			}
			#If it is out of date or not uploaded, upload it. 
			#print "Found the file\n";
		} else {
			deposit_file($file,$file_name,$parent_uri);
		}
	}

	closedir(DIR);
}


sub md5sum {
	my $file = shift;
	use Digest::MD5;
	my $digest = "";
	eval{
		open(FILE, $file) or die "[ERROR] md5sum: Can't find file $file\n";
		my $ctx = Digest::MD5->new;
		$ctx->addfile(*FILE);
		$digest = $ctx->hexdigest;
		close(FILE);
	};
	if($@){
		print $@;
		return "";
	}
	return $digest;
}


sub get_associations {
	
	my $file = shift;

	my @associations = ();

	open(HANDLE,$file);

	while (<HANDLE>) {
		chomp;
		push @associations, $_;
	}

	close(HANDLE);

	return @associations;

}

sub get_uris_from_atom {
	my $content = shift;
	
	use XML::XPath;
	
	my $eprint_uri; 
	my $media_uri;
		
	my $xp = XML::XPath->new(xml=>$content);
	
	my $nodeset = $xp->find('/atom:entry/atom:id'); 
	foreach my $node ($nodeset->get_nodelist) {
		$eprint_uri = $node->string_value;
	}
	
	$nodeset = $xp->find('/atom:entry/atom:link'); 

	foreach my $node ($nodeset->get_nodelist) {
		my $attr = $node->getAttribute("rel");
		if ($attr eq "edit-media") {
			$media_uri = $node->getAttribute("href");
		}
	}

	# if $eprint_uri is not defined it's a feed!!!!

	if (!defined $eprint_uri) {
		$nodeset = $xp->find('/feed/entry/id'); 

		foreach my $node ($nodeset->get_nodelist) {
			$media_uri = $node->string_value;
			#print "MEDIA: " . $media_uri;
		}
	}
	
	return ($eprint_uri,$media_uri);
	
}

sub local_info {
	
	my $file = shift;

	my $local_modified = stat($file)->mtime;
	my $local_md5 = md5sum($file);	
	
	return ($local_modified,$local_md5);

}

sub head_uri {
	
	my $uri = shift;

	use LWP::UserAgent;

	# credentials:
	my $username = 'admin';
	my $password = 'depositmo';
	my $realm = 'Authenticate';
	my $host = 'depositmo.eprints.org:80';

	my $ua = LWP::UserAgent->new();

	$ua->credentials(
			"$host",
			"$realm",
			"$username" => "$password"
			);

	my $req = HTTP::Request->new( HEAD => $uri );

	my $res = $ua->request($req);
	
	my $last_modified = undef;
	my $content_md5 = undef;

	if ($res->is_success) {
		$last_modified = $res->header("Last-Modified") . "\n";
		$content_md5 = $res->header("ETag") . "\n";
	}
	chomp $last_modified;

	$last_modified = utc_to_epoch($last_modified);
	
	chomp $content_md5;	
	
	return($last_modified,$content_md5);
}

sub utc_to_epoch {
	
	my $timestring = shift;
	use Time::Local;
	my @elements = split / /,$timestring;
	my @timebits = split /:/,@elements[4];
	my $sec = @timebits[2];
	my $min = @timebits[1];
	my $hour = @timebits[0];
	my $day = @elements[1];
	my $month;
	$month = 0 if (@elements[2] eq "Jan"); 
	$month = 1 if (@elements[2] eq "Feb"); 
	$month = 2 if (@elements[2] eq "Mar"); 
	$month = 3 if (@elements[2] eq "Apr"); 
	$month = 4 if (@elements[2] eq "May"); 
	$month = 5 if (@elements[2] eq "Jun"); 
	$month = 6 if (@elements[2] eq "Jul"); 
	$month = 7 if (@elements[2] eq "Aug"); 
	$month = 8 if (@elements[2] eq "Sep"); 
	$month = 9 if (@elements[2] eq "Oct"); 
	$month = 10 if (@elements[2] eq "Nov"); 
	$month = 11 if (@elements[2] eq "Dec"); 
	my $year = @elements[3];
	
	my $date = timelocal($sec,$min,$hour,$day,$month,$year);
	
	return $date;	
}


sub delete_uri {
	
	my $uri = shift;

	use LWP::UserAgent;

	# credentials:
	my $username = 'admin';
	my $password = 'depositmo';
	my $realm = 'SWORD';
	my $host = 'depositmo.eprints.org:80';

	my $ua = LWP::UserAgent->new();

	$ua->credentials(
			"$host",
			"$realm",
			"$username" => "$password"
			);

	my $req = HTTP::Request->new( DELETE => $uri );

	my $res = $ua->request($req);
	
	return 1 if ($res->is_success); 
	
	print $res->status_line;
	print "\n";
	print $res->content;

}

sub put_file_to_uri {
	
	my $file = shift;
	my $filename = shift;
	my $uri = shift;

	print "Attempting to put $file to $uri\n";

	use LWP::UserAgent;

	# credentials:
	my $username = 'admin';
	my $password = 'depositmo';
	my $realm = 'SWORD';
	my $host = 'depositmo.eprints.org:80';

	open(FILE, "$file" ) or die('cant open input file');
	binmode FILE;

	my $ua = LWP::UserAgent->new();

	$ua->credentials(
			"$host",
			"$realm",
			"$username" => "$password"
			);

	my $req = HTTP::Request->new( PUT => $uri );

	# Tell SWORD to process the XML file as EPrints XML
	#$req->header( 'X-Packaging' => 'http://eprints.org/ep2/data/2.0' );
	$req->header( 'Content-Disposition' => 'form-data; name="'.$filename.'"; filename="'.$filename.'"');
	#$req->header( 'X-Extract-Media' => 'true' );
	#$req->header( 'X-Override-Metadata' => 'true' );
	#$req->header( 'X-Extract-Archive' => 'true' );

	use MIME::Types qw(by_suffix by_mediatype);

	my ($mime_type,$encoding) = by_suffix($file);
	$req->content_type( $mime_type );

	my $file_handle = "";
	while(<FILE>) { $file_handle .= $_; }

	$req->content( $file_handle );

	# Et Zzzzooo!
	my $res = $ua->request($req);	
	
	close(FILE);
	
	return 1 if ($res->is_success);
	
	print $res->status_line;
	print "\n";
	print $res->content;

}

sub deposit_file {
	
	my $filepath = shift;
	my $filename = shift;
	my $url = shift;

	print "Attempting to post $filepath to $url\n";

	use LWP::UserAgent;

	# collection end point:
	my $sword_url = $url;
	if (!defined $url) {
		$sword_url = "http://depositmo.eprints.org/sword-app/deposit/inbox";
	}

	# credentials:
	my $username = 'admin';
	my $password = 'depositmo';
	my $realm = 'SWORD';
	my $host = 'depositmo.eprints.org:80';

	open(FILE, "$filepath" ) or die('cant open input file');
	binmode FILE;

	my $ua = LWP::UserAgent->new();

	$ua->credentials(
			"$host",
			"$realm",
			"$username" => "$password"
			);

	my $req = HTTP::Request->new( POST => $sword_url );

	# Tell SWORD to process the XML file as EPrints XML
	#$req->header( 'X-Packaging' => 'http://eprints.org/ep2/data/2.0' );
	$req->header( 'Content-Disposition' => 'form-data; name="'.$filename.'"; filename="'.$filename.'"');
	$req->header( 'X-Extract-Media' => 'true' );
	$req->header( 'X-Override-Metadata' => 'true' );
	#$req->header( 'X-Extract-Archive' => 'true' );

	use MIME::Types qw(by_suffix by_mediatype);

	my ($mime_type,$encoding) = by_suffix($filepath);
	$req->content_type( $mime_type );

	my $file = "";
	while(<FILE>) { $file .= $_; }

	$req->content( $file );

	# Et Zzzzooo!
	my $res = $ua->request($req);	
	
	close(FILE);

	if ($res->is_success) 
	{
		my $content = $res->content;
		my ($eprint_uri,$media_uri) = get_uris_from_atom($content);
		if (!defined $eprint_uri) {
			$eprint_uri = $url;
		}
		write_uris_to_file($filename,$filepath,$media_uri,$eprint_uri);
	}
	else 
	{
		print $res->status_line;
		print "\n";
		print $res->content;
	}


}

sub write_uris_to_file {

	my $filename = shift;
	my $full_path = shift;
	my $media_uri = shift;
	my $parent_uri = shift;

	#print $filename . " : " . $full_path . " : " . $media_uri . " : " . $parent_uri . "\n\n"; 

	my $file_last_modified = stat($full_path)->mtime;
	my $path = substr($full_path,0, 0 - length($filename));
	my $file_index = $path . "." . $filename;
	my $parent_file = $path . ".parent_uri";
	my $parent_mtime = stat($path)->mtime;

	open (FILE,">$file_index");
	print FILE "$file_last_modified $media_uri\n";
	close (FILE);
	
	open(FILE,">$parent_file");
	print FILE "$parent_mtime $parent_uri\n";
	close(FILE);
}
