package Convert::PlainText::application::msword;
use strict;

my $wordtotext = "/usr/local/bin/wvText";

sub test {
	if (! -e $wordtotext) {
		return 0;
	}

	return 1;
}

sub convert($$) {
	my ($cache, $input) = @_;
	defined $cache or return 0;
	defined $input or return 0;
	
	exec($wordtotext, $input, $cache);
}

1;
