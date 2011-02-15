#!/bin/perl

use strict;
use File::stat;
use LWP::UserAgent;
use XML::XPath;

my $dir = $ARGV[0];

our $config = load_config($dir);
exit if (!defined $config);
my $items = get_resource_list();
my $items = undef;
my $update_counter = 0;

while (1) {
	process_directory($dir,0,$items);
	sleep(10);
	$update_counter++;
	if ($update_counter > 5) {
		$items = get_resource_list();
		$update_counter = 0;
	}
}

sub load_config {
	my $dir = shift;

	my $file = $dir . "CONFIG";
	
	if ( -e $file ) {
		
		my $resources = {};
		
		open(HANDLE,$file);
	
		while (<HANDLE>) {
			chomp;
			next if ((substr $_,0,1) eq "#");
			my @parts = split(/:/,$_,2);
			my $key = trim(@parts[0]);
			my $value = trim(@parts[1]);
			$resources->{$key} = $value;
		}

		close(HANDLE);

		return $resources;
	} 

	return undef;
}

sub get_resources {

	my $content_file = shift;

	if ( -e $content_file ) {

		my $resources = {};
	
		my @lines;
		
		open(HANDLE,$content_file);

		while (<HANDLE>) {
			chomp;
			push @lines, $_;
		}

		close(HANDLE);

		my $URI;
		foreach my $line(@lines) {
			my @parts = split(/:/,$line,2);
			$URI = trim(@parts[1]) if (@parts[0] eq "URI");
		}
		
		foreach my $line(@lines) {
			my @parts = split(/:/,$line,2);
			next if (@parts[0] eq "URI");
			$resources->{$URI}->{trim(@parts[0])} = trim(@parts[1]);
		}
	
		return $resources;
	} 

	return undef;
}

