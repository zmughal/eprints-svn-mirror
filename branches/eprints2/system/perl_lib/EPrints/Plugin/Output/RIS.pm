package EPrints::Plugin::Output::RIS;

use EPrints::Plugin::Output;

@ISA = ( "EPrints::Plugin::Output" );

use Unicode::String;

use strict;


sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Reference Manager";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".ris";
	$self->{mimetype} = "text/plain";

	return $self;
}


sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = {};

	# RIS Format Specifications <http://www.refman.com/support/risformat_intro.asp>

	# Title and reference type
	my $type = $dataobj->get_type;
	$data->{TY} = "GEN";
	$data->{TY} = "JOUR" if $type eq "article";
	$data->{TY} = "BOOK" if $type eq "book";
	$data->{TY} = "CHAP" if $type eq "book_section";
	$data->{TY} = "CONF" if $type eq "conference_item";
	$data->{TY} = "RPRT" if $type eq "monograph";
	$data->{TY} = "PAT" if $type eq "patent";
	$data->{TY} = "THES" if $type eq "thesis";
	if( $dataobj->is_set( "ispublished" ) )
	{
		my $status = $dataobj->get_value( "ispublished" );
		$data->{TY} = "INPR" if $status eq "inpress"; 
		$data->{TY} = "UNPB" if $status eq "unpub";
	}
	$data->{ID} = $plugin->{session}->get_archive->get_id . $dataobj->get_id;
	$data->{TI} = $dataobj->get_value( "title" ) if $dataobj->is_set( "title" );
	$data->{T3} = $dataobj->get_value( "series" ) if $dataobj->is_set( "series" );
	$data->{BT} = $dataobj->get_value( "book_title" ) if $dataobj->is_set( "book_title" );
	$data->{BT} = $dataobj->get_value( "event_title" ) if $dataobj->is_set( "event_title" );
	
	# Authors
	if( $dataobj->is_set( "creators" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "creators" ) } )
		{
			# family name first
			push @{ $data->{AU} }, EPrints::Utils::make_name_string( $name->{main}, 0 );
		}
	}
	if( $dataobj->is_set( "editors" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "editors" ) } )
		{
			# family name first
			push @{ $data->{ED} }, EPrints::Utils::make_name_string( $name->{main}, 0 );
		}
	}

	# Year and Free Text
	if( $dataobj->is_set( "date_effective" ) ) {
		$dataobj->get_value( "date_effective" ) =~ /([0-9]{4})-([0-9]{2})-([0-9]{2})/;
		# YYYY/MM/DD - slashes required
		$data->{PY} = sprintf( "%s/%s/%s", $1, $2 ne "00" ? $2 : "", $3 ne "00" ? $3 : "");
	}
	$data->{N1} = $dataobj->get_value( "note" ) if $dataobj->is_set( "note" );
	$data->{N2} = $dataobj->get_value( "abstract" ) if $dataobj->is_set( "abstract" );
	if( $dataobj->is_set( "keywords" ) ) {
		foreach( split ",", $dataobj->get_value( "keywords" ) )
		{
			push @{ $data->{KW} }, $_;
		}
	}
	
	# Periodical and publisher
	$data->{JO} = $dataobj->get_value( "publication" ) if $dataobj->is_set( "publication" );
	$data->{VL} = $dataobj->get_value( "volume" ) if $dataobj->is_set( "volume" );
	$data->{IS} = $dataobj->get_value( "number" ) if $dataobj->is_set( "number" );
	$data->{IS} = $dataobj->get_value( "id_number" ) if $dataobj->is_set( "id_number" );
	if( $dataobj->is_set( "pagerange" ) )
	{
		$dataobj->get_value( "pagerange" ) =~ /([0-9]+)-([0-9]+)/;
		$data->{SP} = $1 if $1;
		$data->{EP} = $2 if $2;
	}
	$data->{CY} = $dataobj->get_value( "place_of_pub" ) if $dataobj->is_set( "place_of_pub" );
	$data->{CY} = $dataobj->get_value( "event_location" ) if $dataobj->is_set( "event_location" );
	$data->{SN} = $dataobj->get_value( "isbn" ) if $dataobj->is_set( "isbn" );
	$data->{SN} = $dataobj->get_value( "issn" ) if $dataobj->is_set( "issn" );
	$data->{PB} = $dataobj->get_value( "insitution") if $dataobj->is_set( "institution" );
	$data->{PB} = $dataobj->get_value( "publisher" ) if $dataobj->is_set( "publisher" );
	
	# Misc
	$data->{UR} = $dataobj->get_url;

	return $data;
}

# The characters allowed in the reference ID fields can be in the set "0" through "9," or "A" through "Z." 
# The characters allowed in all other fields can be in the set from "space" (character 32) to character 255 in the IBM Extended Character Set.
# Note, however, that the asterisk (character 42) is not allowed in the author, keywords or periodical name fields.	

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $out = "TY  - " . $data->{TY} . "\n";
	foreach my $k ( keys %{ $data } )
	{
		next if $k eq "TY";
		if( ref( $data->{$k} ) eq "ARRAY" )
		{
			foreach( @{ $data->{$k} } )
			{
				$out .= "$k  - " . remove_utf8( $_ ) . "\n";
			}
		} else {
			$out .= "$k  - " . remove_utf8( $data->{$k} ) . "\n";
		}
	}
	$out .= "ER  -\n\n";

	return $out;
}

sub remove_utf8
{
	my( $text, $char ) = @_;

	$char = '?' unless defined $char;

	$text = "" unless( defined $text );

	my $stringobj = Unicode::String->new();
	$stringobj->utf8( $text );
	my $escstr = "";

	foreach($stringobj->unpack())
	{
		if( $_ < 128)
		{
			$escstr .= chr( $_ );
		}
		else
		{
			$escstr .= $char;
		}
	}

	return $escstr;
}

1;
