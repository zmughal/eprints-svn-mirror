package Convert::PlainText::text::html;
use strict;

my $lynx = "/usr/bin/lynx";

sub test {
	if (! -e $lynx) {
		return 0;
	}

	return 1;
}

sub convert($$) {
	my ($cache, $input) = @_;
	defined $cache or return 0;
	defined $input or return 0;

	open(STDIN, "<", $input);
	open(STDOUT, ">", $cache);
	exec($lynx, "-display_charset=utf-8", "-nolist", "-stdin", "-dump");
}

1;
