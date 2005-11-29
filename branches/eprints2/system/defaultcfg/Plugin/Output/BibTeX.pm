package __PLUGIN__::Output::BibTeX;

use EPrints::Plugin::Output::BibTeX;

@ISA = ( 'EPrints::Plugin::Output::BibTeX' );

use strict;

sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	# use this line if you want to start building up the structure
	# from scratch:
	#my $data = { normal=>{}, unescaped=>{} };

	# use this line if you want to start with the default mapping
	# and then just tweak it:
	my $data = $plugin->SUPER::convert_dataobj( $dataobj );

	return $data;
}

