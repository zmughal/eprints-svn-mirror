package EPrints::Plugin::Output::RSS;

use EPrints::Plugin::Output;

@ISA = ( "EPrints::Plugin::Output" );

use Unicode::String qw(latin1);

# $EPrints::Plugin::Output::BibTeX::ABSTRACT = 1;

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();
	$d{name} = "RSS";
	$d{accept} = [ 'list/eprint' ];
	return %d;
}

sub id { return "output/rss"; }

sub is_visible { return 1; }

sub mime_type
{
	my( $plugin, $searchexp ) = @_;

	return "text/plain";
}

sub suffix
{
	my( $plugin, $searchexp ) = @_;

	return ".txt";
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	return "(".$dataobj->get_value("title").")\n";
}

1;
