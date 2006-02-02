package EPrints::Plugin::Output::Refer;

use EPrints::Plugin::Output;

@ISA = ( "EPrints::Plugin::Output" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Refer";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".refer";
	$self->{mimetype} = "text/plain";

	return $self;
}


sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = {};

	# The Refer Format <http://www.ecst.csuchico.edu/~jacobsd/bib/formats/refer.html>
	# Doug Arnold's Common Bibliography Reference Card <http://clwww.essex.ac.uk/search/refer_local_help>

	if( $dataobj->is_set( "creators" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "creators" ) } )
		{
			# given name first
			push @{ $data->{A} }, EPrints::Utils::make_name_string( $name->{main}, 1 );
		}
	}
	if( $dataobj->is_set( "editors" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "editors" ) } )
		{
			# given name first
			push @{ $data->{E} }, EPrints::Utils::make_name_string( $name->{main}, 1 );
		}
	}

	$data->{T} = $dataobj->get_value( "title" ) if $dataobj->is_set( "title" );
	$data->{B} = $dataobj->get_value( "event_title" ) if $dataobj->is_set( "event_title" );
	$data->{B} = $dataobj->get_value( "book_title" ) if $dataobj->is_set( "book_title" );

	if( $dataobj->is_set( "date_effective" ) )
	{
		$dataobj->get_value( "date_effective" ) =~ /^([0-9]{4})/;
		$data->{D} = $1;
	}

	$data->{J} = $dataobj->get_value( "publication" ) if $dataobj->is_set( "publication" );
	$data->{V} = $dataobj->get_value( "volume" ) if $dataobj->is_set( "volume" );
	$data->{N} = $dataobj->get_value( "number" ) if $dataobj->is_set( "number" );
	$data->{S} = $dataobj->get_value( "series" ) if $dataobj->is_set( "series" );
	$data->{P} = $dataobj->get_value( "pagerange" ) if $dataobj->is_set( "pagerange" );
	$data->{R} = $dataobj->get_value( "id_number" ) if $dataobj->is_set( "id_number" );

	$data->{I} = $dataobj->get_value( "institution" ) if $dataobj->is_set( "institution" );
	$data->{I} = $dataobj->get_value( "publisher" ) if $dataobj->is_set( "publisher" );
	$data->{C} = $dataobj->get_value( "event_location" ) if $dataobj->is_set( "event_location" );
	$data->{C} = $dataobj->get_value( "place_of_pub" ) if $dataobj->is_set( "place_of_pub" );

	$data->{O} = $dataobj->get_value( "note" ) if $dataobj->is_set( "note" );
	$data->{K} = $dataobj->get_value( "keywords" ) if $dataobj->is_set( "keywords" );
	$data->{X} = $dataobj->get_value( "abstract" ) if $dataobj->is_set( "abstract" );

	$data->{L} = $plugin->{session}->get_archive->get_id . $dataobj->get_id;

	return $data;
}

# The programs that print entries understand most nroff and
# troff  conventions (e.g. for bold face, greek characters,
#  etc.).  In particular, for names that include  spaces  in
#  them (e.g. `Louis des Tombe', where `des' and `Tombe' are
#  effectively one word) use the `\0' for the space,  as  in
#  `Louis des\0Tombe'. For Special Characters, put \*X after
#  a normal character (X is  normally  something  that  will
#  overprint  the  normal character for the desired effect).
#  Here is a list:
#   e'(e-acute: e \ * apostrophe ')
#   e`(e-grave: e \ * open single quote `)
#   a^(a-circumflex: a \ * circumflex ^)
#   a"(a-umlaut: a \ * colon :)
#   c,(c-cidilla: c \ * comma ,)
#   a~(a-tilde: a \ * tilde ~)

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $out;
	foreach my $k ( keys %{ $data } )
	{
		if( ref( $data->{$k} ) eq "ARRAY" )
		{
			foreach( @{ $data->{$k} } )
			{
				$out .= "%$k " . remove_utf8( $_ ) . "\n";
			}
		} else {
			$out .= "%$k " . remove_utf8( $data->{$k} ) . "\n";
		}
	}
	$out .= "\n";

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
