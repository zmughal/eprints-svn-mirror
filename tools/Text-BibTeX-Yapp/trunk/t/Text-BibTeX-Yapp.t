# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Text-BibTeX-Yapp.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;
BEGIN { use_ok('Text::BibTeX::Yapp') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $p = Text::BibTeX::Yapp->new;

my $r = $p->parse_file( "examples/xampl.bib" );

use Data::Dumper;
#warn Data::Dumper::Dumper($r);

$r = $p->parse_file( "examples/strings.bib" );
#warn Data::Dumper::Dumper($r->[$#$r]);
$r = Text::BibTeX::Yapp::expand_names( $r );
#warn Data::Dumper::Dumper($r->[$#$r]);

use Text::BibTeX::YappName;
$p = Text::BibTeX::YappName->new;

if( open(my $fh, "<", "names.txt") )
{
	while(<$fh>)
	{
		my $names = $p->parse_string( $_ );
#		print STDERR "$_:\n" . Data::Dumper::Dumper($names);
	}
	close($fh);
}
