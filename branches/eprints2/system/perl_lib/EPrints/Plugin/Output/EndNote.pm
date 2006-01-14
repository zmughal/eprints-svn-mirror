package EPrints::Plugin::Output::EndNote;

use EPrints::Plugin::Output;
use EPrints::Plugin::Output::Refer;

@ISA = ( "EPrints::Plugin::Output::Refer" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "output/endnote";
	$d{name} = "EndNote";
	$d{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$d{visible} = "all";
	$d{suffix} = ".enw";
	$d{mimetype} = "text/plain";

	return %d;
}

sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->SUPER::convert_dataobj( $dataobj );
	
	# The EndNote Format <http://www.ecst.csuchico.edu/~jacobsd/bib/formats/endnote.html>

	delete( $data->{A} );
	if( $dataobj->is_set( "creators" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "creators" ) } )
		{
			# family name first
			push @{ $data->{A} }, EPrints::Utils::make_name_string( $name->{main}, 0 );
		}
	}
	delete( $data->{E} );
	if( $dataobj->is_set( "editors" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "editors" ) } )
		{
			# family name first
			push @{ $data->{E} }, EPrints::Utils::make_name_string( $name->{main}, 0 );
		}
	}

	my $type = $dataobj->get_type;
	$data->{0} = "Generic";
	$data->{0} = "Book" if $type eq "book";
	$data->{0} = "Book Section" if $type eq "book_section";
	$data->{0} = "Conference Proceedings" if $type eq "conference_item";
	$data->{0} = "Journal Article" if $type eq "article";
	$data->{0} = "Patent" if $type eq "patent";
	$data->{0} = "Report" if $type eq "monograph";
	$data->{0} = "Thesis" if $type eq "thesis";
	
	$data->{8} = $dataobj->get_value( "event_dates" ) if $dataobj->is_set( "event_dates" );
	$data->{9} = EPrints::Utils::tree_to_utf8( $dataobj->render_value( "monograph_type" ) ) if $dataobj->is_set( "monograph_type" );
	$data->{9} = EPrints::Utils::tree_to_utf8( $dataobj->render_value( "thesis_type" ) ) if $dataobj->is_set( "thesis_type" );

	return $data;
}

1;