sub process_directory {

	my $dir = shift;
	my $depth = shift;
	my $items = shift;

	#print "No items defined in repo\n" if (!defined $items);
	
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

	if (defined $parent_uri) {
		my $edit_uri = $resources->{$parent_uri}->{"Edit-URI"};
		my ($server_file_modified,$server_file_md5,$status_code) = head_uri($edit_uri,"application/atom+xml");
		my $file = $dir . "METADATA.xml";
		if ( -e $file ) {
			my ($local_file_modified, $local_file_md5) = local_info($file);
#print STDERR "local: $local_file_modified $local_file_md5 \n";
#print STDERR "remote: $server_file_modified $server_file_md5 \n";
			if (defined $server_file_md5) {
				if (!($local_file_md5 eq $server_file_md5) and ($local_file_modified > $server_file_modified)) {
					put_file_to_uri($file,"METADATA.xml",$edit_uri,"application/atom+xml");
				} elsif (!($local_file_md5 eq $server_file_md5) and ($local_file_modified < $server_file_modified)) {
					get_file_from_uri($file,$edit_uri,"application/atom+xml");
				}
			}
		} elsif ($status_code == 200) {
			get_file_from_uri($file,$edit_uri,"application/atom+xml");
		}
	}

	my $repo_docs = $items->{$parent_uri}->{"documents"};

	foreach my $file (readdir(DIR)) {

		my $file_name = $file;


		next if ($file_name eq ".parent_uri");
		next if ($file_name eq ".config");
		next if (substr($file_name,0,9) eq "VIEW_ITEM");
		next if (substr($file_name,0,8) eq "METADATA");
		next if ($file_name eq "CONFIG");

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
				$repo_docs->{$uri} = undef;
			}
		}
		
		next if ((substr $file_name,0,1) eq ".");
	
		$file = $dir . $file;	

		#my $path = $dir . "." . $file_name . "\n";
		#print "PROCESSING: $path \n";
	
		if ( -d $file ) {
			$depth++;
			process_directory($file.'/',$depth,$items);	
		} elsif ( -e ($dir . "." . $file_name) ) {
			my $uri;
			my $resources = get_resources($dir . "." . $file_name);
			foreach my $key(keys %$resources) {
				if ((substr $key,0,4) eq "http") {
					$uri = $key;
				}
			}	
			$repo_docs->{$uri} = undef;
			#See if file exists in eprints and is up to date.
			my ($server_file_modified, $server_file_md5, $status_code) = head_uri($uri);
			if ($status_code == 404 or $status_code == 410) {
				unlink($file);
				unlink($dir . "." . $file_name);
			} else {
				my ($local_file_modified, $local_file_md5) = local_info($file);
				if (defined $server_file_md5) {
					if (!($local_file_md5 eq $server_file_md5) and ($local_file_modified > $server_file_modified)) {
						put_file_to_uri($file,$file_name,$uri,undef);
					} elsif (!($local_file_md5 eq $server_file_md5) and ($local_file_modified < $server_file_modified)) {
						get_file_from_uri($file,$uri,undef);
					}
					
				}
			}
			#If it is out of date or not uploaded, upload it. 
			#print "Found the file\n";
		} else {
			deposit_file($file,$file_name,$parent_uri);
		}
	}
	foreach my $remainder(keys %$repo_docs) {
		if (defined $repo_docs->{$remainder}) {
			print $remainder . " is only in repo\n";
			my $filename = $repo_docs->{$remainder}->{"filename"};
			my $file = $dir . $filename;
			get_file_from_uri($file,$remainder,undef);
			write_uris_to_file($filename,$file,$remainder,$parent_uri,undef);
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

sub get_uris_from_atom {
	my $content = shift;
	
	my $eprint_uri; 
	my $media_uri;
	my $edit_uri;
		
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
		if ($attr eq "edit") {
			$edit_uri = $node->getAttribute("href");
		}
	}

	# if $eprint_uri is not defined it's a feed!!!!

	if (!defined $eprint_uri) {
		$nodeset = $xp->find('/feed/entry/id'); 

		foreach my $node ($nodeset->get_nodelist) {
			$media_uri = $node->string_value;
		}
	}
	
	return ($eprint_uri,$media_uri,$edit_uri);
	
}

sub local_info {
	
	my $file = shift;

	my $local_modified = stat($file)->mtime;
	my $local_md5 = md5sum($file);	
	
	return ($local_modified,$local_md5);

}

sub get_user_agent {

	my $realm = shift;
	$realm = $config->{realm} if (!defined $realm);
	
	my $ua = LWP::UserAgent->new();

	$ua->credentials(
			$config->{host},
			"$realm",
			$config->{username} => $config->{password}
			);

	return $ua;

}

sub head_uri {
	
	my $uri = shift;
	my $content_type = shift;

	my $ua = get_user_agent(undef);

	my $h;
	my $req;

	if (defined $content_type) {
		$h = HTTP::Headers->new(Accept => "application/atom+xml");
		$req = HTTP::Request->new( HEAD => $uri, $h );
	} else {
		$req = HTTP::Request->new( HEAD => $uri );
	}

	my $res = $ua->request($req);
	
	my $last_modified = undef;
	my $content_md5 = undef;
	my $status_code = undef;

	$status_code = $res->code;
	if ($res->is_success) {
		$last_modified = $res->header("Last-Modified");
		$content_md5 = $res->header("ETag");
	}
	
	if (defined $last_modified && $last_modified ne "") {
		$last_modified = utc_to_epoch($last_modified);
	}
	
	chomp $content_md5;	
	
	return($last_modified,$content_md5,$status_code);
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

	my $realm = 'SWORD';
	
	print "Attempting to delete $uri\n";

	my $ua = get_user_agent($realm);

	my $req = HTTP::Request->new( DELETE => $uri );

	my $res = $ua->request($req);

	return 1 if ($res->is_success); 
	
	print $res->status_line;
	print "\n";
	print $res->content;

}

sub get_file_from_uri {
	
	my $file = shift;
	my $uri = shift;
	my $accept_type = shift;

	print "Attempting to get $file from $uri\n";

	my $ua = get_user_agent(undef);

	open(FILE, ">", "$file" ) or die('cant open input file');
	binmode FILE;

	my $h;
	my $req;

	if (defined $accept_type) {
		$h = HTTP::Headers->new(Accept => $accept_type);
		$req = HTTP::Request->new( GET => $uri, $h );
	} else {
		$req = HTTP::Request->new( GET => $uri );
	}

	my $file_handle = "";

	# Et Zzzzooo!
	my $res = $ua->request($req);	
	
	
	if ($res->is_success) {
		open(FILE,">$file");
		print FILE $res->content;
		close(FILE);
		return 1;
	}
	
	print $res->status_line;
	print "\n";
	print $res->content;

}

sub put_file_to_uri {
	
	my $file = shift;
	my $filename = shift;
	my $uri = shift;
	my $mime_type = shift;

	print "Attempting to put $file to $uri\n";

	open(FILE, "$file" ) or die('cant open input file');
	binmode FILE;

	my $realm = "SWORD";
	my $ua = get_user_agent($realm);

	my $req = HTTP::Request->new( PUT => $uri );

	# Tell SWORD to process the XML file as EPrints XML
	#$req->header( 'X-Packaging' => 'http://eprints.org/ep2/data/2.0' );
	$req->header( 'Content-Disposition' => 'form-data; name="'.$filename.'"; filename="'.$filename.'"');
	#$req->header( 'X-Extract-Media' => 'true' );
	#$req->header( 'X-Override-Metadata' => 'true' );
	#$req->header( 'X-Extract-Archive' => 'true' );

	use MIME::Types qw(by_suffix by_mediatype);

	my $encoding;
	if (!defined $mime_type) {
		($mime_type,$encoding) = by_suffix($file);
	}

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

	# collection end point:
	my $sword_url = $url;
	if (!defined $url) {
		$sword_url = $config->{sword_url};
	}

	# credentials:
	my $realm = 'SWORD';

	open(FILE, "$filepath" ) or die('cant open input file');
	binmode FILE;

	my $ua = get_user_agent($realm);

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
		my ($eprint_uri,$media_uri,$edit_uri) = get_uris_from_atom($content);
		if (!defined $eprint_uri) {
			$eprint_uri = $url;
		}
		write_uris_to_file($filename,$filepath,$media_uri,$eprint_uri,$edit_uri);
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
	my $edit_uri = shift;

#	print $filename . " : " . $full_path . " : " . $media_uri . " : " . $parent_uri . "\n\n"; 

	my $file_last_modified = stat($full_path)->mtime;
	my $path = substr($full_path,0, 0 - length($filename));
	my $file_index = $path . "." . $filename;
	my $parent_file = $path . ".parent_uri";
	my $parent_mtime = stat($path)->mtime;
	
	if ( -e $parent_file ) {
		my $resources = get_resources($parent_file);
		if (!defined $edit_uri) {
			$edit_uri = $resources->{$parent_uri}->{"Edit-URI"};
		}
	}

	open (FILE,">$file_index");
	print FILE "URI: $media_uri\nLast-Modified: $file_last_modified\n";
	close (FILE);
	
	open(FILE,">$parent_file");
	print FILE "URI: $parent_uri\nLast-Modified: $parent_mtime\nEdit-URI: $edit_uri\n";
	close(FILE);

	my $html_file = $path . "VIEW_ITEM.HTML";
	open(FILE,">$html_file");
	print FILE '
<html><head>
<meta http-equiv="REFRESH" content="0;url='.$parent_uri.'"/>
</head>
<body style="margin: 7em;">
<div align="center">
<a href="'.$parent_uri.'">Click here if you are not automatically redirected</a>
</div>
</body>
</html>
';
	close(FILE);
}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub get_resource_list {
	
	my $uri = "http://" . $config->{host} . "/id/records";

	print "Attempting to get $uri\n";

	my $ua = get_user_agent(undef);

	my $h = HTTP::Headers->new(Accept => "application/atom+xml");
	my $req = HTTP::Request->new( GET => $uri, $h );

	my $items;

	# Et Zzzzooo!
	my $res = $ua->request($req);	
	
	if ($res->is_success) {
		my $content = $res->content;
		
		my $xp = XML::XPath->new(xml=>$content);
	
		my $nodeset = $xp->find('/feed/entry'); 
		foreach my $node ($nodeset->get_nodelist) {
			my $eprint_id;	
			my $sub_nodeset = $xp->find('id',$node);
			foreach my $sub_node ($sub_nodeset->get_nodelist) {
				$eprint_id = $sub_node->string_value;
#print "FOUND: " . $sub_node->string_value . "\n";
			}
			my $sub_nodeset = $xp->find('title',$node);
			foreach my $sub_node ($sub_nodeset->get_nodelist) {
				$items->{$eprint_id}->{"title"} = $sub_node->string_value;
#print "TITLE: " . $sub_node->string_value . "\n";
			}
			my $sub_nodeset = $xp->find('link',$node);
			foreach my $sub_node ($sub_nodeset->get_nodelist) {
				my $attr = $sub_node->getAttribute("rel");
				if ($attr eq "contents") {
					$items->{$eprint_id}->{"contents"} = $sub_node->getAttribute("href");
#print $sub_node->getAttribute("href") . "\n";
				}
			}
		}
	}
	
	if (!defined $items) {
		print $res->status_line;
		print "\n";
		print $res->content;
		return undef;
	}


	foreach my $eprint_id(keys %$items) {
		my $uri = $items->{$eprint_id}->{"contents"};
		my $req = HTTP::Request->new( GET => $uri, $h );
		# Et Zzzzooo!
		my $res = $ua->request($req);	

		next if (!($res->is_success));

		my $documents;
		
		my $content = $res->content;
		
		my $xp = XML::XPath->new(xml=>$content);
	
		my $nodeset = $xp->find('/feed/entry'); 
		foreach my $node ($nodeset->get_nodelist) {
			my $doc_id;	
			my $sub_nodeset = $xp->find('id',$node);
			foreach my $sub_node ($sub_nodeset->get_nodelist) {
				$doc_id = $sub_node->string_value;
#print "FOUND: " . $sub_node->string_value . "\n";
			}
			my $sub_nodeset = $xp->find('title',$node);
			foreach my $sub_node ($sub_nodeset->get_nodelist) {
				$documents->{$doc_id}->{"title"} = $sub_node->string_value;
#print "TITLE: " . $sub_node->string_value . "\n";
			}
			my $sub_nodeset = $xp->find('link',$node);
			foreach my $sub_node ($sub_nodeset->get_nodelist) {
				my $attr = $sub_node->getAttribute("rel");
				if ($attr eq "alternate") {
					my $filename = $sub_node->getAttribute("href");
					$filename = substr $filename, rindex($filename,"/")+1,length($filename);
					$documents->{$doc_id}->{"filename"} = $filename;
#print "Adding doc $doc_id with filename $filename\n";
				}
			}
		}
		$items->{$eprint_id}->{"documents"} = $documents;
	}
		
	my $documents = $items->{"http://yomiko.ecs.soton.ac.uk:8027/id/eprint/154"}->{"documents"};
	return $items;
	
	print $res->status_line;
	print "\n";
	print $res->content;

}