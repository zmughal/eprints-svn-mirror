package Convert::PlainText::text::plain;
use strict;

sub test {
	return 1;
}

sub convert($$) {
	my ($cache, $input) = @_;
	defined $cache or return 0;
	defined $input or return 0;

	open(F_IN, "<", $input);
	open(F_OUT, ">", $cache);
	while(<F_IN>) { print F_OUT $_; }
	close F_IN;
	close F_OUT;
}

1;
