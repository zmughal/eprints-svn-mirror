package Convert::PlainText::text::plain;
use strict;

sub test {
	return 1;
}

sub convert($$) {
	my ($cache, $input) = @_;
	defined $cache or return 0;
	defined $input or return 0;

	open(STDIN, "<", $input);
	open(STDOUT, ">", $cache);
	while(<STDIN>) { print; }
}

1;
