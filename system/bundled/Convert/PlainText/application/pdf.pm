package Convert::PlainText::application::pdf;
use strict;

my $pdftotext = "/usr/bin/pdftotext";

sub test {
	if (! -e $pdftotext) {
		return 0;
	}

	return 1;
}

sub convert($$) {
	my ($cache, $input) = @_;
	defined $cache or return 0;
	defined $input or return 0;
	
	exec($pdftotext, "-enc", "UTF-8", $input, $cache);
}

1;
