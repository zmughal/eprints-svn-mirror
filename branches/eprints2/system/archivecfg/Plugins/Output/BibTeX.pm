package __PLUGIN__::Output::BibTeX;

use EPrints::Plugin::Output::BibTeX;

sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = { normal=>{}, unescaped=>{} };

	$data->{normal}->{title} = $dataobj->get_value( "title" );
	$data->{normal}->{abstract} = $dataobj->get_value( "abstract" );
	$data->{unescaped}->{url} = $dataobj->get_url;
	$data->{type} = "article";
	$data->{key} = "footle97xxx:working";

	return $data;
}

