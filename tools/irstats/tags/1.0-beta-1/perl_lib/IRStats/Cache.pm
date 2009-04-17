package IRStats::Cache;

use Data::Dumper;

use strict;
use warnings;

sub new
{
	my ($class, $params) = @_;
	my $repository_name = $params->{conf}->repository;
	$repository_name =~ s/\W/_/g;
	return bless { filename => $params->{conf}->get_path('cache_path') . "/" . $repository_name . "_" . $params->get('id') }, $class;
}

sub cleanup
{
	my( $session ) = @_;

	my @paths = ($session->get_conf->get_path('cache_path'));
	push @paths, $session->get_conf->get_path('static_path') . '/graphs';

	foreach my $path (@paths)
	{
		_cleanup( $session, $path );
	}
}
	
sub _cleanup
{
	my( $session, $path ) = @_;
	
	opendir(my $dir, $path) or die "Error reading cache dir $path: $!";
	my @files = grep { $_ !~ /^\./ } readdir($dir);
	closedir($dir);
	
	$session->log( "Cleaning up cache files (".@files." files found): $path", 2 );
	
	my $expire_after = $session->get_conf->max_cache_age;
	
	foreach my $filename (@files)
	{
		my $file = "$path/$filename";
		next unless -f $file;
		my @stat = stat _;
		if( (time() - $stat[9]) > $expire_after )
		{
			$session->log( "Removing expired cache file $file", 3 );
			unlink($file);
		}
	}
}

sub exists
{
	my ($self) = @_;
	return -e $self->{'filename'};
}

sub write
{
	my ($self, $data) = @_;
	return if -e $self->{'filename'}; #in case the file has been written since exists was run

	open FILE, ">$self->{'filename'}" or die "Error writing Cache File $self->{'filename'}: $!";
	print FILE Dumper($data);
	close FILE;

}

sub read
{
	my ($self) = @_;

	my $VAR1;
	open FILE, $self->{'filename'} or die "Error reading Cache File $self->{'filename'}: $!";
	undef $/;
	my $contents = (<FILE>);
	close FILE;
	eval $contents;
	return $VAR1;
}

1;
