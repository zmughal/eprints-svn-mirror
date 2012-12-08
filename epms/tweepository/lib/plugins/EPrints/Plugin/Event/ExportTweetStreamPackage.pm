package EPrints::Plugin::Event::ExportTweetStreamPackage;

use EPrints::Plugin::Event::LockingEvent;
@ISA = qw( EPrints::Plugin::Event::LockingEvent );

use File::Path qw/ make_path /;
use Archive::Zip;
use File::Copy;

use strict;

sub _initialise_constants
{
	my ($self) = @_;

	$self->{search_page_size} = 5000; #page size 
	$self->{json_records_per_file} = 10000;
	$self->{csv_rows_per_file} = 10000;

}

sub action_export_tweetstream_packages
{
	my ($self, @ids) = @_;

        $self->{log_data}->{start_time} = scalar localtime time;

	my $repo = $self->repository;

	if ($self->is_locked)
	{
		$self->repository->log( (ref $self) . " is locked.  Unable to run.\n");
		return;
	}
	$self->create_lock;

	$self->_initialise_constants();

	foreach my $id (@ids)
	{
		my $ts = $repo->dataset('tweetstream')->dataobj($id);
		next unless $ts;
		$self->export_single_tweetstream($ts);
	}

	$self->remove_lock;
        $self->{log_data}->{end_time} = scalar localtime time;
	$self->write_log;
}


sub action_export_queued_tweetstream_packages
{
	my ($self) = @_;

	my $repo = $self->repository;

	my $ds = $repo->dataset('tsexport');

	#tidy up after possible previos crash (set all 'running' to 'pending')
	my @exports = $ds->search( filters => [ {
                meta_fields => [qw( status )],
                value => 'running',
        },] )->get_records;
	foreach my $export(@exports)
	{
		$export->set_value('status','pending');
		$export->commit;
	}

	my $pending_count = $ds->search( filters => [ {
                meta_fields => [qw( status )],
                value => 'pending',
        },] )->count;

	return unless $pending_count >= 1; #just leave if there are no requests

        $self->{log_data}->{start_time} = scalar localtime time;

	if ($self->is_locked)
	{
		$self->repository->log( (ref $self) . " is locked.  Unable to run.\n");
		return;
	}
	$self->create_lock;

	$self->_initialise_constants();

	$self->export_requested_tweetstreams;

	$self->remove_lock;
        $self->{log_data}->{end_time} = scalar localtime time;
	$self->write_log;

}



sub export_requested_tweetstreams
{
	my ($self) = @_;

	my $repo = $self->repository;

	my $export_ds = $repo->dataset('tsexport');

	#process a maximum of 100 records in this run.  Leave more for the next run
	my @exports = $export_ds->search( filters => [ {
                meta_fields => [qw( status )],
                value => 'pending',
        },] )->get_records(0,100);

	my $done_timestamps = {};
	foreach my $export (@exports)
	{
		my $tsid = $export->value('tweetstream');
		if (!$done_timestamps->{$tsid})
		{
			$export->set_value('status','running');
			$export->commit();
			my $ts = $repo->dataset('tweetstream')->dataobj($tsid) if $tsid;
			if ($ts)
			{
				$self->export_single_tweetstream($ts);
			}
		}
		$done_timestamps->{$tsid} = EPrints::Time::get_iso_timestamp();
		#it either failed, succeeded or was a dupliate
		$export->set_value('status','finished');
		$export->set_value('date_completed',  $done_timestamps->{$tsid});
		$export->commit;
	}
}

sub export_single_tweetstream
{
	my ($self, $ts) = @_;

	my $repo = $self->repository;
	my $tsid = $ts->id;

	my $tmp_dir = File::Temp->newdir( "ep-ts-export-explodeXXXXX", TMPDIR => 1 );

	$self->extract_export_data($ts, $tmp_dir);

	my $final_dir = File::Temp->newdir( "ep-ts-export-implodeXXXXX", TMPDIR => 1 );


	$self->process_extracted_data($ts, $final_dir, $tmp_dir);

	my $final_filepath = $ts->export_package_filepath;
	unlink $final_filepath if -e $final_filepath;
	create_zip($final_dir, "tweetstream$tsid", $final_filepath );
}


#the tweet data is spread across a temporary tree on the filesystem.
#Collate this data.
sub process_extracted_data
{
	my ($self, $ts, $dest_dir, $src_dir) = @_;
	my $repo = $self->repository;

	my $xml = $ts->to_xml;
	open FILE, ">$dest_dir/tweetstream.xml" or die "couldn't open $dest_dir/tweetstream.xml for writing\n";
	binmode(FILE, ":utf8");
	print FILE $repo->xml->to_string($xml);
	close FILE;

	$self->traverse_source_tree($ts, $src_dir, $dest_dir);

}




sub create_zip
{
	my ($dir_to_zip, $dirname_in_zip, $zipfile) = @_;

	my $z = Archive::Zip->new();

	$z->addTree($dir_to_zip, $dirname_in_zip);
	$z->writeToFileNamed($zipfile);
}



