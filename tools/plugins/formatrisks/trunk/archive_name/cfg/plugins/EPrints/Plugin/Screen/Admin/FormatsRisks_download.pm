package EPrints::Plugin::Screen::Admin::FormatsRisks_download;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new {
	my( $class, %params ) = @_;
 	
	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ get_files /];

	$self->{appears} = [
	{
		place => "admin_actions",
		      position => 1240,
		      action => "get_files",
	},
		];

	return $self;
}

sub action_get_files {
	my ( $self ) = @_;

	my $format = $self->{session}->param( "format" );
	my $count = $self->{session}->param( "count" );

	my $session = $self->{session};
	my $dataset = $session->get_repository->get_dataset( "file" );	

	my $searchexp = EPrints::Search->new( 
			session => $session, 
			dataset => $dataset,
			custom_order => "filesize", 
			filters => [ 
			{ meta_fields => [qw( datasetid )], value => "document" }, 
			{ meta_fields => [qw( pronomid )], value => "$format", match => "EX" }, 
			], 
			); 

	my $list = $searchexp->perform_search; 
	if ($count > $list->count) {
		$count = $list->count;
	}
	my @files = ();
	if ($count > 1) {
		@files = push_top_to_array($session,\@files,$list);
		reverse($list);
		@files = push_top_to_array($session,\@files,$list);
	}
	my $done = @files;
	if (($count - $done) > 1) {
		my $searchexp = EPrints::Search->new( 
			session => $session, 
			dataset => $dataset,
			custom_order => "mtime", 
			filters => [ 
			{ meta_fields => [qw( datasetid )], value => "document" }, 
			{ meta_fields => [qw( pronomid )], value => "$format", match => "EX" }, 
			], 
			); 

		my $list = $searchexp->perform_search; 
		@files = push_top_to_array($session,\@files,$list);
		reverse($list);
		@files = push_top_to_array($session,\@files,$list);
	}
	
	my @ids = List::Util::shuffle(@{$list->get_ids});
	$list = EPrints::List->new(
		session => $session,
		dataset => $dataset,
		ids => \@ids );
	while ($done < $count) {
		my $runner = 1;
		$list->map( sub {  
			my $file = $_[2];        
			my $local_copy = $file->get_local_copy();
			$runner++;
			});

		@files = push_top_to_array($session,\@files,$list);
		$done = @files;
	}

	my $zip_executable = $self->{session}->get_repository->get_conf('executables','zip');
	my $tmpfile = File::Temp->new( SUFFIX => ".zip" );
	unlink($tmpfile);
	my $cmd = "zip -j $tmpfile";
	foreach my $file_path (@files) {
		$cmd = $cmd . " " . $file_path;
	}
	system($cmd);
	my $result = 1;
	if ( !-s "$tmpfile" )
	{
		$result = 0;
	}
	if ($result ==1) 
	{
		seek($tmpfile, 0, 0);
		$self->{processor}->{tarball} = $tmpfile;
	} else {
		$self->{processor}->add_message(
				"error",
				$self->html_phrase( "Failed" )
				);
		$self->{processor}->{screenid} = "Admin::FormatsRisks";
	}

}

sub push_top_to_array
{
	my( $session, $files, $list) = @_;

	my $running = 1;
	$list->map( sub {  
		my $file = $_[2];        
		my $local_copy = $file->get_local_copy();
		if ($running == 1) {
			if (!in_array($files,$local_copy)) {
				push(@{$files},$local_copy);
				$running++;
			}
		}
	} );

	return @{$files};
	
}

sub in_array
{
     my ($arr,$search_for) = @_;
     my %items = map {$_ => 1} @{$arr}; # create a hash out of the array values
     return (exists($items{$search_for}))?1:0;
}

sub allow_get_files
{
	my( $self ) = @_;
	return 1;
}

sub wishes_to_export
{
	my( $self ) = @_;

	if( !defined( $self->{processor}->{tarball} ) )
	{
		return 0;
	}
	#my $filename = $self->{session}->get_repository->get_id . ".zip";
	my $filename = "files.zip";
	my $filesize = -s $self->{processor}->{tarball};

	EPrints::Apache::AnApache::header_out(
			$self->{session}->get_request,
			"Content-Disposition: attachment; filename=$filename; Content-Length: $filesize;"
			);

	return 1;
}

sub export
{
	my( $self ) = @_;

	binmode(STDOUT);
	my $file = $self->{processor}->{tarball};
	seek($file,0,0);
	open(HANDLE,$file);
	while(sysread(HANDLE, my $buffer, 4096))
	{
		print $buffer;
	}
	unlink($file);
}

sub export_mimetype
{
	my( $self ) = @_;

	return "application/x-gzip";
}

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

1;

