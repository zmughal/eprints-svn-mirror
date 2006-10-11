package Convert::PlainText;
use strict;
use utf8;

use Proc::Reliable;
use File::Path;
use Unicode::Normalize;

my $module_usage_count;

sub new {
	my $class = shift;
	my $instance = $module_usage_count++;
	my $self = {
		 instance => $instance
		,tmpdir => "/tmp/fulltext-search-$$-$instance"
	};
	bless $self, $class;
	
	return $self;
}


sub mimetype($$) {
	my $self = shift or return undef;
	my $file = shift or return undef;
	
	if ($file =~ /\.pdf$/i) {
		return qw(application pdf);
	} elsif ($file =~ /\.doc$/i) {
		return qw(application msword);
	} elsif ($file =~ /\.html?$/i) {
		return qw(text html);
	} elsif ($file =~ /\.txt$/i) {
		return qw(text plain);
	}
	return undef;
}

sub forcebuild($$@) {
	my $self = shift or return undef;
	my $cache = shift @_ or return 0;
	my @input = @_;

	my $tmpdir = $self->{tmpdir};

	my $proc = Proc::Reliable->new;
	$proc->time_per_try(30);
	
	if (scalar @input == 0) { return 1; }

	rmtree($tmpdir, 0, 1);
	mkpath($tmpdir, 0, 0777);
	foreach my $file (@input) {
		my @mimetype = $self->mimetype($file);
		next unless defined $mimetype[0];
		$file =~ m#([^/]*)$#;
		my $tempcache = $tmpdir . "/$1";
		my $package = "Convert::PlainText::" . $mimetype[0] . "::" . $mimetype[1];
		eval "require $package";
		no strict "refs";
		my $test = &{$package . "::test"};
		if ($test) {
			my $converter = \&{$package . "::convert"};
			$proc->run(sub { $converter->($tempcache, $file) });
		}
	}

	open(CACHE, ">", $cache);
	if ($^V ge v5.8.0) {
		binmode(CACHE, ":utf8");
	}
	opendir(DIR, $tmpdir);
	while (my $file = readdir(DIR)) {
		next if $file =~ /^\.\.?$/;
		open(FILE, "$tmpdir/$file");
		if ($^V ge v5.8.0) {
			binmode(FILE, ":utf8");
		}

# *Dirty Hack Alert!|*
# Unicode::Normalize::* only work on strings which are tagged internally by
# Perl as being UTF-8. In Perl 5.8 and above, this includes strings read from
# a filehandle, but Perl 5.6.1 has no way of explicitly tagging a filehandle
# as producing UTF-8. This pack() call has no effect other than to mark the
# string as UTF-8 so NFKC() can work.

		if ($^V lt v5.8.0) {
			while (<FILE>) {
				print CACHE NFKC(pack("U0a*", $_));
			}
		} else {
			while (<FILE>) {
				print CACHE NFKC($_);
			}
		}


		close(FILE);
	}
	closedir(DIR);
	close(CACHE);
	rmtree($tmpdir, 0, 1);
	return 1;
}

sub build($$@) {
	my $self = shift or return 0;
	my $cache = shift @_ or return 0;
	my @input = @_;

	my $cachetime = (stat($cache))[9] || 0;
	foreach my $file (@input) {
		my $filetime = (stat($file))[9] || 0;
		if ($filetime > $cachetime) {
			return $self->forcebuild($cache, @input);
		}
	}
	return 2;
}

1;