sub process_file
{
	my ($self, $file, $filename, $data, $ts) = @_;

	if ($filename eq 'csv')
	{
		$data->{csv_count}++;
		if ($data->{csv_count} > $self->{csv_rows_per_file})
		{
			$data->{csv_page_no}++;
			$data->{csv_count} = 1; #reinitialise to one because this line comes after the increment.
			close $data->{csv_fh};
			$data->{csv_fh} = $self->create_fh('csv', $data->{base_dir}, $data->{csv_page_no});
			initialise_csv($data->{csv_fh}, $ts);
		}
		open FILE, $file or return; ##Again, I sould do exception handling
		print {$data->{csv_fh}} <FILE>;
	}
	if ($filename eq 'json')
	{
		open FILE, $file or return; ##Again, I sould do exception handling

		print {$data->{json_fh}} ",\n" if ($data->{json_count});
		print {$data->{json_fh}} <FILE>;
		$data->{json_count}++;

		if ($data->{json_count} > $self->{json_records_per_file})
		{
			$data->{json_page_no}++;
			$data->{json_count} = 0;

			print {$data->{json_fh}} "\n  ]\n}";

			close $data->{json_fh};
			$data->{json_fh} = $self->create_fh('json', $data->{base_dir}, $data->{json_page_no});
			initialise_json($data->{json_fh});
		}
	}

}

sub initialise_csv
{
	my ($fh, $ts) = @_;

	print $fh EPrints::Plugin::Export::TweetStream::CSV::csv_headings($ts);	
}

sub initialise_json
{
	my ($fh) = @_;

	print $fh "{\n  \"tweets\": [\n"; 
}



sub tweet_filepath
{
	my ($self, $tweet, $tmp_dir) = @_;

	return $tmp_dir . '/' . $self->twitterid_to_pathfrag($tweet->value('twitterid'));
}


sub twitterid_to_pathfrag
{
	my ($self, $twitterid) = @_;

	#Make the padding three or four digits longer just in case
	my $len = length($twitterid);

	$len += $len%3; #get it up to a multiple of 4
	$len += 3; #in case of overflow

	my $idstring = sprintf("%0${len}d",$twitterid);
        $idstring =~ s#(...)#/$1#g;
        substr($idstring,0,1) = '';

	return $idstring;
}


sub generate_log_string
{
	my ($self) = @_;

	my $l = $self->{log_data};

	my @r;

	push @r, '===========================================================================';
	push @r, '';
        push @r, "Export started at:        " . $l->{start_time};
	push @r, '';
	push @r, "Export finished at:       " . $l->{end_time};
	push @r, '';
	push @r, '===========================================================================';


	return join("\n", @r);
}

sub process_tweet
{
	my ($self, $tweet, $ts, $tmp_dir) = @_;

	my $path = $self->tweet_filepath($tweet, $tmp_dir);
	make_path($path);

	my $csv = EPrints::Plugin::Export::TweetStream::CSV::tweet_to_csvrow($tweet, $ts->csv_cols);
	
	open FILE, ">$path/csv" or die "couldn't open $path/csv for writing";
	binmode(FILE, ":utf8");
	print FILE $csv;
	close FILE;

	my $json = EPrints::Plugin::Export::TweetStream::JSON::tweet_to_json($tweet, 6, 0 ); 
	
	open FILE, ">$path/json" or die "couldn't open $path/json for writing";
	binmode(FILE, ":utf8");
	print FILE $json;
	close FILE;

}

#Tweets are not ordered by twitterid, and we'd like them to be -- there are performance issues with ordering them in the database.
#So, we'll run across the database and extract the data from each tweet and store it on the filesystem
#then we'll aggregate all the filesystem data in order into the final files
sub extract_export_data
{
	my ($self, $ts, $tmp_dir) = @_;
	my $repo = $self->repository;
	my $tweet_ds = $repo->dataset('tweet');

	my $high_id = 0;

	while (1)
	{
		$high_id++; #we've seen the item with high_id. let's not include it in our next search
	        my $search = $tweet_ds->prepare_search(limit => $self->{search_page_size}, custom_order => 'tweetid' );
	        $search->add_field($tweet_ds->get_field('tweetid'), $high_id . '-');
	        $search->add_field($tweet_ds->get_field('tweetstreams'), $ts->id);
	
	        my $results = $search->perform_search;

		last unless $results->count > 0;

		$results->map(sub {
			my ($repo, $ds, $tweet, $data) = @_;

			my $tweetid = $tweet->id;
			$high_id = $tweetid if $tweetid > $high_id;
			$self->process_tweet($tweet, $ts, $tmp_dir);
		});

		$results->DESTROY;
	}
}

sub create_fh
{
	my ($self, $type, $base_dir, $page) = @_;

	my $filename = $base_dir . '/tweets' . sprintf("%04d",$page) . ".$type";
	open(my $fh, ">", $filename) or die "cannot open $filename for writing: $!";

	return $fh;
}

sub traverse_source_tree
{
	my ($self, $ts, $src_dir, $dest_dir) = @_;

	my $data = {
		csv_count => 0,
		csv_page_no => 1,
		json_count => 0,
		json_page_no => 1,
		base_dir => $dest_dir,
	};
	$data->{csv_fh} = $self->create_fh('csv', $dest_dir, $data->{csv_page_no});
	$data->{json_fh} = $self->create_fh('json', $dest_dir, $data->{json_page_no});
	initialise_csv($data->{csv_fh}, $ts);
	initialise_json($data->{json_fh});

	$self->process_dir($src_dir, $data, $ts);

	#print the json file footer before closing the file
	print {$data->{json_fh}} "\n  ]\n}";
	close $data->{csv_fh};
	close $data->{json_fh};

}

sub process_dir
{
	my ($self, $dir, $data, $ts) = @_;
	$dir .= '/' unless $dir =~ m/\/$/;

	opendir (my $dir_h, $dir) or return; ##This shouldn't happen!  May need exception handling.
	my @contents = readdir($dir_h);

	foreach my $filename (sort @contents)
	{
		next if $filename =~ m/^\./;
		my $file = $dir . $filename;
		if (-d $file)
		{
			$self->process_dir($file, $data, $ts)
		}
		else
		{
			$self->process_file($file, $filename, $data, $ts);
		}
	}
	closedir $dir_h;

}

1;
